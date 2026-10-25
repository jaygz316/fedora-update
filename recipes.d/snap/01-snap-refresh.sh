#!/usr/bin/env bash
if command -v snap &>/dev/null && { systemctl is-active --quiet snapd.socket 2>/dev/null || systemctl is-active --quiet snapd 2>/dev/null; }; then
    step "Snap: Refresh Installed Packages & Runtimes"
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would refresh snap packages..."
    else
        log_action "Checking for snap updates..."
        run_silent_log sudo snap refresh || log_warn "Snap refresh had issues, continuing..."
    fi
    log_ok "Snap packages up to date."
else
    skip_step "Snap Packages" "snapd not active or not installed"
fi
