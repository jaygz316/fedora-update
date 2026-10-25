#!/usr/bin/env bash
step "Core: Bun JavaScript/TypeScript Runtime"
if ! command -v bun &>/dev/null; then
    log_bootstrap "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
    command -v bun &>/dev/null && log_ok "Bun installed ($(bun --version))." || log_warn "Bun install could not be verified."
else
    run_silent_log bun upgrade || true
    log_ok "Bun up to date ($(bun --version 2>/dev/null || echo 'current'))."
fi
