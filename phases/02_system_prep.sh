#!/bin/bash
# ============================================================
# Phase 2 — System Preparation
# Configures swap and runs apt update/upgrade.
# Can be run standalone:  sudo ./phases/02_system_prep.sh
# ============================================================

# ── Standalone bootstrap ──────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${SCRIPT_DIR}/lib/common.sh"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --swap-size) export SWAP_SIZE="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
fi

# ── Parameters ────────────────────────────────────────────────
ask_param_optional SWAP_SIZE "Swap file size (e.g. 2G, 4G)" "4G"

# ── 2.1 Update & upgrade ──────────────────────────────────────
log_info "2.1  Updating package lists..."
log_step "apt-get update"
sudo apt-get update -y

log_info "2.1  Upgrading installed packages (this may take a while)..."
log_step "apt-get upgrade"
sudo apt-get upgrade -y

log_success "System packages updated and upgraded."

# ── 2.2 Swap ──────────────────────────────────────────────────
log_info "2.2  Configuring swap (${SWAP_SIZE})..."

if swapon --show | grep -q '/swapfile'; then
    log_warn "A swapfile is already active — skipping creation."
    SWAP_STATUS="already active"
else
    log_step "fallocate -l ${SWAP_SIZE} /swapfile"
    sudo fallocate -l "${SWAP_SIZE}" /swapfile

    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    # Persist across reboots
    if ! grep -q '/swapfile' /etc/fstab; then
        echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
        log_info "Swap entry added to /etc/fstab."
    fi

    SWAP_STATUS="active"
    log_success "Swap configured: ${SWAP_SIZE}"
fi

sudo swapon --show

# ── JSON Confirmation ─────────────────────────────────────────
phase_json "$(cat <<EOF
{
  "phase": "2_system_prep",
  "status": "success",
  "system": {
    "apt_updated": true,
    "apt_upgraded": true,
    "swap_size": "${SWAP_SIZE}",
    "swap_status": "${SWAP_STATUS}"
  }
}
EOF
)"
