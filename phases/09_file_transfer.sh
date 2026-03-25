#!/bin/bash
# ============================================================
# Phase 9 — File Transfer Service
# Branches on FTP_MODE:
#   ftps  → VSFTPD + TLS (uses Let's Encrypt cert from Phase 6)
#   sftp  → SSH subsystem chrooted to the vhost directory
# Can be run standalone:  sudo ./phases/09_file_transfer.sh [OPTIONS]
#   OPTIONS: --domain DOMAIN  --ftp-mode ftps|sftp
#            --ftp-user USER  --ftp-pass PASS
# ============================================================

# ── Standalone bootstrap ──────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain)   export DOMAIN="$2";   shift 2 ;;
            --ftp-mode) export FTP_MODE="$2"; shift 2 ;;
            --ftp-user) export FTP_USER="$2"; shift 2 ;;
            --ftp-pass) export FTP_PASS="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
fi

# ── Parameters ────────────────────────────────────────────────
ask_param          DOMAIN   "Primary domain (vhost root)" ""
ask_param_optional FTP_MODE "File transfer mode (ftps or sftp)" "ftps"

# Validate FTP_MODE
if [[ "$FTP_MODE" != "ftps" && "$FTP_MODE" != "sftp" ]]; then
    log_error "FTP_MODE must be 'ftps' or 'sftp'. Got: '${FTP_MODE}'"
    exit 1
fi

ask_param    FTP_USER "Transfer username"   ""
ask_password FTP_PASS "Transfer password"

VHOST_ROOT="/var/www/vhosts/${DOMAIN}"

# ── 9.1 Create transfer user ──────────────────────────────────
log_info "9.1  Creating transfer user '${FTP_USER}'..."

if id "${FTP_USER}" &>/dev/null; then
    log_warn "User '${FTP_USER}' already exists — skipping adduser."
else
    log_step "adduser --disabled-password ${FTP_USER}"
    sudo adduser --disabled-password --gecos "" "${FTP_USER}"
fi

log_step "chpasswd"
echo "${FTP_USER}:${FTP_PASS}" | sudo chpasswd

log_step "usermod -a -G www-data ubuntu && usermod -a -G www-data ${FTP_USER}"
sudo usermod -a -G www-data ubuntu
sudo usermod -a -G www-data "${FTP_USER}"
log_success "Transfer user configured."

# ── 9.2 Branch: SFTP or FTPS ─────────────────────────────────
if [[ "$FTP_MODE" == "sftp" ]]; then
    # ── SFTP (SSH subsystem — more secure, no extra daemon) ──────
    log_info "9.2  Configuring SFTP (SSH subsystem, chrooted)..."

    # Add user to sftpusers group
    if ! getent group sftpusers &>/dev/null; then
        sudo groupadd sftpusers
    fi
    sudo usermod -a -G sftpusers "${FTP_USER}"

    # Append sshd_config block if not already present
    if ! grep -q "Match Group sftpusers" /etc/ssh/sshd_config; then
        sudo tee -a /etc/ssh/sshd_config > /dev/null <<SSHCONF

Match Group sftpusers
    ChrootDirectory ${VHOST_ROOT}
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
SSHCONF
        log_success "sshd_config updated."
    else
        log_warn "sshd_config already has Match Group sftpusers — skipping."
    fi

    log_step "systemctl restart ssh"
    sudo systemctl restart ssh
    SERVICE_NAME="ssh"
    SERVICE_STATUS=$(systemctl is-active ssh)
    CONNECTION_INFO="SFTP on port 22 — use your SFTP client (FileZilla, WinSCP, etc.)"

else
    # ── FTPS (VSFTPD + TLS — uses Let's Encrypt cert) ────────────
    log_info "9.2  Configuring FTPS via VSFTPD..."

    CERT_FULLCHAIN="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
    CERT_PRIVKEY="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"

    if [[ ! -f "$CERT_FULLCHAIN" ]]; then
        log_warn "Let's Encrypt cert not found at ${CERT_FULLCHAIN}."
        log_warn "Phase 6 (SSL) must complete before FTPS can use TLS."
        log_warn "VSFTPD will be configured but TLS will not work until certs exist."
    fi

    log_step "Writing /etc/vsftpd.conf"
    sudo tee /etc/vsftpd.conf > /dev/null <<VSFTPDCONF
# ── Base ─────────────────────────────────────────────────────
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=002
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES

# ── Passive ports (open 49152-65535 TCP in Lightsail firewall) ─
connect_from_port_20=YES
pasv_enable=YES
pasv_min_port=49152
pasv_max_port=65535

# ── TLS/FTPS — requires Let's Encrypt cert from Phase 6 ───────
ssl_enable=YES
rsa_cert_file=${CERT_FULLCHAIN}
rsa_private_key_file=${CERT_PRIVKEY}
allow_anon_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO

# ── Chroot jail ───────────────────────────────────────────────
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
allow_writeable_chroot=YES

# ── Default root ──────────────────────────────────────────────
local_root=${VHOST_ROOT}
VSFTPDCONF

    log_step "systemctl restart vsftpd"
    sudo systemctl restart vsftpd
    SERVICE_NAME="vsftpd"
    SERVICE_STATUS=$(systemctl is-active vsftpd)
    CONNECTION_INFO="FTPS on port 21 — use Explicit TLS in your FTP client."
fi

log_success "File transfer service: ${SERVICE_STATUS}"
log_info "  ${CONNECTION_INFO}"

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "9_file_transfer",
  "status": "success",
  "file_transfer": {
    "mode": "${FTP_MODE}",
    "ftp_user": "${FTP_USER}",
    "ftp_pass": "(hidden)",
    "chroot_path": "${VHOST_ROOT}",
    "service": "${SERVICE_NAME}",
    "service_status": "${SERVICE_STATUS}",
    "connection_info": "${CONNECTION_INFO}"
  }
}
EOF
)"
