#!/usr/bin/env bash
step "Core: Herdr CLI"
if ! command -v herdr &>/dev/null; then
    log_bootstrap "Installing Herdr CLI..."
    curl -fsSL https://herdr.dev/install.sh | bash 2>/dev/null || true
    command -v herdr &>/dev/null && log_ok "Herdr CLI installed." || log_warn "Herdr CLI install could not be verified."
else
    local cv_h; cv_h="$(herdr --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
    local lv_h; lv_h="$(curl -s --max-time 3 'https://herdr.dev/latest.json' 2>/dev/null | grep -m1 '"version":' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
    if [ -n "$cv_h" ] && [ -n "$lv_h" ] && [ "$cv_h" = "$lv_h" ]; then
        log_ok "Herdr up to date ($cv_h)."
    elif is_cli_running "herdr"; then
        if [ "${FORCE_UPDATE:-false}" != "true" ]; then
            echo -e "  ${YELLOW}[SKIP] Herdr is active; skipping update (use --force to update).${RESET}"
        else
            log_info "Updating Herdr CLI with session handoff (--force)..."
            run_silent_log herdr update --handoff || run_silent_log herdr update || true
            log_ok "Herdr updated to ${lv_h:-latest}."
        fi
    else
        log_info "Updating Herdr CLI..."
        run_silent_log herdr update || true
        log_ok "Herdr updated to ${lv_h:-latest}."
    fi
fi
