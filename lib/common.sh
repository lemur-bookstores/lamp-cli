#!/bin/bash
# ============================================================
# lib/common.sh — Shared utilities for the LAMP CLI installer
# ============================================================

# ── Colours ──────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Logging ──────────────────────────────────────────────────
log_info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}   $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET}  $*" >&2; }
log_step()    { echo -e "  ${CYAN}▶${RESET} $*"; }

log_phase() {
    echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}══════════════════════════════════════════════${RESET}\n"
}

# ── ask_param ─────────────────────────────────────────────────
# Usage: ask_param  VAR_NAME "Human prompt" ["default"]
# If the variable is already set (CLI arg or prior phase), skip prompt.
# If no default and user leaves blank, re-prompt until a value is given.
ask_param() {
    local var_name="$1"
    local prompt="$2"
    local default="${3:-}"
    local value="${!var_name:-}"

    if [[ -n "$value" ]]; then
        log_info "${var_name} = ${value}"
        return 0
    fi

    local input
    if [[ -n "$default" ]]; then
        read -r -p "  ${prompt} [${default}]: " input
        input="${input:-$default}"
    else
        while [[ -z "$input" ]]; do
            read -r -p "  ${prompt}: " input
            [[ -z "$input" ]] && log_warn "This field is required."
        done
    fi

    export "$var_name"="$input"
}

# ── ask_param_optional ────────────────────────────────────────
# Like ask_param but always has a default — accepts blank to use default.
ask_param_optional() {
    local var_name="$1"
    local prompt="$2"
    local default="${3:-}"

    [[ -n "${!var_name:-}" ]] && { log_info "${var_name} = ${!var_name}"; return 0; }

    local input
    read -r -p "  ${prompt} [${default}]: " input
    export "$var_name"="${input:-$default}"
    log_info "${var_name} = ${!var_name}"
}

# ── ask_password ──────────────────────────────────────────────
# Hidden input with confirmation. Skips if var already set.
ask_password() {
    local var_name="$1"
    local prompt="$2"

    [[ -n "${!var_name:-}" ]] && { log_info "${var_name} = (already set)"; return 0; }

    local value confirm
    while true; do
        read -r -s -p "  ${prompt}: " value
        echo
        read -r -s -p "  Confirm ${prompt}: " confirm
        echo
        if [[ "$value" == "$confirm" ]]; then
            export "$var_name"="$value"
            break
        fi
        log_warn "Passwords do not match. Try again."
    done
}

# ── phase_json ────────────────────────────────────────────────
# Pretty-print the JSON confirmation block for a phase.
phase_json() {
    echo -e "\n${GREEN}── JSON Confirmation ──────────────────────────────${RESET}"
    if command -v python3 &>/dev/null; then
        echo "$1" | python3 -m json.tool 2>/dev/null || echo "$1"
    else
        echo "$1"
    fi
    echo -e "${GREEN}────────────────────────────────────────────────────${RESET}\n"
}

# ── require_sudo ──────────────────────────────────────────────
require_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This phase requires elevated privileges. Re-run with: sudo $0 $*"
        exit 1
    fi
}
