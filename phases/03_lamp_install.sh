#!/bin/bash
# ============================================================
# Phase 3 — LAMP Stack Installation
# Installs Apache, MariaDB, PHP (via Ondřej Surý PPA),
# Certbot, and VSFTPD; enables services on boot.
# Can be run standalone:  sudo ./phases/03_lamp_install.sh [--php-version 8.2]
# ============================================================

# ── Standalone bootstrap ──────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --php-version) export PHP_VERSION="$2"; shift 2 ;;
            --php-handler) export PHP_HANDLER="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
fi

# ── Parameters ────────────────────────────────────────────────
ask_param_optional PHP_VERSION "PHP version to install (e.g. 8.1, 8.2, 8.3)" "8.2"
ask_param_optional PHP_HANDLER "PHP handler (fpm or mod)"                      "fpm"

if [[ "$PHP_HANDLER" != "fpm" && "$PHP_HANDLER" != "mod" ]]; then
    log_error "PHP_HANDLER must be 'fpm' or 'mod'. Got: '${PHP_HANDLER}'"
    exit 1
fi

# ── 3.1 Core packages ─────────────────────────────────────────
log_info "3.1  Installing Apache, MariaDB, Certbot, VSFTPD..."
log_step "apt install apache2 mariadb-server mariadb-client certbot python3-certbot-apache vsftpd"
sudo apt install -y apache2 mariadb-server mariadb-client \
    certbot python3-certbot-apache vsftpd
log_success "Core packages installed."

# ── 3.2 PHP via Ondřej Surý PPA ───────────────────────────────
log_info "3.2  Adding Ondřej Surý PHP PPA..."
log_step "add-apt-repository ppa:ondrej/php"
sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get update -y

log_info "3.2  Installing PHP ${PHP_VERSION} and extensions (handler: ${PHP_HANDLER})..."
log_step "apt install php${PHP_VERSION} + extensions"
PHP_HANDLER_PKG="php${PHP_VERSION}-fpm"
[[ "$PHP_HANDLER" == "mod" ]] && PHP_HANDLER_PKG="libapache2-mod-php${PHP_VERSION}"

# sudo apt install -y \
#     "php${PHP_VERSION}" \
#     "${PHP_HANDLER_PKG}" \
#     "php${PHP_VERSION}-cli" \
#     "php${PHP_VERSION}-mysql" \
#     "php${PHP_VERSION}-zip" \
#     "php${PHP_VERSION}-ldap" \
#     "php${PHP_VERSION}-xml" \
#     "php${PHP_VERSION}-gd" \
#     "php${PHP_VERSION}-curl" \
#     "php${PHP_VERSION}-tidy" \
#     "php${PHP_VERSION}-mbstring" \
#     "php${PHP_VERSION}-intl" \
#     "php${PHP_VERSION}-soap" \
#     "php${PHP_VERSION}-imagick"

sudo apt install -y "php${PHP_VERSION} php${PHP_VERSION}-{cli,mysql,zip,ldap,xml,gd,curl,tidy,mbstring,intl,xmlrpc,soap,imagick}"
[[ "$PHP_HANDLER" == "fpm" ]] && sudo apt install -y "php${PHP_VERSION}-fpm"

log_success "PHP ${PHP_VERSION} and extensions installed."

# ── 3.3 Enable PHP handler in Apache ──────────────────────────
if [[ "$PHP_HANDLER" == "fpm" ]]; then
    log_info "3.3  Enabling PHP-FPM in Apache..."
    log_step "a2enconf php${PHP_VERSION}-fpm && a2enmod proxy_fcgi setenvif"
    sudo a2enconf "php${PHP_VERSION}-fpm"
    sudo a2enmod proxy_fcgi setenvif
else
    log_info "3.3  Enabling mod_php in Apache..."
    log_step "a2enmod php${PHP_VERSION}"
    sudo a2enmod "php${PHP_VERSION}"
fi

# ── 3.4 Enable services on boot ───────────────────────────────
log_info "3.4  Enabling services to start on boot..."
sudo systemctl enable apache2
sudo systemctl enable mariadb
sudo systemctl enable vsftpd
[[ "$PHP_HANDLER" == "fpm" ]] && sudo systemctl enable "php${PHP_VERSION}-fpm"
log_success "All services enabled."

# ── 3.5 Start and verify ──────────────────────────────────────
log_info "3.5  Restarting Apache and verifying service status..."
sudo systemctl restart apache2

APACHE_STATUS=$(systemctl is-active apache2)
MARIADB_STATUS=$(systemctl is-active mariadb)
APACHE_VER=$(apache2 -v 2>/dev/null | awk '/Server version/{print $3}')
PHP_VER=$(php -r "echo PHP_VERSION;" 2>/dev/null || echo "unknown")
MARIADB_VER=$(mysql --version 2>/dev/null | awk '{print $5}' | tr -d ',' || echo "unknown")

log_success "Apache  : ${APACHE_STATUS} (${APACHE_VER})"
log_success "MariaDB : ${MARIADB_STATUS} (${MARIADB_VER})"
if [[ "$PHP_HANDLER" == "fpm" ]]; then
    PHP_FPM_STATUS=$(systemctl is-active "php${PHP_VERSION}-fpm")
    log_success "PHP-FPM : ${PHP_FPM_STATUS} (PHP ${PHP_VER})"
else
    PHP_FPM_STATUS="n/a (mod_php)"
    log_success "mod_php : active — embedded in Apache (PHP ${PHP_VER})"
fi

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "3_lamp_install",
  "status": "success",
  "stack": {
    "apache": {
      "version": "${APACHE_VER}",
      "status": "${APACHE_STATUS}"
    },
    "php": {
      "version": "${PHP_VER}",
      "handler": "${PHP_HANDLER}",
      "fpm_status": "${PHP_FPM_STATUS}",
      "extensions": ["mysqli","gd","intl","curl","zip","mbstring","soap","imagick","ldap","tidy"]
    },
    "mariadb": {
      "version": "${MARIADB_VER}",
      "status": "${MARIADB_STATUS}"
    }
  }
}
EOF
)"
