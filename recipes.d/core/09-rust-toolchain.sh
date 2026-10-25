#!/usr/bin/env bash
step "Core: Rust Toolchain & Cargo Tools (rustup)"
if ! command -v rustup &>/dev/null && [ ! -f "$HOME/.cargo/bin/rustup" ]; then
    log_bootstrap "Installing Rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
    export PATH="$HOME/.cargo/bin:$PATH"
fi
if command -v rustup &>/dev/null || [ -x "$HOME/.cargo/bin/rustup" ]; then
    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
    rustup update 2>&1 | tee -a "$LOG_FILE" | grep -E "(installed|updated|unchanged)" | sed 's/^/  /' || true
    if [ -x "$HOME/.cargo/bin/cargo-tauri" ]; then
        local current_tauri latest_tauri
        current_tauri="$(cargo tauri --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
        latest_tauri="$(curl -s --max-time 5 'https://crates.io/api/v1/crates/tauri-cli' 2>/dev/null | grep -o '"max_version":"[^"]*"' | cut -d'"' -f4 || true)"
        if [ -n "$current_tauri" ] && [ -n "$latest_tauri" ] && [ "$current_tauri" = "$latest_tauri" ]; then
            log_ok "tauri-cli already up to date ($current_tauri)."
        else
            log_action "Updating tauri-cli (${current_tauri:-unknown} -> $latest_tauri)..."
            run_silent_log cargo install tauri-cli --locked || true
        fi
    fi
    log_ok "Rust toolchain up to date."
else
    log_warn "Rust toolchain installation could not be completed."
fi
