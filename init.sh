#!/bin/bash
# ============================================================
# init.sh — LAMP Stack Modular CLI Installer
#              Ubuntu 22.04 LTS — AWS Lightsail
#
# Usage:
#   sudo lamp-cli [OPTIONS]
#
# Each phase can also be run standalone:
#   sudo lamp-cli --phases 4,5
# ============================================================


set -euo pipefail

# ── Usage / help ──────────────────────────────────────────────
usage() {
    cat <<EOF

${BOLD}LAMP Stack CLI Installer — Ubuntu 22.04 LTS${RESET}

USAGE:
    sudo lamp-cli [OPTIONS] [--phases PHASE_LIST]
    sudo lamp-cli <subcommand> [args]

${BOLD}SUBCOMMANDS:${RESET}
    portproxy               WSL2 ↔ Windows port proxy manager

    portproxy options:
        -p <port>             Forward the specified port  (default: 80)
        -l                    List all active port proxies
        -d                    Delete proxy for the specified port
        -h                    Show portproxy help

    Examples:
        sudo lamp-cli portproxy                  # Forward port 80
        sudo lamp-cli portproxy -p 3000          # Forward port 3000
        sudo lamp-cli portproxy -l               # List active proxies
        sudo lamp-cli portproxy -p 8080 -d       # Remove port 8080

${BOLD}GLOBAL OPTIONS:${RESET}

GLOBAL OPTIONS (all optional — will prompt if not provided):
    --domain          DOMAIN     Primary domain, no www (e.g. site.com)
    --admin-email     EMAIL      Admin email for Certbot SSL notices
    --db-name         DB_NAME    Database name
    --db-user         DB_USER    Database username
    --db-pass         DB_PASS    Database password
    --php-version     VERSION    PHP version to install       (default: 8.2)
    --swap-size       SIZE       Swap file size               (default: 4G)
    --ftp-mode        ftps|sftp  File transfer mode           (default: ftps)
    --ftp-user        USER       FTP/SFTP username
    --ftp-pass        PASS       FTP/SFTP password
    --php-handler     fpm|mod    PHP handler mode                (default: fpm)
    --vhost-root      PATH       Absolute DocumentRoot path      (default: /var/www/vhosts/DOMAIN)
    --vhost-port      PORT       Virtual host port               (default: 80)
    --mariadb-ratio   PERCENT    InnoDB buffer % of RAM 50-70 (default: 60)

PHASE SELECTION:
    --phases  LIST    Comma-separated phase numbers, or "all"
                                        e.g. --phases 1,2,3   or   --phases all

AVAILABLE PHASES:
    1  Pre-Flight Checks
    2  System Preparation       (swap, apt update/upgrade)
    3  LAMP Stack Installation  (Apache, PHP, MariaDB, Certbot, VSFTPD)
    4  Virtual Host             (directories, vhost config, permissions)
    5  Database                 (harden MariaDB, create DB + user)
    6  SSL Certificate          (Let's Encrypt via Certbot)
    7  PHP Performance Tuning   (php.ini optimizations)
    8  MariaDB Performance Tuning
    9  File Transfer Service    (FTPS via VSFTPD or SFTP)

EXAMPLES:
    sudo lamp-cli
    sudo lamp-cli --domain example.com --php-version 8.2 --phases all
    sudo lamp-cli --phases 1,2,3 --swap-size 2G
    sudo lamp-cli --domain site.com --db-name mydb --db-user myuser --phases 4,5

EOF
    exit 0
}

# Resolve the real script directory, even if called via symlink
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
        DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# ── Subcommand routing ────────────────────────────────────────
# Allow: lamp-cli <subcommand> [args...]
# Example: lamp-cli portproxy -p 8080
#          lamp-cli portproxy -l
#          lamp-cli portproxy -p 3000 -d
SUBCOMMAND="${1:-}"

case "$SUBCOMMAND" in
        portproxy)
                shift  # remove 'portproxy' from args
                PROXY_SCRIPT="${SCRIPT_DIR}/tools/wsl2-portproxy.sh"

                if [[ ! -f "$PROXY_SCRIPT" ]]; then
                        log_error "Script not found: ${PROXY_SCRIPT}"
                        exit 1
                fi

                chmod +x "$PROXY_SCRIPT"
                exec bash "$PROXY_SCRIPT" "$@"
                ;;
        help|--help|-h)
                usage
                ;;
esac

# ── Phase metadata ─────────────────────────────────────────────
declare -A PHASE_NAMES=(
    [1]="Pre-Flight Checks"
    [2]="System Preparation (swap, apt)"
    [3]="LAMP Stack Installation"
    [4]="Virtual Host Configuration"
    [5]="Database Security & Setup"
    [6]="SSL Certificate (Let's Encrypt)"
    [7]="PHP Performance Tuning"
    [8]="MariaDB Performance Tuning"
    [9]="File Transfer Service (FTP/SFTP)"
)

# ── Parse named arguments ─────────────────────────────────────
SELECTED_PHASES=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --domain)         export DOMAIN="$2";               shift 2 ;;
        --admin-email)    export ADMIN_EMAIL="$2";          shift 2 ;;
        --db-name)        export DB_NAME="$2";              shift 2 ;;
        --db-user)        export DB_USER="$2";              shift 2 ;;
        --db-pass)        export DB_PASS="$2";              shift 2 ;;
        --php-version)    export PHP_VERSION="$2";          shift 2 ;;
        --swap-size)      export SWAP_SIZE="$2";            shift 2 ;;
        --ftp-mode)       export FTP_MODE="$2";             shift 2 ;;
        --ftp-user)       export FTP_USER="$2";             shift 2 ;;
        --ftp-pass)       export FTP_PASS="$2";             shift 2 ;;
        --mariadb-ratio)  export MARIADB_BUFFER_RATIO="$2"; shift 2 ;;
        --php-handler)    export PHP_HANDLER="$2";          shift 2 ;;
        --vhost-root)     export VHOST_ROOT="$2";           shift 2 ;;
        --vhost-port)     export VHOST_PORT="$2";           shift 2 ;;
        --phases)         SELECTED_PHASES="$2";             shift 2 ;;
        -h|--help)        usage ;;
        *) log_error "Unknown option: $1"; echo "Run with --help for usage."; exit 1 ;;
    esac
done

# ── Banner ────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
cat <<'BANNER'
  ██╗      █████╗ ███╗   ███╗██████╗      ██████╗██╗     ██╗
  ██║     ██╔══██╗████╗ ████║██╔══██╗    ██╔════╝██║     ██║
  ██║     ███████║██╔████╔██║██████╔╝    ██║     ██║     ██║
  ██║     ██╔══██║██║╚██╔╝██║██╔═══╝     ██║     ██║     ██║
  ███████╗██║  ██║██║ ╚═╝ ██║██║         ╚██████╗███████╗██║
  ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝          ╚═════╝╚══════╝╚═╝
                Ubuntu 22.04 LTS — AWS Lightsail
BANNER
echo -e "${RESET}"

# ── Phase selection menu ───────────────────────────────────────
select_phases() {
    echo -e "${BOLD}Select which phases to run:${RESET}\n"
    for i in $(seq 1 9); do
        echo -e "  ${CYAN}[${i}]${RESET} ${PHASE_NAMES[$i]}"
    done
    echo -e "  ${CYAN}[a]${RESET} Run ALL phases (1–9)"
    echo -e "  ${CYAN}[q]${RESET} Quit\n"

    local input
    read -r -p "Enter phases (comma-separated, e.g. 1,2,3 or a): " input

    case "$input" in
        a|all|A) SELECTED_PHASES="1,2,3,4,5,6,7,8,9" ;;
        q|Q)     echo "Aborted."; exit 0 ;;
        "")      log_error "No phases selected."; select_phases ;;
        *)       SELECTED_PHASES="$input" ;;
    esac
}

[[ -z "$SELECTED_PHASES" ]] && select_phases
[[ "$SELECTED_PHASES" == "all" ]] && SELECTED_PHASES="1,2,3,4,5,6,7,8,9"

# ── Normalize and validate phase list ─────────────────────────
IFS=',' read -ra PHASES_TO_RUN <<< "$SELECTED_PHASES"

echo ""
log_info "Phases to run: ${PHASES_TO_RUN[*]}"
echo ""

# ── Run each selected phase ────────────────────────────────────
ERRORS=0

for phase_num in "${PHASES_TO_RUN[@]}"; do
    phase_num="$(echo "$phase_num" | tr -d ' ')"

    # Find the matching phase file (e.g. phases/04_vhost.sh)
    phase_pattern="${SCRIPT_DIR}/phases/$(printf '%02d' "$phase_num")_*.sh"
    matched=( ${phase_pattern} )

    if [[ ! -f "${matched[0]:-}" ]]; then
        log_warn "Phase ${phase_num}: script not found (${phase_pattern}) — skipping."
        continue
    fi

    log_phase "Phase ${phase_num} — ${PHASE_NAMES[$phase_num]:-}"

    # Source the phase so it inherits all exported variables
    if source "${matched[0]}"; then
        log_success "Phase ${phase_num} completed successfully.\n"
    else
        log_error "Phase ${phase_num} failed."
        ERRORS=$(( ERRORS + 1 ))
        echo ""
        read -r -p "  Phase failed. Continue with next phase? [y/N]: " cont
        [[ "${cont,,}" != "y" ]] && { log_error "Aborting."; exit 1; }
    fi
done

echo ""
if [[ $ERRORS -eq 0 ]]; then
    log_success "All selected phases completed without errors."
else
    log_warn "Completed with ${ERRORS} phase failure(s). Review the output above."
fi
