#!/usr/bin/env bash
if [ -f "$HOME/.agents/.skill-lock.json" ] && command -v npx &>/dev/null; then
    step "Dev: Agent Skills & Configurations"
    log_action "Updating Agent Skills & Configurations..."
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would run: npx -y skills update --yes --global"
        log_ok "Agent skills updated."
    else
        timeout --kill-after=10s 120s npx -y skills update --yes --global </dev/null >> "$LOG_FILE" 2>&1 || log_warn "Agent skills update had issues, continuing..."
        log_ok "Agent skills updated."
    fi
else
    skip_step "Agent Skills lockfile" "not present"
fi
