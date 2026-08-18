# SecureLab System Baseline

## System

- Hostname: randaya-VirtualBox
- OS: Ubuntu 26.04 LTS
- Kernel: Linux 7.0.0-29-generic
- RAM: 3GB
- Disk: 30GB

## Network

- Interface: enp0s3
- IP: 10.0.2.15/24 (VirtualBox-NAT)
- Gateway: 10.0.2.2

## Running Services

| Unit | Load | Active | Sub | Description |
| :--- | :--- | :--- | :--- | :--- |
| `accounts-daemon.service` | loaded | active | running | Accounts Service |
| `avahi-daemon.service` | loaded | active | running | Avahi mDNS/DNS-SD Stack |
| `chrony.service` | loaded | active | running | chrony, an NTP client/server |
| `colord.service` | loaded | active | running | Manage, Install and Generate Color Profiles |
| `cron.service` | loaded | active | running | Regular background program processing daemon |
| `cups-browsed.service` | loaded | active | running | Make remote CUPS printers available locally |
| `cups.service` | loaded | active | running | CUPS Scheduler |
| `dbus.service` | loaded | active | running | D-Bus System Message Bus |
| `fwupd.service` | loaded | active | running | Firmware update daemon |
| `gdm.service` | loaded | active | running | GNOME Display Manager |
| `ModemManager.service` | loaded | active | running | Modem Manager |

## Listening Ports

| Port / Proto | Local Address | Service / Process | Exposure Level | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `22/tcp` | `0.0.0.0 / [::]` | `sshd` | Exposed (Network) | SSH administration |
| `3702/udp` | `10.0.2.15 / Multicast` | `python3 (WS-Discovery)` | Exposed (Network) | Local device discovery |
| `53/udp, tcp` | `127.0.0.53` | `systemd-resolved` | Local Only | System DNS resolver |
| `631/tcp` | `127.0.0.1` | `cupsd` | Local Only | Printing service |
| Various High | `127.0.0.1` | `language_server, antigravity` | Local Only | Development/IDE processes |

## Initial Observations

- Speculative Store Bypass (Spectre v4) is listed as Vulnerable. CPU is open to local speculative memory attacks unless mitigated via kernel boot flags (e.g. spec_store_bypass_disable=on) or process-level PRCTL controls.
