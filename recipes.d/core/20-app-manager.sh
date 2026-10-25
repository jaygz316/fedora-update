#!/usr/bin/env bash
if command -v app-manager &>/dev/null || [ -x "$HOME/.local/bin/app-manager" ] || [ -x "$HOME/Applications/AppManager" ]; then
    step "Core: AppImage Manager (AppManager)"
    local app_mgr="app-manager"
    [ ! -x "$(command -v "$app_mgr" 2>/dev/null)" ] && [ -x "$HOME/.local/bin/app-manager" ] && app_mgr="$HOME/.local/bin/app-manager"
    [ ! -x "$(command -v "$app_mgr" 2>/dev/null)" ] && [ -x "$HOME/Applications/AppManager" ] && app_mgr="$HOME/Applications/AppManager"

    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would check and update installed AppImages..."
    else
        log_action "Checking and updating AppImages in ~/Applications..."
        timeout --kill-after=5s 60s "$app_mgr" --update-all >> "$LOG_FILE" 2>&1 \
            || log_warn "AppManager update check finished with warnings, continuing..."
    fi
    log_ok "AppImages synchronized."
else
    skip_step "AppManager" "not installed"
fi
