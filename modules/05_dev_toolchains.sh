#!/usr/bin/env bash
# modules/05_dev_toolchains.sh - SDKMAN!, Google Cloud SDK, VS Code, and Agent Skills
#

set -u

run_dev_toolchains() {
    # 1. SDKMAN!
    if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
        step "Dev: SDKMAN! candidates & framework"
        log_action "Checking SDKMAN! candidate versions..."
        (
            set +u
            # shellcheck disable=SC1091
            source "$HOME/.sdkman/bin/sdkman-init.sh"
            sdk selfupdate force >/dev/null 2>&1 || true
            sdk update
        ) || log_warn "SDKMAN! update encountered issues, continuing..."
        log_ok "SDKMAN! updated."
    else
        skip_step "SDKMAN!" "not installed"
    fi

    # 2. Google Cloud SDK
    if [ -d "$HOME/google-cloud-sdk" ] && command -v gcloud &>/dev/null; then
        step "Dev: Google Cloud SDK components"
        log_action "Checking Google Cloud SDK components..."
        gcloud components update --quiet || log_warn "Google Cloud SDK update encountered issues, continuing..."
        log_ok "Google Cloud SDK components updated."
    else
        skip_step "Google Cloud SDK" "not installed"
    fi

    # 3. Visual Studio Code Extensions
    if command -v code &>/dev/null; then
        step "Dev: Visual Studio Code extensions"
        log_action "Checking and updating installed VS Code extensions..."
        if is_vscode_running; then
            echo -e "  ${YELLOW}[SKIP] VS Code is currently running; skipping extension updates to prevent conflict.${RESET}"
        else
            code --update-extensions --force || log_warn "VS Code extension update encountered issues, continuing..."
            log_ok "VS Code extensions updated."
        fi
    else
        skip_step "Visual Studio Code ('code')" "not installed"
    fi

    # 4. Agent Skills Lockfile
    if [ -f "$HOME/.agents/.skill-lock.json" ] && command -v npx &>/dev/null; then
        step "Dev: Agent Skills & Configurations"
        log_action "Checking Agent skills lockfile for updates..."
        timeout 60s npx -y skills update --yes || log_warn "Agent skills update encountered issues, continuing..."
        log_ok "Agent skills updated."
    else
        skip_step "Agent Skills lockfile" "not present"
    fi
}
