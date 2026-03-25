#!/bin/bash
# ============================================================
# Phase 6 — SSL Certificate (Let's Encrypt)
# Guards DNS before running Certbot, then sets up auto-renewal.
# PREREQUISITE: DNS A records for DOMAIN and www.DOMAIN must
#               point to this server's IP before running.
# Can be run standalone:  sudo ./phases/06_ssl.sh [--domain DOMAIN] [--admin-email EMAIL]
# ============================================================

# ── Standalone bootstrap ──────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)      export DOMAIN="$2";      shift 2 ;;
            --admin-email) export ADMIN_EMAIL="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
fi

# ── Parameters ────────────────────────────────────────────────
ask_param DOMAIN      "Primary domain (no www)"            ""
ask_param ADMIN_EMAIL "Admin email (for cert expiry alerts)" ""

# ── 6.1 DNS guard ─────────────────────────────────────────────
log_info "6.1  Checking DNS resolution for ${DOMAIN}..."
DNS_CHECK=$(dig +short "${DOMAIN}" | head -1 || echo "")
MY_IP=$(curl -s --max-time 5 ifconfig.me || echo "")

log_info "  Server IP     : ${MY_IP}"
log_info "  DNS resolves  : ${DNS_CHECK:-<not resolved>}"

if [[ -z "$DNS_CHECK" || "$DNS_CHECK" != "$MY_IP" ]]; then
    log_error "DNS guard failed."
    log_error "  ${DOMAIN} → ${DNS_CHECK:-<no record>}  (expected ${MY_IP})"
    log_error "Fix your DNS A record and re-run Phase 6."
    exit 1
fi
log_success "DNS check passed: ${DOMAIN} → ${MY_IP}"

# ── 6.2 Obtain certificate ────────────────────────────────────
log_info "6.2  Obtaining SSL certificate via Certbot (Apache plugin)..."
log_step "certbot --apache -d ${DOMAIN} -d www.${DOMAIN}"
sudo certbot --apache \
    -d "${DOMAIN}" -d "www.${DOMAIN}" \
    --non-interactive \
    --agree-tos \
    -m "${ADMIN_EMAIL}"
log_success "Certificate issued."

# ── 6.3 Auto-renewal cron ────────────────────────────────────
log_info "6.3  Configuring auto-renewal cron (every 12 hours)..."
# Remove any existing certbot renew cron entry, then add fresh one
( crontab -l 2>/dev/null | grep -v "certbot renew" ; \
  echo "0 */12 * * * /usr/bin/certbot renew --quiet" ) | crontab -
log_success "Cron renewal configured."

# ── 6.4 Verify HTTPS ──────────────────────────────────────────
log_info "6.4  Verifying HTTPS response..."
HTTPS_STATUS=$(curl -Is --max-time 10 "https://${DOMAIN}" | head -1 | tr -d '\r' || echo "unreachable")
log_info "HTTPS response: ${HTTPS_STATUS}"
[[ "$HTTPS_STATUS" == *"200"* || "$HTTPS_STATUS" == *"301"* ]] \
    && log_success "HTTPS is active." \
    || log_warn "Unexpected status — check Apache SSL config."

SSL_EXPIRY=$(sudo certbot certificates 2>/dev/null \
    | grep "Expiry Date" | head -1 | awk '{print $3}' || echo "unknown")

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "6_ssl",
  "status": "success",
  "ssl": {
    "domain": "${DOMAIN}",
    "provider": "Let's Encrypt",
    "status": "Installed",
    "expiry_date": "${SSL_EXPIRY}",
    "auto_renewal": "active (cron every 12h)",
    "https_check": "${HTTPS_STATUS}"
  }
}
EOF
)"
