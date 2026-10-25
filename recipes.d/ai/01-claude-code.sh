#!/usr/bin/env bash
if ! command -v claude &>/dev/null; then
    skip_step "Claude Code CLI" "not installed"
    return 0
fi

step "AI: Claude Code CLI"
if [ "${_NPM_GLOBAL_SYNCED:-false}" = "true" ] && [[ "$(command -v claude 2>/dev/null || true)" == *".npm-global"* ]]; then
    log_ok "Claude Code verified (synced via NPM global)."
elif is_cli_running "claude"; then
    if [ "${FORCE_UPDATE:-false}" != "true" ]; then
        echo -e "  ${YELLOW}[SKIP] Claude Code is active; skipping update (use --force to update).${RESET}"
    else
        log_info "Updating Claude Code CLI (--force)..."
        claude update || log_warn "Claude update had issues, continuing..."
        log_ok "Claude Code updated."
    fi
else
    log_action "Checking Claude Code version..."
    claude update || log_warn "Claude update had issues, continuing..."
fi
