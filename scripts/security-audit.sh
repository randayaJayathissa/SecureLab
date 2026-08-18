#!/usr/bin/env bash
#
# SecureLab - Baseline System Security Audit Script
# Target: Ubuntu 26.04 LTS
# Location: ~/projects/SecureLab/scripts/security-audit.sh
#

set -euo pipefail

# Output styling
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
RESET="\033[0m"

print_header() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${RESET}"
}

echo "=================================================="
echo -e "${BOLD}${GREEN}          SECURELAB SECURITY AUDIT               ${RESET}"
echo "=================================================="

# 1. System Identity
print_header "SYSTEM IDENTITY"
echo "Hostname     : $(hostname)"
echo "Timestamp    : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "Current User : $(whoami)"
echo "Kernel       : $(uname -r)"

# 2. Resource Utilization
print_header "RESOURCE UTILIZATION"
echo "-- Root Filesystem Usage --"
df -h / | awk 'NR==1 || NR==2'
echo ""
echo "-- Memory Allocation --"
free -h

# 3. Network Configuration
print_header "NETWORK INTERFACES & IP ADDRESSES"
ip -4 -br addr show

# 4. Listening Sockets
print_header "LISTENING PORTS (TCP/UDP)"
ss -tuln | awk 'NR==1 {printf "%-6s %-22s %-22s\n", $1, $4, $5} NR>1 {printf "%-6s %-22s %-22s\n", $1, $4, $5}'

# 5. User Activity
print_header "LOGGED-IN USERS"
if who | grep -q .; then
    who
else
    echo "No interactive login sessions detected."
fi

# 6. Service & Security Posture
print_header "CORE SERVICE STATUS"
SSH_STATE=$(systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null || echo "inactive")
echo "SSH Daemon   : ${SSH_STATE}"

if command -v nginx &>/dev/null; then
    NGINX_STATE=$(systemctl is-active nginx 2>/dev/null || echo "inactive")
    echo "Nginx Server : ${NGINX_STATE}"
fi

# 7. Firewall Inspection
print_header "FIREWALL (UFW) POSTURE"
if command -v ufw &>/dev/null; then
    if [ "$EUID" -ne 0 ]; then
        sudo ufw status verbose 2>/dev/null || echo "Permission denied: run with sudo for detailed UFW table."
    else
        ufw status verbose
    fi
else
    echo "UFW is not installed."
fi

# 8. Running Services Overview
print_header "ACTIVE SYSTEM SERVICES"
TOTAL_ACTIVE=$(systemctl list-units --type=service --state=running --no-legend | wc -l)
echo "Total Active Services: ${TOTAL_ACTIVE}"
echo ""
echo "First 10 Active Services:"
systemctl list-units --type=service --state=running --no-legend | head -n 10 | awk '{print "  [+] " $1}'

echo -e "\n=================================================="
echo -e "${BOLD}${GREEN}              AUDIT COMPLETE                     ${RESET}"
echo "=================================================="
