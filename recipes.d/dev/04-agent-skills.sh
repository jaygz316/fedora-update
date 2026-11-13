#!/usr/bin/env bash
if [ -d "$HOME/.agents" ]; then
    step "Dev: Agent Skills & Configurations"
    log_action "Updating Agent Skills & Configurations..."
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would run: npx -y skills update --yes --global && android skills update --all --agent=common && sync_agent_configs.py --install-watcher"
        log_ok "Agent skills updated."
    else
        if [ -f "$HOME/.agents/.skill-lock.json" ] && command -v npx &>/dev/null; then
            timeout --kill-after=10s 120s npx -y skills update --yes --global </dev/null >> "$LOG_FILE" 2>&1 || log_warn "Agent skills update had issues, continuing..."
        fi
        if command -v android &>/dev/null; then
            timeout --kill-after=10s 120s android skills update --all --agent=common </dev/null >> "$LOG_FILE" 2>&1 || true
        fi
        python3 "$SCRIPT_DIR/helpers/sync_agent_configs.py" --install-watcher >> "$LOG_FILE" 2>&1 || log_warn "Agent config sync had issues, continuing..."
        log_ok "Agent skills & unified configurations synced."
    fi
else
    skip_step "Agent Skills directory" "not present"
fi
