#!/usr/bin/env bash
step "Core: Astral uv package manager"
if ! command -v uv &>/dev/null; then
    log_bootstrap "Installing Astral uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
else
    run_silent_log uv self update || true
    if [ -d "$HOME/.local/share/uv/python" ] && [ -n "$(ls -A "$HOME/.local/share/uv/python" 2>/dev/null)" ]; then
        log_action "Upgrading installed uv Python runtimes..."
        run_silent_log uv python upgrade || true
    fi
    log_ok "uv up to date."
fi
