#!/bin/bash
# ============================================================
# Phase 8 — MariaDB Performance Tuning
# Calculates innodb_buffer_pool_size from actual RAM and
# applies safe tuning defaults to 50-server.cnf.
# Can be run standalone:  sudo ./phases/08_mariadb_tuning.sh [--mariadb-ratio 60]
# ============================================================

# ── Standalone bootstrap ──────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mariadb-ratio) export MARIADB_BUFFER_RATIO="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
fi

# ── Parameters ────────────────────────────────────────────────
ask_param_optional MARIADB_BUFFER_RATIO \
    "InnoDB buffer pool % of total RAM (recommended: 50-70)" "60"

MARIADB_CNF="/etc/mysql/mariadb.conf.d/50-server.cnf"

if [[ ! -f "$MARIADB_CNF" ]]; then
    log_error "Config file not found: ${MARIADB_CNF}. Is MariaDB installed?"
    exit 1
fi

# ── 8.1 Calculate buffer size from actual RAM ─────────────────
log_info "8.1  Detecting available RAM..."
RAM_TOTAL_MB=$(free -m | awk '/^Mem:/{print $2}')
INNODB_BUFFER_MB=$(( RAM_TOTAL_MB * MARIADB_BUFFER_RATIO / 100 ))

log_info "  Total RAM          : ${RAM_TOTAL_MB} MB"
log_info "  Buffer ratio       : ${MARIADB_BUFFER_RATIO}%"
log_info "  innodb_buffer_pool : ${INNODB_BUFFER_MB} MB"

# ── 8.2 Apply configuration ───────────────────────────────────
log_info "8.2  Applying settings to ${MARIADB_CNF}..."

apply_mariadb() {
    local key="$1" val="$2"
    log_step "Setting ${key} = ${val}"

    # Update existing (commented or active) line
    if grep -qE "^[#[:space:]]*${key}[[:space:]]*=" "${MARIADB_CNF}"; then
        sudo sed -i "s/^[#[:space:]]*${key}[[:space:]]*=.*/${key} = ${val}/" "${MARIADB_CNF}"
    else
        # Append under [mysqld] section
        sudo sed -i "/^\[mysqld\]/a ${key} = ${val}" "${MARIADB_CNF}"
    fi
}

apply_mariadb "innodb_buffer_pool_size" "${INNODB_BUFFER_MB}M"

# Additional safe defaults — insert only if not already present
for setting in \
    "innodb_log_file_size = 64M" \
    "query_cache_size = 0" \
    "query_cache_type = 0" \
    "max_connections = 150"
do
    key="${setting%% =*}"
    if ! grep -qE "^${key}[[:space:]]*=" "${MARIADB_CNF}"; then
        log_step "Appending ${setting}"
        sudo sed -i "/^\[mysqld\]/a ${setting}" "${MARIADB_CNF}"
    else
        log_info "  ${key} already set — skipping."
    fi
done

# ── 8.3 Restart and verify ────────────────────────────────────
log_info "8.3  Restarting MariaDB and verifying..."
sudo systemctl restart mariadb

MARIADB_STATUS=$(systemctl is-active mariadb)
log_success "MariaDB status: ${MARIADB_STATUS}"

# Confirm the buffer pool value was applied
APPLIED_BYTES=$(sudo mysql -u root -e \
    "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" 2>/dev/null \
    | awk 'NR==2{print $2}' || echo "unknown")
log_info "  innodb_buffer_pool_size (bytes): ${APPLIED_BYTES}"

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "8_mariadb_tuning",
  "status": "success",
  "mariadb_tuning": {
    "config_file": "${MARIADB_CNF}",
    "ram_total_mb": ${RAM_TOTAL_MB},
    "buffer_ratio_pct": ${MARIADB_BUFFER_RATIO},
    "innodb_buffer_pool_size": "${INNODB_BUFFER_MB}M",
    "innodb_log_file_size": "64M",
    "query_cache_size": "0",
    "max_connections": "150",
    "mariadb_status": "${MARIADB_STATUS}"
  }
}
EOF
)"
