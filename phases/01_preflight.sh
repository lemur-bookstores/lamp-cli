#!/bin/bash
# ============================================================
# Phase 1 — Pre-Flight Checks
# Can be run standalone:  sudo ./phases/01_preflight.sh [--domain DOMAIN]
# ============================================================

# ── Standalone bootstrap ──────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    # Accept --domain from CLI when run standalone
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain) export DOMAIN="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
fi

# ── Parameters ────────────────────────────────────────────────
ask_param DOMAIN "Primary domain for DNS check (no www)" ""

# ── 1.1 OS and identity ───────────────────────────────────────
log_info "1.1  Verifying OS and identity..."
lsb_release -a 2>/dev/null
CURRENT_USER=$(whoami)
log_info "Running as: ${CURRENT_USER}"

# ── 1.2 RAM and disk ──────────────────────────────────────────
log_info "1.2  Checking RAM and disk space..."
free -m
df -h /
RAM_TOTAL_MB=$(free -m | awk '/^Mem:/{print $2}')
DISK_FREE=$(df -h / | awk 'NR==2{print $4}')
log_info "RAM total: ${RAM_TOTAL_MB} MB  |  Disk free: ${DISK_FREE}"

# ── 1.3 Public IP and DNS ─────────────────────────────────────
log_info "1.3  Checking public IP and DNS resolution..."
SERVER_IP_ACTUAL=$(curl -s --max-time 5 ifconfig.me || echo "unavailable")
DNS_RESOLVED=$(dig +short "${DOMAIN}" | head -1 || echo "")
log_info "Server public IP : ${SERVER_IP_ACTUAL}"
log_info "DNS resolves to  : ${DNS_RESOLVED:-<not resolved yet>}"

DNS_MATCH=false
[[ -n "$DNS_RESOLVED" && "$DNS_RESOLVED" == "$SERVER_IP_ACTUAL" ]] && DNS_MATCH=true

if [[ "$DNS_MATCH" == "false" ]]; then
    log_warn "DNS does not yet point to this server."
    log_warn "SSL (Phase 6) will fail until DNS matches the server IP."
else
    log_success "DNS matches server IP — SSL (Phase 6) can proceed."
fi

# ── 1.4 Port availability ─────────────────────────────────────
log_info "1.4  Checking if ports 80, 443, 21, 22 are in use..."
ss -tlnp | grep -E ':80\b|:443\b|:21\b|:22\b' || log_info "No conflicts detected on key ports."

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "1_preflight",
  "status": "success",
  "server_info": {
    "current_user": "${CURRENT_USER}",
    "ip_public": "${SERVER_IP_ACTUAL}",
    "ram_total_mb": ${RAM_TOTAL_MB},
    "disk_free": "${DISK_FREE}",
    "dns_domain_resolves_to": "${DNS_RESOLVED:-none}",
    "dns_matches_server_ip": ${DNS_MATCH}
  }
}
EOF
)"
