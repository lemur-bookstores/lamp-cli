#!/bin/bash
# ============================================================
# Phase 4 — Virtual Host Configuration
# Creates the web root, logs dir, Apache vhost config,
# enables the site, and verifies HTTP response.
# Can be run standalone:  sudo ./phases/04_vhost.sh [--domain DOMAIN] [--php-version 8.2]
# ============================================================

# ── Standalone bootstrap ──────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)      export DOMAIN="$2";      shift 2 ;;
            --php-version) export PHP_VERSION="$2"; shift 2 ;;
            --php-handler) export PHP_HANDLER="$2"; shift 2 ;;
            --vhost-root)  export VHOST_ROOT="$2";  shift 2 ;;
            *) shift ;;
        esac
    done
fi

# ── Parameters ────────────────────────────────────────────────
ask_param          DOMAIN      "Primary domain (no www)"           ""
ask_param_optional PHP_VERSION "PHP version (must match Phase 3)"  "8.2"
ask_param_optional PHP_HANDLER "PHP handler (fpm or mod)"          "fpm"
ask_param_optional VHOST_ROOT  "Document root (absolute path)"     "/var/www/vhosts/${DOMAIN}"

VHOST_CONF="/etc/apache2/sites-available/${DOMAIN}.conf"

# ── 4.1 Directory structure ───────────────────────────────────
log_info "4.1  Creating directory structure under ${VHOST_ROOT}..."
log_step "mkdir -p ${VHOST_ROOT}/httpdocs  ${VHOST_ROOT}/logs"
sudo mkdir -p "${VHOST_ROOT}/httpdocs"
sudo mkdir -p "${VHOST_ROOT}/logs"

# ── 4.2 Permissions ──────────────────────────────────────────
log_info "4.2  Setting permissions (owner: ${USER}:www-data, mode: 755)..."
sudo chown -R "${USER}:www-data" "${VHOST_ROOT}"
sudo chmod -R 755 "${VHOST_ROOT}"

# ── 4.3 VirtualHost config ────────────────────────────────────
log_info "4.3  Writing Apache VirtualHost config to ${VHOST_CONF}..."

# Build PHP handler directive (FPM uses a unix socket; mod_php needs no extra directive)
if [[ "${PHP_HANDLER:-fpm}" == "fpm" ]]; then
    PHP_HANDLER_BLOCK="    <FilesMatch \\.php\$>
        SetHandler \"proxy:unix:/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost\"
    </FilesMatch>"
else
    PHP_HANDLER_BLOCK=""
fi

sudo tee "${VHOST_CONF}" > /dev/null <<APACHECONF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    DocumentRoot ${VHOST_ROOT}/httpdocs

    <Directory "${VHOST_ROOT}/httpdocs">
        Options -Indexes +FollowSymLinks -MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog  ${VHOST_ROOT}/logs/error.log
    CustomLog ${VHOST_ROOT}/logs/access.log combined
${PHP_HANDLER_BLOCK}
</VirtualHost>
APACHECONF
log_success "VirtualHost config written."

# ── 4.4 Maintenance placeholder ──────────────────────────────
log_info "4.4  Creating maintenance placeholder page..."

# Maintenance placeholder with template substitution
TEMPLATE_PATH="${SCRIPT_DIR}/template/main_template.html"
TARGET_INDEX="${VHOST_ROOT}/httpdocs/index.html"
TARGET_IMG_DIR="${VHOST_ROOT}/httpdocs"

# Default values
SITE_NAME="${DOMAIN}"
SITE_TITLE="Maintenance in progress"
DESCRIPTION="We are experts in LMS configuration, maintenance, updates, and technical support. We are currently optimizing this server to provide you with the best e-learning experience. We'll be back online shortly."
CORPORATE_SITE_URL="https://${DOMAIN}"
VISIT_CORPORATE_SITE_TEXT="Visit our main site"
UNDER_CONSTRUCTION_IMAGE_URL="https://${DOMAIN}"
CURRENT_YEAR="$(date +%Y)"
CORPORATE_SITE_NAME="${DOMAIN}"

# Allow user overrides via env vars if set
[[ -n "${MAINT_SITE_NAME:-}" ]] && SITE_NAME="$MAINT_SITE_NAME"
[[ -n "${MAINT_SITE_TITLE:-}" ]] && SITE_TITLE="$MAINT_SITE_TITLE"
[[ -n "${MAINT_DESCRIPTION:-}" ]] && DESCRIPTION="$MAINT_DESCRIPTION"
[[ -n "${MAINT_CORPORATE_SITE_URL:-}" ]] && CORPORATE_SITE_URL="$MAINT_CORPORATE_SITE_URL"
[[ -n "${MAINT_VISIT_CORPORATE_SITE_TEXT:-}" ]] && VISIT_CORPORATE_SITE_TEXT="$MAINT_VISIT_CORPORATE_SITE_TEXT"
[[ -n "${MAINT_UNDER_CONSTRUCTION_IMAGE_URL:-}" ]] && UNDER_CONSTRUCTION_IMAGE_URL="$MAINT_UNDER_CONSTRUCTION_IMAGE_URL"
[[ -n "${MAINT_CORPORATE_SITE_NAME:-}" ]] && CORPORATE_SITE_NAME="$MAINT_CORPORATE_SITE_NAME"

# Substitute variables in template
if [[ -f "$TEMPLATE_PATH" ]]; then
    log_step "Generating index.html from template..."
    sed -e "s|{{SITE_NAME}}|$SITE_NAME|g" \
        -e "s|{{SITE_TITLE}}|$SITE_TITLE|g" \
        -e "s|{{DESCRIPTION}}|$DESCRIPTION|g" \
        -e "s|{{CORPORATE_SITE_URL}}|$CORPORATE_SITE_URL|g" \
        -e "s|{{VISIT_CORPORATE_SITE_TEXT}}|$VISIT_CORPORATE_SITE_TEXT|g" \
        -e "s|{{UNDER_CONSTRUCTION_IMAGE_URL}}|$UNDER_CONSTRUCTION_IMAGE_URL|g" \
        -e "s|{{CURRENT_YEAR}}|$CURRENT_YEAR|g" \
        -e "s|{{CORPORATE_SITE_NAME}}|$CORPORATE_SITE_NAME|g" \
        "$TEMPLATE_PATH" | sudo tee "$TARGET_INDEX" > /dev/null
    log_success "index.html generated from template."
    # Copy vector.png if exists in template dir
    if [[ -f "${SCRIPT_DIR}/template/vector.png" ]]; then
        sudo cp "${SCRIPT_DIR}/template/vector.png" "$TARGET_IMG_DIR/"
        log_success "vector.png copied to httpdocs."
    fi
else
    log_warn "Template not found, using default minimal placeholder."
    echo "<h2>Site under maintenance</h2>" | sudo tee "$TARGET_INDEX" > /dev/null
fi

# Final ownership: web server
sudo chown -R www-data:www-data "${VHOST_ROOT}"
log_success "Ownership set to www-data."

# ── 4.5 Enable site / disable default ────────────────────────
log_info "4.5  Enabling ${DOMAIN} site and disabling default..."
log_step "a2ensite ${DOMAIN}.conf"
sudo a2ensite "${DOMAIN}.conf"
sudo a2dissite 000-default.conf 2>/dev/null || true

# ── 4.6 Config test & restart ────────────────────────────────
log_info "4.6  Validating Apache config syntax..."
if ! sudo apache2ctl configtest 2>&1; then
    log_error "Apache config has a syntax error. Aborting phase."
    exit 1
fi
log_success "Config syntax OK."

log_step "systemctl restart apache2"
sudo systemctl restart apache2

HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --max-time 5 "http://${DOMAIN}" || echo "000")
log_info "HTTP response for http://${DOMAIN} : ${HTTP_CODE}"
[[ "$HTTP_CODE" == "200" ]] && log_success "Site is responding with HTTP 200." \
    || log_warn "HTTP check returned ${HTTP_CODE}. DNS may not point here yet."

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "4_vhost",
  "status": "success",
  "site": {
    "domain": "${DOMAIN}",
    "root_path": "${VHOST_ROOT}/httpdocs",
    "php_version": "${PHP_VERSION}",
    "php_handler": "${PHP_HANDLER}",
    "config_path": "${VHOST_CONF}",
    "config_syntax_test": "Syntax OK",
    "apache_status": "active",
    "http_check": "${HTTP_CODE}"
  }
}
EOF
)"
