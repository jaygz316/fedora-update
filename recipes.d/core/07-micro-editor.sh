#!/usr/bin/env bash
step "Core: Micro Editor"
if ! command -v micro &>/dev/null; then
    log_bootstrap "Installing Micro editor..."
    run_or_dry sudo dnf install -y micro || (curl -s https://getmic.ro | bash && mv micro "$HOME/.local/bin/") 2>/dev/null || true
fi
if command -v micro &>/dev/null; then
    run_silent_log micro -plugin update || true
    log_ok "Micro editor + plugins up to date."
else
    log_warn "Micro editor installation could not be completed."
fi
