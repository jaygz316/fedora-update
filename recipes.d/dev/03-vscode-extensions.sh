#!/usr/bin/env bash
if ! command -v code &>/dev/null; then
    skip_step "Visual Studio Code" "not installed"
    return 0
fi

step "Dev: Visual Studio Code extensions"
log_action "Checking Visual Studio Code extensions..."
local was_running=false
local proceed=true
if is_vscode_running; then
    if [ "${FORCE_UPDATE:-false}" != "true" ]; then
        echo -e "  ${YELLOW}[SKIP] VS Code is running; skipping extension updates (use --force to restart).${RESET}"
        proceed=false
    elif ! safe_stop_app "Visual Studio Code" get_vscode_pids is_vscode_running; then
        proceed=false
    else
        was_running=true
    fi
fi
if [ "$proceed" = "true" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would update Visual Studio Code extensions..."
        [ "$was_running" = "true" ] && restart_app "Visual Studio Code" "code" "code" is_vscode_running
    else
        run_silent_log code --update-extensions --force || log_warn "VS Code extension update had issues, continuing..."
        log_ok "VS Code extensions updated."
        if [ "$was_running" = "true" ]; then
            restart_app "Visual Studio Code" "code" "code" is_vscode_running
        fi
    fi
fi
