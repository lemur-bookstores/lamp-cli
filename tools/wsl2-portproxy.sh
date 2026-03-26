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

# --- Defaults --- (moved to top for safety)
PORT=80
LIST_MODE=false
DELETE_MODE=false

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

# --- Parse args --- (before any logic that uses these variables)
while getopts "p:dlh" opt; do
    case "$opt" in
        p) PORT=$OPTARG ;;
        l) LIST_MODE=true ;;
        d) DELETE_MODE=true ;;
        h) show_help ;;
        *) show_help ;;
    esac
done

# --- Apache port management ---
manage_apache_port() {
    local action="$1"
    local port="$2"
    local conf="/etc/apache2/ports.conf"


    if [[ ! -f "$conf" ]]; then
        echo -e "${YELLOW}[!] $conf not found — skipping Apache check.${NC}"
        return 0
    fi

    if ! command -v apachectl >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] Apache not detected — skipping ports.conf check.${NC}"
        return 0
    fi

    case "$action" in
        add)
            if grep -qE "^\s*Listen\s+${port}\s*$" "$conf"; then
                echo -e "${GREEN}[✓] Apache already listening on port $port.${NC}"
                return 0
            fi
            echo -e "${YELLOW}[!] Port $port not found in $conf. Adding...${NC}"
            last_listen_line=$(awk '
                /<IfModule/    { in_block=1 }
                /<\/IfModule>/ { in_block=0; next }
                !in_block && /^\s*Listen\s+[0-9]+\s*$/ { last=NR }
                END { print last }
            ' "$conf")
            if [[ -n "$last_listen_line" ]]; then
                sed -i "${last_listen_line}a Listen ${port}" "$conf"
            else
                sed -i "1i Listen ${port}" "$conf"
            fi
            echo -e "${GREEN}[✓] Port $port added to $conf.${NC}"
            if apachectl configtest > /dev/null 2>&1; then
                service apache2 restart
                echo -e "${GREEN}[✓] Apache restarted successfully.${NC}"
            else
                echo -e "${RED}[✗] Apache config error detected. Check $conf manually.${NC}"
                sed -i "/^Listen ${port}$/d" "$conf"
                echo -e "${YELLOW}[!] Rolled back: 'Listen $port' removed from $conf.${NC}"
                exit 1
            fi
            ;;
        remove)
            echo -e "${YELLOW}[!] Removing port $port from $conf...${NC}"
            awk '
                /<IfModule/    { in_block=1 }
                /<\/IfModule>/ { in_block=0 }
                in_block       { print; next }
                /^\s*Listen\s+'"$port"'\s*$/ { next }
                { print }
            ' "$conf" > /tmp/ports.conf.tmp && mv /tmp/ports.conf.tmp "$conf"
            service apache2 restart
            echo -e "${GREEN}[✓] Port $port removed and Apache restarted.${NC}"
            ;;
        list)
            echo -e "${BLUE}[i] Ports currently registered in $conf:${NC}\n"
            awk '
                /<IfModule/    { in_block=1 }
                /<\/IfModule>/ { in_block=0; next }
                !in_block && /^\s*Listen\s+[0-9]+\s*$/ { print }
            ' "$conf"
            ;;
        *)
            echo -e "${RED}[✗] Unknown action: $action${NC}"
            return 1
            ;;
    esac
}

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

# --- Linux native mode (no Windows proxy needed) ---
if [[ "$ENV_TYPE" != "wsl2" ]]; then

    echo -e "${YELLOW}[!] WSL2 environment not detected — running in Apache-only mode.${NC}"
    echo -e "${BLUE}[i] Port proxy (Windows/netsh) steps will be skipped.${NC}\n"


    if [ "$DELETE_MODE" = true ]; then
        manage_apache_port remove "$PORT"
        echo ""
        manage_apache_port list
    elif [ "$LIST_MODE" = true ]; then
        manage_apache_port list
    else
        manage_apache_port add "$PORT"
    fi

    exit 0  # Only one exit here
fi

# --- WSL2 mode ---

# --- Ensure netstat (net-tools) is installed ---
if ! command -v netstat >/dev/null 2>&1; then
    echo -e "${YELLOW}[!] net-tools is not installed. Installing...${NC}"
    sudo apt update -qq && sudo apt install -y net-tools > /dev/null 2>&1
    echo -e "${GREEN}[✓] net-tools installed.${NC}"
fi

# --- List Mode ---
if [ "$LIST_MODE" = true ]; then
    manage_apache_port list  # Also shows Apache ports in WSL2
    echo ""
    echo -e "${BLUE}[i] To list active Windows Port Proxies, run in PowerShell (as Administrator):${NC}"
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
    manage_apache_port remove "$PORT"  # Also cleans ports.conf in WSL2

    CMD_DEL_PROXY="netsh interface portproxy delete v4tov4 listenport=$PORT listenaddress=0.0.0.0"
    CMD_DEL_FW="netsh advfirewall firewall delete rule name='WSL2 Port $PORT'"

    echo -e "${YELLOW}[!] To remove the Windows proxy and firewall rule for port $PORT,${NC}"
    echo -e "${YELLOW}    Copy and run these commands in PowerShell (as Administrator):${NC}"
    echo -e "\n    $CMD_DEL_PROXY"
    echo -e "    $CMD_DEL_FW\n"
    echo -e "${YELLOW}[!] Or directly from WSL2 (no sudo):${NC}"
    echo -e "\n    powershell.exe -Command \"Start-Process powershell -ArgumentList '$CMD_DEL_PROXY; $CMD_DEL_FW' -Verb RunAs\"\n"
    echo -e "${GREEN}[✓] Copy and paste the above commands in PowerShell as admin, or run the WSL2 line above.${NC}"
else
    manage_apache_port add "$PORT"  # Correct function name

    # --- Verify Apache is actually listening after setup ---
    echo -e "${BLUE}[i] Verifying Apache is listening on port $PORT...${NC}"
    if ! netstat -tlnp 2>/dev/null | grep -qE ":${PORT}\s"; then
        echo -e "${RED}[✗] Apache does not appear to be listening on port $PORT.${NC}"
        echo -e "${YELLOW}[!] Check your Apache vHost configuration and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}[✓] Apache confirmed on port $PORT.${NC}"

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