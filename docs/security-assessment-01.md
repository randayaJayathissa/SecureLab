# Network Security Assessment 01

## Objective
Evaluate the external attack surface and network exposure of the SecureLab server from the perspective of an external host on the administrative subnet (`192.168.56.0/24`).

## Method
Executed non-credentialed TCP network reconnaissance from the Windows Host (`192.168.56.1`) targeting the Ubuntu guest VM (`192.168.56.101`) using Nmap:

```powershell
nmap.exe -sV -sC -Pn 192.168.56.101 -oN reports/scans/hardened.txt
```

- **Target Host:** `192.168.56.101` (`randaya-VirtualBox`)
- **Source Host:** `192.168.56.1` (Windows 10/11 Host)
- **Scan Parameters:** Service/version detection (`-sV`), default NSE security scripts (`-sC`), and skip ICMP ping probe (`-Pn`).

## Observation
- **Open Ingress Ports:**
  - `22/tcp` — OpenSSH daemon (Ubuntu Linux; protocol 2.0).
  - `80/tcp` — Nginx HTTP web server.
- **Firewall Behavior:**
  - 998 of the top 1,000 scanned TCP ports returned in a `filtered` state.
  - Confirms UFW default-deny policy is actively dropping unauthorized inbound TCP packets without sending TCP RST responses.
- **Service Banners:**
  - Port 80 exposes the Nginx web server banner.
  - Port 22 exposes the OpenSSH package and OS identifier.

## Risk
- **Version Disclosure:** Public software version banners assist adversaries during reconnaissance in identifying relevant Common Vulnerabilities and Exposures (CVEs).
- **Cleartext Transmission:** Port 80 transmits unencrypted HTTP traffic across the local segment.

## Mitigation
- **Enforce Least Privilege Network Access:** Keep UFW default-deny ingress active so only ports 22 and 80 remain reachable.
- **Banner Suppression:** Add `server_tokens off;` inside `/etc/nginx/nginx.conf` to hide precise Nginx version numbers.
- **Transport Layer Security:** Transition web traffic from plain HTTP (port 80) to TLS termination (HTTPS via reverse proxy) in upcoming milestones.

## Verification
- Raw Nmap scan evidence saved to `reports/scans/baseline.txt` and `reports/scans/hardened.txt`.
- Confirmed that internal services and unbound daemon sockets are inaccessible externally.
