#!/bin/bash
# ============================================================
# Phase 5 — Database Security & Setup
# Hardens MariaDB, creates the application database and user,
# and verifies the connection.
# Can be run standalone:  sudo ./phases/05_database.sh [OPTIONS]
#   OPTIONS: --db-name NAME  --db-user USER  --db-pass PASS
# ============================================================

# ── Standalone bootstrap ──────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --db-name) export DB_NAME="$2"; shift 2 ;;
            --db-user) export DB_USER="$2"; shift 2 ;;
            --db-pass) export DB_PASS="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
fi

# ── Parameters ────────────────────────────────────────────────
ask_param    DB_NAME "Database name"     ""
ask_param    DB_USER "Database username" ""
ask_password DB_PASS "Database password"

# ── 5.1 Harden MariaDB ────────────────────────────────────────
log_info "5.1  Hardening MariaDB (removing anonymous users, test DB, remote root)..."

log_step "DELETE anonymous users"
sudo mysql -u root -e "DELETE FROM mysql.global_priv WHERE User='';"

log_step "RESTRICT root to localhost"
sudo mysql -u root -e "DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');"

log_step "DROP DATABASE test"
sudo mysql -u root -e "DROP DATABASE IF EXISTS test;"
sudo mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

sudo mysql -u root -e "FLUSH PRIVILEGES;"
log_success "MariaDB hardened."

# ── 5.2 Create database and user ─────────────────────────────
log_info "5.2  Creating database '${DB_NAME}' and user '${DB_USER}'@localhost..."

log_step "CREATE DATABASE ${DB_NAME}"
sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

log_step "GRANT ALL on ${DB_NAME} TO ${DB_USER}@localhost"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"

sudo mysql -u root -e "FLUSH PRIVILEGES;"
log_success "Database and user created."

# ── 5.3 Connection test ───────────────────────────────────────
log_info "5.3  Verifying connection with application credentials..."
CONN_TEST=$(mysql -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" \
    -e "SELECT 'Connection OK' AS result;" 2>&1 | grep -o "Connection OK" || echo "FAILED")

if [[ "$CONN_TEST" == "Connection OK" ]]; then
    log_success "Connection test: OK"
else
    log_error "Connection test FAILED. Check credentials or grants."
    exit 1
fi

MARIADB_VER=$(mysql --version 2>/dev/null | awk '{print $5}' | tr -d ',' || echo "unknown")

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "5_database",
  "status": "success",
  "database": {
    "engine": "MariaDB",
    "version": "${MARIADB_VER}",
    "db_name": "${DB_NAME}",
    "db_user": "${DB_USER}",
    "db_pass": "(hidden)",
    "db_created": true,
    "connection_test": "${CONN_TEST}"
  }
}
EOF
)"
