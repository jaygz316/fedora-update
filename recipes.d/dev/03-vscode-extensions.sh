#!/usr/bin/env bash
if ! command -v code &>/dev/null; then
    skip_step "Visual Studio Code" "not installed"
    return 0
fi

step "Dev: Visual Studio Code extensions"
log_action "Checking Visual Studio Code extensions..."
local proceed=true
local running=false
if is_vscode_running; then
    running=true
    if [ "${FORCE_UPDATE:-false}" != "true" ]; then
        echo -e "  ${YELLOW}[SKIP] VS Code is running; skipping extension updates (use --force to update in place).${RESET}"
        proceed=false
    fi
fi
# The CLI updates extensions on disk without closing VS Code; the open window just
# asks to reload the affected extensions, so --force no longer needs to kill it.
if [ "$proceed" = "true" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would update Visual Studio Code extensions (VS Code stays open)..."
    else
        run_silent_log code --update-extensions --force || log_warn "VS Code extension update had issues, continuing..."
        log_ok "VS Code extensions updated."
        [ "$running" = "true" ] && log_info "VS Code stayed open; reload the window if it prompts for updated extensions."
    fi
fi
