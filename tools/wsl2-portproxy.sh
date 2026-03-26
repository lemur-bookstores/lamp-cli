#!/bin/bash
# ==============================================================================
# WSL2 Ultimate Port Proxy Manager
# Author: https://github.com/ElkinCp5
# Description: Professional CLI to manage Windows → WSL2 port forwarding.
# ==============================================================================

set -e

# --- Colors ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

PORT=80

show_help() {
    echo -e "${PURPLE}WSL2 Port Proxy Manager${NC}"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -p <port>    Specify the port (default: 80)"
    echo "  -l           List all active port proxies in Windows"
    echo "  -d           Delete proxy for the specified port"
    echo "  -h           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p 8080       # Forward port 8080"
    echo "  $0 -l            # Show active mappings"
    echo "  $0 -p 3000 -d    # Remove port 3000 mapping"
    exit 0
}

# --- Actions ---
LIST_MODE=false
DELETE_MODE=false

while getopts "p:dlh" opt; do
    case "$opt" in
        p) PORT=$OPTARG ;;
        l) LIST_MODE=true ;;
        d) DELETE_MODE=true ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# --- List Mode ---
if [ "$LIST_MODE" = true ]; then
    echo -e "${BLUE}[i] Fetching active Port Proxies from Windows...${NC}"
    echo -e "${GREEN}------------------------------------------------------------${NC}"
    powershell.exe -Command "netsh interface portproxy show v4tov4"
    echo -e "${GREEN}------------------------------------------------------------${NC}"
    exit 0
fi

# --- WSL2 IP Detection ---
WSL_IP=$(hostname -I | awk '{print $1}')

if [[ -z "$WSL_IP" ]]; then
    echo -e "${RED}[✗] Error: Could not detect WSL2 IP.${NC}"
    exit 1
fi

# --- Execution Logic ---
if [ "$DELETE_MODE" = true ]; then
    echo -e "${YELLOW}[!] Removing proxy and firewall rule for port $PORT...${NC}"

    CMD_DEL_PROXY="netsh interface portproxy delete v4tov4 listenport=$PORT listenaddress=0.0.0.0"
    CMD_DEL_FW="netsh advfirewall firewall delete rule name='WSL2 Port $PORT'"

    powershell.exe -Command "Start-Process powershell -ArgumentList \"$CMD_DEL_PROXY; $CMD_DEL_FW\" -Verb RunAs"
    echo -e "${GREEN}[✓] Deletion request sent to Windows.${NC}"
else
    echo -e "${BLUE}[i] Mapping Windows:$PORT ➔ WSL2:$WSL_IP:$PORT${NC}"

    CMD_PROXY="netsh interface portproxy add v4tov4 listenport=$PORT listenaddress=0.0.0.0 connectport=$PORT connectaddress=$WSL_IP"
    CMD_FW="netsh advfirewall firewall add rule name='WSL2 Port $PORT' dir=in action=allow protocol=TCP localport=$PORT"

    echo -e "${YELLOW}[!] Requesting Admin privileges...${NC}"
    powershell.exe -Command "Start-Process powershell -ArgumentList \"$CMD_PROXY; $CMD_FW\" -Verb RunAs"

    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}[✓] Success! Port $PORT is now exposed.${NC}"
    echo -e "${BLUE}[i] Note: Check the Windows UAC popup to confirm.${NC}"
    echo -e "${GREEN}============================================================${NC}"
fi