#!/bin/bash
# ============================================================
# setup-cli.sh — Install lamp-cli Globally
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/lemur-bookstores/lamp-cli/main/setup-cli.sh | sudo bash
#
# Or:
#   sudo bash setup-cli.sh [INSTALL_DIR]
#
# Environment Variables:
#   INSTALL_DIR — Installation directory (default: /opt/lamp-cli)
# ============================================================

set -e

# Configuration
INSTALL_DIR="${INSTALL_DIR:-/opt/lamp-cli}"
BIN_LINK="/usr/local/bin/lamp-cli"
REPO_URL="https://github.com/lemur-bookstores/lamp-cli.git"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Helper functions
log_info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[✓]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[!]${RESET}    $*"; }
log_error()   { echo -e "${RED}[✗]${RESET}    $*" >&2; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run with sudo"
    exit 1
fi

# Display header
echo -e "${BOLD}${BLUE}"
cat <<'BANNER'
  ██╗      █████╗ ███╗   ███╗██████╗      ██████╗██╗     ██╗
  ██║     ██╔══██╗████╗ ████║██╔══██╗    ██╔════╝██║     ██║
  ██║     ███████║██╔████╔██║██████╔╝    ██║     ██║     ██║
  ██║     ██╔══██║██║╚██╔╝██║██╔═══╝     ██║     ██║     ██║
  ███████╗██║  ██║██║ ╚═╝ ██║██║         ╚██████╗███████╗██║
  ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝          ╚═════╝╚══════╝╚═╝
                  Global Installation Script
BANNER
echo -e "${RESET}"

log_info "Installing lamp-cli globally..."
log_info "Installation directory: ${INSTALL_DIR}"
log_info "Binary link: ${BIN_LINK}"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    log_error "git is not installed. Installing..."
    apt-get update -qq && apt-get install -y git > /dev/null 2>&1
    log_success "git installed"
fi

# Clone or update repository
if [[ -d "$INSTALL_DIR" ]]; then
    log_info "Directory ${INSTALL_DIR} already exists."
    log_info "Updating from remote..."

    cd "$INSTALL_DIR"
    git fetch origin main > /dev/null 2>&1 || {
        log_error "Failed to fetch from git repository"
        exit 1
    }

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_warn "Uncommitted changes detected. Stashing..."
        git stash > /dev/null 2>&1 || true
    fi

    git checkout main > /dev/null 2>&1 || {
        log_error "Failed to checkout main branch"
        exit 1
    }

    git pull origin main > /dev/null 2>&1 || {
        log_error "Failed to pull updates"
        exit 1
    }

    log_success "Repository updated"
else
    log_info "Cloning repository..."

    git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1 || {
        log_error "Failed to clone repository from ${REPO_URL}"
        exit 1
    }

    log_success "Repository cloned"
fi

# Make scripts executable
log_info "Making scripts executable..."
chmod +x "${INSTALL_DIR}/init.sh" || {
    log_error "Failed to chmod init.sh"
    exit 1
}

if [[ -d "${INSTALL_DIR}/phases" ]]; then
    find "${INSTALL_DIR}/phases" -name "*.sh" -exec chmod +x {} \; || {
        log_error "Failed to chmod phase scripts"
        exit 1
    }
fi

if [[ -d "${INSTALL_DIR}/lib" ]]; then
    find "${INSTALL_DIR}/lib" -name "*.sh" -exec chmod +x {} \; || {
        log_error "Failed to chmod lib scripts"
        exit 1
    }
fi

if [[ -d "${INSTALL_DIR}/wsl-port_proxy" ]]; then
    find "${INSTALL_DIR}/wsl-port_proxy" -name "*.sh" -exec chmod +x {} \; || {
        log_error "Failed to chmod wsl-port_proxy scripts"
        exit 1
    }
fi

log_success "Scripts are executable"

# Remove existing symlink if present
if [[ -L "$BIN_LINK" ]]; then
    log_info "Removing existing symlink..."
    rm "$BIN_LINK" || {
        log_error "Failed to remove existing symlink"
        exit 1
    }
elif [[ -f "$BIN_LINK" ]]; then
    log_warn "Regular file exists at ${BIN_LINK}. Backing up to ${BIN_LINK}.bak"
    mv "$BIN_LINK" "${BIN_LINK}.bak" || {
        log_error "Failed to backup existing file"
        exit 1
    }
fi

# Create symlink
log_info "Creating symlink at ${BIN_LINK}..."
ln -s "${INSTALL_DIR}/init.sh" "$BIN_LINK" || {
    log_error "Failed to create symlink"
    exit 1
}

log_success "Symlink created"

# Verify installation
if [[ -x "$BIN_LINK" ]] && [[ -L "$BIN_LINK" ]]; then
    log_success "Installation completed successfully!"
    echo ""
    log_info "You can now run:"
    echo "    ${BOLD}sudo lamp-cli${RESET}"
    echo ""
    log_info "For help:"
    echo "    ${BOLD}sudo lamp-cli --help${RESET}"
    echo ""
    log_info "For interactive setup:"
    echo "    ${BOLD}sudo lamp-cli${RESET}"
    echo ""
    log_info "For full deployment:"
    echo "    ${BOLD}sudo lamp-cli --domain example.com --phases all${RESET}"
    echo ""
else
    log_error "Installation verification failed"
    exit 1
fi

log_info "Installation directory: ${INSTALL_DIR}"
log_info "To update later, run: ${BOLD}cd ${INSTALL_DIR} && sudo git pull${RESET}"
log_info "To uninstall, run: ${BOLD}sudo rm ${BIN_LINK} && sudo rm -rf ${INSTALL_DIR}${RESET}"
echo ""
