#!/usr/bin/env bash
if command -v distrobox &>/dev/null; then
    local dboxes; dboxes="$(distrobox list --no-color 2>/dev/null | tail -n +2 | grep -v '^$' || true)"
    if [ -n "$dboxes" ]; then
        step "Dev: Distrobox Containers"
        if [ "${DRY_RUN:-false}" = "true" ]; then
            log_info "[DRY-RUN] Would upgrade packages inside distrobox containers..."
        else
            log_action "Upgrading packages inside distrobox containers..."
            run_silent_log distrobox upgrade --all || log_warn "Distrobox upgrade had issues, continuing..."
        fi
        log_ok "Distrobox containers updated."
    else
        skip_step "Distrobox" "no containers configured"
    fi
else
    skip_step "Distrobox" "not installed"
fi
