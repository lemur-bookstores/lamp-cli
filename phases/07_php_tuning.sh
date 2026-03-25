#!/bin/bash
# ============================================================
# Phase 7 — PHP Performance Tuning
# Applies php.ini optimizations for Moodle / LMS workloads.
# Can be run standalone:  sudo ./phases/07_php_tuning.sh [--php-version 8.2]
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
echo ""
log_info "Leave any value blank to keep the recommended default."
echo ""
ask_param_optional PHP_VERSION        "PHP version (must match installed)"       "8.2"
ask_param_optional PHP_HANDLER        "PHP handler (fpm or mod)"                 "fpm"
ask_param_optional PHP_MAX_INPUT_VARS "max_input_vars  (Moodle needs 5000+)"     "5000"
ask_param_optional PHP_MAX_EXEC_TIME  "max_execution_time  (seconds)"            "250"
ask_param_optional PHP_POST_MAX_SIZE  "post_max_size       (e.g. 50M)"           "50M"
ask_param_optional PHP_UPLOAD_MAX     "upload_max_filesize (e.g. 50M)"           "50M"
ask_param_optional PHP_MAX_INPUT_TIME "max_input_time      (seconds)"            "250"

if [[ "${PHP_HANDLER:-fpm}" == "fpm" ]]; then
    PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
else
    PHP_INI="/etc/php/${PHP_VERSION}/apache2/php.ini"
fi

if [[ ! -f "$PHP_INI" ]]; then
    log_error "php.ini not found at ${PHP_INI}. Is PHP ${PHP_VERSION} installed?"
    exit 1
fi

log_info "7.1  Applying settings to ${PHP_INI}..."

# Regex handles both commented (;directive) and active forms
apply_ini() {
    local directive="$1" value="$2"
    log_step "Setting ${directive} = ${value}"
    sudo sed -i "s/^[;[:space:]]*${directive}[[:space:]]*=.*/${directive} = ${value}/" "${PHP_INI}"
}

apply_ini "max_input_vars"    "${PHP_MAX_INPUT_VARS}"
apply_ini "max_execution_time" "${PHP_MAX_EXEC_TIME}"
apply_ini "post_max_size"     "${PHP_POST_MAX_SIZE}"
apply_ini "upload_max_filesize" "${PHP_UPLOAD_MAX}"
apply_ini "max_input_time"    "${PHP_MAX_INPUT_TIME}"

# ── 7.2 Restart and verify ────────────────────────────────────
if [[ "${PHP_HANDLER:-fpm}" == "fpm" ]]; then
    log_info "7.2  Restarting PHP-FPM and Apache..."
    sudo systemctl restart "php${PHP_VERSION}-fpm"
    FPM_RESTARTED=true
else
    log_info "7.2  Restarting Apache (mod_php — no FPM service)..."
    FPM_RESTARTED=false
fi
sudo systemctl restart apache2
log_success "Services restarted."

log_info "7.2  Verifying values from CLI SAPI (note: FPM/mod_php reads same php.ini):"
php -r "
echo '  upload_max_filesize  : ' . ini_get('upload_max_filesize')  . PHP_EOL;
echo '  post_max_size        : ' . ini_get('post_max_size')         . PHP_EOL;
echo '  max_execution_time   : ' . ini_get('max_execution_time')    . PHP_EOL;
echo '  max_input_vars       : ' . ini_get('max_input_vars')        . PHP_EOL;
echo '  max_input_time       : ' . ini_get('max_input_time')        . PHP_EOL;
"

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "7_php_tuning",
  "status": "success",
  "php_ini": {
    "path": "${PHP_INI}",
    "php_handler": "${PHP_HANDLER}",
    "max_input_vars": "${PHP_MAX_INPUT_VARS}",
    "max_execution_time": "${PHP_MAX_EXEC_TIME}",
    "post_max_size": "${PHP_POST_MAX_SIZE}",
    "upload_max_filesize": "${PHP_UPLOAD_MAX}",
    "max_input_time": "${PHP_MAX_INPUT_TIME}",
    "fpm_restarted": ${FPM_RESTARTED}
  }
}
EOF
)"
