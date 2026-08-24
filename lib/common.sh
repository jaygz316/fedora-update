#!/usr/bin/env bash
# lib/common.sh - Shared utilities, formatting, logging, and sudo/polkit management
#

set -u

# Source Cargo env if present
if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env" 2>/dev/null || true
fi

# Ensure PATH includes all user toolchains and binaries across all nodes
for dir in \
    "$HOME/.local/bin" \
    "$HOME/bin" \
    "$HOME/.cargo/bin" \
    "$HOME/.bun/bin" \
    "$HOME/.npm-global/bin" \
    "$HOME/.lmstudio/bin" \
    "$HOME/google-cloud-sdk/bin" \
    "$HOME/go/bin" \
    "$HOME/Android/Sdk/cmdline-tools/latest/bin" \
    "$HOME/Android/Sdk/platform-tools" \
    "$HOME/Android/Sdk/emulator" \
    "$HOME/.local/opt/android-studio-preview/bin"
do
    if [ -d "$dir" ] && [[ ":$PATH:" != *":$dir:"* ]]; then
        PATH="$dir:$PATH"
    fi
done
export PATH

# Terminal Formatting & Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
RESET="\033[0m"

# Ensure unbuffered execution and non-interactive safety across sub-tools
export PYTHONUNBUFFERED=1
export GIT_TERMINAL_PROMPT=0
export FORCE_COLOR=1
export CLICOLOR_FORCE=1

# Step Counter
STEP_COUNT=0
TOTAL_STEPS=0

step() {
    ((STEP_COUNT++))
    if [ "$TOTAL_STEPS" -gt 0 ]; then
        echo -e "\n${BOLD}${GREEN}[+] [${STEP_COUNT}/${TOTAL_STEPS}] $1...${RESET}"
    else
        echo -e "\n${BOLD}${GREEN}[+] [${STEP_COUNT}] $1...${RESET}"
    fi
}

skip_step() {
    ((STEP_COUNT++))
    local title="$1"
    local reason="${2:-not found}"
    if [ "$TOTAL_STEPS" -gt 0 ]; then
        echo -e "\n${YELLOW}[-] [${STEP_COUNT}/${TOTAL_STEPS}] ${title} (${reason}, skipping)${RESET}"
    else
        echo -e "\n${YELLOW}[-] [${STEP_COUNT}] ${title} (${reason}, skipping)${RESET}"
    fi
}

log_substep() {
    local current="$1"
    local total="$2"
    local msg="$3"
    echo -e "  ${BOLD}${CYAN}--> [${current}/${total}]${RESET} ${msg}"
}

log_action() {
    echo -e "  ${CYAN}... $1${RESET}"
}

log_info() {
    echo -e "  ${BOLD}[*] $1${RESET}"
}

log_ok() {
    echo -e "  ${GREEN}[OK] $1${RESET}"
}

log_warn() {
    echo -e "  ${YELLOW}^ WARNING: $1${RESET}"
}

log_err() {
    echo -e "  ${RED}^ ERROR: $1${RESET}"
}

log_bootstrap() {
    echo -e "  ${BOLD}${MAGENTA}--> [BOOTSTRAP] $1${RESET}"
}

# Logging Initialization
init_logging() {
    LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/update"
    mkdir -p "$LOG_DIR"
    TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    LOG_FILE="$LOG_DIR/update_${TIMESTAMP}.log"
    LAST_LOG="$LOG_DIR/last-update.log"

    # Clean up older log files (keep last 10)
    find "$LOG_DIR" -name "update_*.log" -type f 2>/dev/null | sort -r | tail -n +11 | xargs -r rm -f

    # Tee output to log files
    exec > >(tee -a "$LOG_FILE" | tee "$LAST_LOG") 2>&1
}

# Passwordless Sudo & Polkit Auto-Configuration
ensure_passwordless_sudo() {
    if ! command -v sudo &>/dev/null; then
        log_warn "'sudo' command not found. Elevated steps will be skipped."
        return 0
    fi

    local sudoers_file="/etc/sudoers.d/$USER"
    local polkit_rule="/etc/polkit-1/rules.d/49-nopasswd-fedora-update.rules"

    # If passwordless sudo already works
    if sudo -n true 2>/dev/null; then
        # Ensure polkit rule is created if missing
        if [ -d "/etc/polkit-1/rules.d" ] && [ ! -f "$polkit_rule" ]; then
            sudo tee "$polkit_rule" >/dev/null << EOF
/* Allow members of wheel or current user to execute administrative actions without password prompts */
polkit.addRule(function(action, subject) {
    if (subject.user == "$USER" || subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
            sudo chmod 0644 "$polkit_rule" 2>/dev/null || true
        fi
        log_ok "Passwordless sudo & Polkit verified."
    else
        echo -e "\n${BOLD}${CYAN}------------------------------------------------------------${RESET}"
        echo -e "${BOLD}${CYAN}  Passwordless Sudo & Polkit Setup                          ${RESET}"
        echo -e "${CYAN}  Configuring passwordless sudo and Polkit for 1-click runs...${RESET}"
        echo -e "${BOLD}${CYAN}------------------------------------------------------------${RESET}"
        
        if [ -t 0 ] || [ -e /dev/tty ]; then
            echo -e "  ${BOLD}[*] Authenticating once to configure system permissions:${RESET}"
            if sudo -v; then
                # 1. Sudoers drop-in
                echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee "$sudoers_file" >/dev/null
                sudo chmod 0440 "$sudoers_file"
                sudo chown root:root "$sudoers_file" 2>/dev/null || true

                # 2. Polkit rule (prevents Flatpak / AppStream / fwupd auth popups)
                if [ -d "/etc/polkit-1/rules.d" ]; then
                    sudo tee "$polkit_rule" >/dev/null << EOF
/* Allow members of wheel or current user to execute administrative actions without password prompts */
polkit.addRule(function(action, subject) {
    if (subject.user == "$USER" || subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
                    sudo chmod 0644 "$polkit_rule" 2>/dev/null || true
                fi

                if sudo -n true 2>/dev/null; then
                    log_ok "Passwordless sudo & Polkit successfully configured for $USER."
                else
                    log_warn "Configured rules, but passwordless validation returned non-zero."
                fi
            else
                log_warn "Authentication failed. Privileged operations may prompt or fail."
            fi
        else
            log_warn "Non-interactive session and passwordless sudo not configured yet. Run 'update' in a terminal once to complete 1-click setup."
        fi
    fi

    # Start background keepalive loop if sudo works
    if sudo -n true 2>/dev/null; then
        while true; do
            sudo -n true
            sleep 60
            kill -0 "$$" || exit
        done 2>/dev/null &
        SUDO_PID=$!
        trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT
    fi
}
