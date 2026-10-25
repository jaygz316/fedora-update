#!/usr/bin/env bash
step "Core: Agy CLI"
if ! command -v agy &>/dev/null; then
    log_bootstrap "Installing Agy CLI..."
    run_silent_log npm install -g @google/agy || true
    command -v agy &>/dev/null && log_ok "Agy CLI installed." || log_warn "Agy CLI installation could not be completed."
elif is_cli_running "agy"; then
    if [ "${FORCE_UPDATE:-false}" != "true" ]; then
        echo -e "  ${YELLOW}[SKIP] Agy is active; skipping update (use --force to update).${RESET}"
    else
        log_info "Updating Agy CLI (--force)..."
        run_silent_log agy update || run_silent_log npm install -g @google/agy || true
        log_ok "Agy CLI up to date."
    fi
else
    run_silent_log agy update || true
    log_ok "Agy CLI up to date."
fi
