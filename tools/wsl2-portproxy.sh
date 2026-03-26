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

# --- Environment Detection ---
detect_environment() {
    if grep -qi "microsoft" /proc/version 2>/dev/null || \
       grep -qi "wsl" /proc/version 2>/dev/null; then
        echo "wsl2"
        return
    fi
    echo "linux"
}

ENV_TYPE=$(detect_environment)

if [[ "$ENV_TYPE" != "wsl2" ]]; then
    echo -e "${YELLOW}[!] WSL2 environment not detected — running in Apache-only mode.${NC}"
    echo -e "${BLUE}[i] Port proxy (Windows/netsh) steps will be skipped.${NC}\n"

    if [ "$DELETE_MODE" = true ]; then
        echo -e "${YELLOW}[!] Removing port $PORT from /etc/apache2/ports.conf...${NC}"
        sed -i "/^Listen ${PORT}$/d" /etc/apache2/ports.conf
        service apache2 restart
        echo -e "${GREEN}[✓] Port $PORT removed and Apache restarted.${NC}"
    elif [ "$LIST_MODE" = true ]; then
        echo -e "${BLUE}[i] Ports currently registered in /etc/apache2/ports.conf:${NC}\n"
        grep -E "^\s*Listen\s+[0-9]+\s*$" /etc/apache2/ports.conf
    else
        ensure_apache_port "$PORT"
    fi

    exit 0
fi

# --- Ensure netstat (net-tools) is installed ---
if ! command -v netstat >/dev/null 2>&1; then
    echo -e "${YELLOW}[!] net-tools not installed. Installing...${NC}"
    sudo apt update -qq && sudo apt install -y net-tools > /dev/null 2>&1
    echo -e "${GREEN}[✓] net-tools installed.${NC}"
fi

PORT=80

# --- Help ---
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

# --- Ensure port is registered in Apache ---
ensure_apache_port() {
    local port="$1"
    local conf="/etc/apache2/ports.conf"

    if [[ ! -f "$conf" ]]; then
        echo -e "${YELLOW}[!] $conf not found — skipping Apache check.${NC}"
        return 0
    fi

    # Check if Apache is actually installed
    if ! command -v apachectl >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] Apache not detected — skipping ports.conf check.${NC}"
        return 0
    fi

    # Search for exactly "Listen <port>" (ignores Listen 443 ssl, etc.)
    if grep -qE "^\s*Listen\s+${port}\s*$" "$conf"; then
        echo -e "${GREEN}[✓] Apache already listening on port $port.${NC}"
        return 0
    fi

    echo -e "${YELLOW}[!] Port $port not found in $conf. Adding...${NC}"
    # Inserta el nuevo puerto justo después de la última línea "Listen <número>" plain
    last_listen_line=$(grep -nE "^\s*Listen\s+[0-9]+\s*$" "$conf" | tail -1 | cut -d: -f1)

    if [[ -n "$last_listen_line" ]]; then
        sed -i "${last_listen_line}a Listen ${port}" "$conf"
    else
        # No hay ningún Listen plain todavía, inserta al inicio del archivo
        sed -i "1i Listen ${port}" "$conf"
    fi
    echo -e "${GREEN}[✓] Port $port added to $conf.${NC}"

    # Validate config before restarting
    if apachectl configtest > /dev/null 2>&1; then
        service apache2 restart
        echo -e "${GREEN}[✓] Apache restarted successfully.${NC}"
    else
        echo -e "${RED}[✗] Apache config error detected. Check $conf manually.${NC}"
        # Roll back the added line
        sed -i "/^Listen ${port}$/d" "$conf"
        echo -e "${YELLOW}[!] Rolled back: 'Listen $port' removed from $conf.${NC}"
        exit 1
    fi
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
    echo -e "${BLUE}[i] To list active Port Proxies, run this in Windows PowerShell (as Administrator):${NC}"
    echo -e "\n    netsh interface portproxy show v4tov4\n"
    echo -e "${YELLOW}[!] Or directly from WSL2 (no sudo):${NC}"
    echo -e "\n    powershell.exe -Command \"netsh interface portproxy show v4tov4\"\n"
    exit 0
fi

# --- WSL2 IP Detection ---
WSL_IP=$(hostname -I | awk '{print $1}')

if [[ -z "$WSL_IP" ]]; then
    echo -e "${RED}[✗] Error: Could not detect WSL2 IP. Try restarting WSL2.${NC}"
    exit 1
fi

# --- Execution Logic ---
if [ "$DELETE_MODE" = true ]; then
    CMD_DEL_PROXY="netsh interface portproxy delete v4tov4 listenport=$PORT listenaddress=0.0.0.0"
    CMD_DEL_FW="netsh advfirewall firewall delete rule name='WSL2 Port $PORT'"

    echo -e "${YELLOW}[!] To remove the proxy and firewall rule for port $PORT,${NC}"
    echo -e "${YELLOW}    copy and run these commands in Windows PowerShell (as Administrator):${NC}"
    echo -e "\n    $CMD_DEL_PROXY"
    echo -e "    $CMD_DEL_FW\n"
    echo -e "${YELLOW}[!] Or directly from WSL2 (no sudo):${NC}"
    echo -e "\n    powershell.exe -Command \"Start-Process powershell -ArgumentList '$CMD_DEL_PROXY; $CMD_DEL_FW' -Verb RunAs\"\n"
    echo -e "${GREEN}[✓] Copy and paste the above commands in PowerShell as admin, or run the WSL2 line above.${NC}"
else
    # --- Ensure Apache is listening on the requested port ---
    ensure_apache_port "$PORT"

    # --- Verify Apache is actually listening after setup ---
    echo -e "${BLUE}[i] Verifying Apache is listening on port $PORT...${NC}"
    if ! netstat -tlnp 2>/dev/null | grep -qE ":${PORT}\s"; then
        echo -e "${RED}[✗] Apache does not appear to be listening on port $PORT.${NC}"
        echo -e "${YELLOW}[!] Check your Apache vHost configuration and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[✓] Apache confirmed on port $PORT.${NC}"

    # --- Build commands ---
    CMD_PROXY="netsh interface portproxy add v4tov4 listenport=$PORT listenaddress=0.0.0.0 connectport=$PORT connectaddress=$WSL_IP"
    CMD_FW_ESCAPED="netsh advfirewall firewall add rule name=\"WSL2 Port $PORT\" dir=in action=allow protocol=TCP localport=$PORT"
    CMD_FW_PLAIN="netsh advfirewall firewall add rule name='WSL2 Port $PORT' dir=in action=allow protocol=TCP localport=$PORT"

    echo -e "${BLUE}[i] Mapping Windows:$PORT ➔ WSL2:$WSL_IP:$PORT${NC}"
    echo -e "${BLUE}[i] Copy and run these commands in Windows PowerShell (as Administrator):${NC}"
    echo -e "\n    $CMD_PROXY"
    echo -e "    $CMD_FW_PLAIN\n"
    echo -e "${YELLOW}[!] Or directly from WSL2 (no sudo):${NC}"
    echo -e "\n    powershell.exe -Command \"Start-Process powershell -ArgumentList '$CMD_PROXY; $CMD_FW_ESCAPED' -Verb RunAs\"\n"
    echo -e "${GREEN}[✓] Run the above in PowerShell as admin, or use the WSL2 line above.${NC}"
fi