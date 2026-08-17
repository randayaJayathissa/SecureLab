# SSH Hardening & Host-to-Guest Architecture Audit

**Target Environment:** Ubuntu 26.04 LTS (Guest VM)  
**Host Environment:** Windows 11 (OpenSSH Client)  
**Document Type:** Security Audit, Configuration Blueprint & Operational Observations  
**Status:** Completed & Verified  

---

## 1. Executive Summary & Objective

The objective of this security baseline is to transition the Ubuntu 26.04 LTS virtual machine from default, password-permissive access to an **asymmetric cryptographic authentication model (Ed25519)**, eliminating unauthorized access vectors while hardening the OpenSSH daemon (`sshd`). 

This audit covers:
1. Complete network architecture design (Dual-Adapter strategy).
2. Elimination of password authentication and direct root login.
3. Cryptographic key distribution, file permission enforcement, and sanitization.
4. Troubleshooting observations (NAT port forwarding vs. Host-Only, systemd socket management, GNOME session inhibition, and OpenSSH session lifecycle).
5. Formal verification and validation test outputs.

---

## 2. Infrastructure & Network Architecture

### 2.1 Network Topology Comparison & Selection

During initial provisioning, multiple network topologies were tested to establish low-latency, reliable communication between the Windows Host and the Ubuntu VM.

```
+-------------------------------------------------------------------------+
|                              WINDOWS HOST                               |
|                                                                         |
|  +-----------------------------------+   +---------------------------+  |
|  | OpenSSH Client (Windows Terminal) |   | VirtualBox Host-Only NIC  |  |
|  | C:\Users\Randaya\.ssh\id_ed25519  |   | 192.168.56.1              |  |
|  +-----------------+-----------------+   +-------------+-------------+  |
+--------------------|-----------------------------------|----------------+
                     |                                   |
                     |  SSH Protocol (TCP Port 22)       | Host-Only Network
                     |                                   | (192.168.56.0/24)
+--------------------|-----------------------------------|----------------+
|                    v                                   v                |
|  +-----------------+-----------------------------------+-------------+  |
|  | Adapter 2: Host-Only (enp0s8) -> 192.168.56.101                   |  |
|  |                                                                   |  |
|  | Adapter 1: NAT (enp0s3)       -> 10.0.2.15 (Outbound WAN Access)  |  |
|  |                                                                   |  |
|  |                   UBUNTU 26.04 LTS VIRTUAL MACHINE                |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

| Topology Evaluated | Observation & Behavior | Security & Operational Impact | Verdict |
|---|---|---|---|
| **Single NAT + Port Forwarding** (`127.0.0.1:2222 -> :22`) | Resulted in `Connection reset before key exchange`. Host-side port redirection experienced driver desynchronization during runtime reboots and proxy resets via Windows Filtering Platform (WFP). | Complex port mapping, prone to localhost socket collision on the host. | **Rejected** |
| **Bridged Adapter** | Connection timed out or dropped immediately. Standard 802.11 Wi-Fi frames reject multiple source MAC addresses over a single physical wireless interface. | Unstable across wireless access points, exposes guest VM directly to local physical LAN. | **Rejected** |
| **Dual-Adapter: NAT + Host-Only** | **Flawless connectivity.** Adapter 1 (NAT) handles outbound package updates (`apt`), while Adapter 2 (`192.168.56.101`) provides an isolated host-to-guest link. | Completely isolates administrative SSH traffic from physical LAN; zero port-forwarding overhead. | **Selected (Standard)** |

---

## 3. Cryptographic Key Architecture

Authentication relies on the **Ed25519** elliptic curve algorithm (Edwards-curve Digital Signature Algorithm over Curve25519), offering superior security, performance, and resistance to side-channel attacks compared to traditional RSA.

### 3.1 Key Distribution Details

```
Windows Host (Client)                            Ubuntu 26.04 Guest (Server)
C:\Users\Randaya\.ssh\                         /home/randaya/.ssh/
├── id_ed25519 (Private Key, 0600)  ------------> [AUTHORIZED ACCESS]
└── id_ed25519.pub (Public Key)     -- Copied ->  authorized_keys (Mode 0600)
```

- **Algorithm**: `ssh-ed25519`
- **Host Key Storage**: Windows OpenSSH `known_hosts` storing guest fingerprint (`SHA256:pvK9bAXtklSJSOG5wyNzYt6DUlx3ctGB4ljevzFUUs4`).
- **Sanitization Requirement**: Public keys pasted from Windows environments must be stripped of carriage returns (`\r`) to ensure OpenSSH parses the record as a single continuous line.

---

## 4. SSH Daemon Configuration & Hardening Directives

Modular drop-in configuration was implemented at `/etc/ssh/sshd_config.d/50-hardening.conf` to isolate custom rules from distro-default package updates.

```ini
# /etc/ssh/sshd_config.d/50-hardening.conf
# SecureLab Day 2 Hardening Baseline

# 1. Disable remote superuser login
PermitRootLogin no

# 2. Disable password authentication (credential brute-force mitigation)
PasswordAuthentication no

# 3. Enforce public key authentication
PubkeyAuthentication yes

# 4. Enforce strict permissions check on home and .ssh directories
StrictModes yes
```

### 4.1 Security Directives Rationale

1. **`PermitRootLogin no`**:
   - *Threat Mitigated*: Direct targeting of root credentials by automated bots.
   - *Impact*: Requires operators to log in as unprivileged users (`randaya`) and explicitly escalate privileges using `sudo`, generating comprehensive audit logs in `auth.log` / `journald`.

2. **`PasswordAuthentication no`**:
   - *Threat Mitigated*: Password guessing, online dictionary attacks, and credential stuffing.
   - *Impact*: Rejects all password authentication methods at the pre-authentication stage, terminating invalid handshake attempts before PAM engagement.

3. **`PubkeyAuthentication yes`**:
   - *Threat Mitigated*: Weak shared secret exploitation.
   - *Impact*: Mandates asymmetric cryptographic proof of private key possession.

---

## 5. Filesystem & Permission Matrix

OpenSSH enforces strict permission hierarchies via `StrictModes`. Permissions across the authentication tree were set as follows:

| Path / Target | Owner:Group | Numeric Mode | Symbolic Notation | Rationale & Security Implication |
|---|---|---|---|---|
| `/home/randaya` | `randaya:randaya` | `0755` | `drwxr-xr-x` | Group/Others cannot write; prevents unauthorized path hijacking. |
| `/home/randaya/.ssh` | `randaya:randaya` | `0700` | `drwx------` | Directory access strictly restricted to the user; prevents key listing. |
| `/home/randaya/.ssh/authorized_keys` | `randaya:randaya` | `0600` | `-rw-------` | Read/Write strictly restricted to the owner; prevents unauthorized key injection. |
| `/etc/ssh/sshd_config.d/50-hardening.conf` | `root:root` | `0644` | `-rw-r--r--` | Readable by daemon; writable only by root administrator. |

---

## 6. Operational Observations & Troubleshooting Log

### Observation 1: OpenSSH Master Daemon vs. Child Session Architecture
- **Observed Behavior**: Executing `sudo systemctl restart ssh.service` did not drop or interrupt the active SSH terminal session.
- **Underlying Mechanism**: The OpenSSH architecture decouples the master listener process (which binds to port 22) from child worker processes (`sshd-session` / `sshd: randaya`). When `systemctl restart` is triggered, only the master listener restarts to ingest updated configurations for *future* connections. Active child sessions remain open, preventing administrative lockout due to configuration errors.

### Observation 2: Systemd Socket vs. Standalone Service Activation
- **Observed Behavior**: Ubuntu 26.04 utilizes `ssh.socket` by default for on-demand socket activation. Under heavy network resets or port-forwarding testing, `ssh.socket` exhibited state races.
- **Resolution**: Disabled `ssh.socket` in favor of persistent `ssh.service` (`systemctl disable --now ssh.socket && systemctl enable --now ssh.service`), ensuring steady socket binding and predictable logging.

### Observation 3: GNOME Desktop Power Management Inhibitors
- **Observed Behavior**: Running `sudo reboot` or `sudo poweroff` from a terminal session was initially rejected with:  
  `Operation inhibited by "randaya" (PID ... "gnome-session-s", reason: "user session inhibited")`.
- **Underlying Mechanism**: The active desktop GUI session registers an inhibitor lock with `systemd-logind` to prevent sudden data loss.
- **Resolution**: Use `--ignore-inhibitors` (`sudo systemctl reboot -i` / `sudo systemctl poweroff -i`) or execute standard kernel-level shutdown commands (`sudo shutdown -h now`).

---

## 7. Verification & Validation Testing

All verification tests were executed from the Windows client host (PowerShell) against target `192.168.56.101`.

![SSH Verification Test](../screenshots/ssh-test.png)

## 8. Conclusion & Sign-Off

The OpenSSH subsystem on Ubuntu 26.04 LTS has been successfully hardened and verified against standard administrative attack vectors. Key-only authentication is enforced, network isolation is guaranteed via the Dual-Adapter topology, and permissions adhere to strict least-privilege standards.
