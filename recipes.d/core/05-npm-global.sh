#!/usr/bin/env bash
step "Core: NPM Global Configuration & Tools"
if command -v npm &>/dev/null; then
    local npm_prefix; npm_prefix="$(npm config get prefix 2>/dev/null || true)"
    if [ "$npm_prefix" = "/usr" ] || [ "$npm_prefix" = "/usr/local" ] || [ -z "$npm_prefix" ]; then
        log_bootstrap "Configuring user npm prefix → $HOME/.npm-global"
        mkdir -p "$HOME/.npm-global/bin" "$HOME/.npm-global/lib"
        npm config set prefix "$HOME/.npm-global"
        export PATH="$HOME/.npm-global/bin:$PATH"
    fi
    # Clean up any stale staging artifacts from interrupted npm updates
    rm -rf "$HOME/.npm-global/lib/node_modules/"\.*-* "$HOME/.npm-global/lib/node_modules/@google/"\.*-* "$HOME/.npm-global/bin/"\.*-* 2>/dev/null || true

    local baseline_npm=( pnpm @google/gemini-cli )
    for pkg in "${baseline_npm[@]}"; do
        if [ ! -d "$HOME/.npm-global/lib/node_modules/$pkg" ]; then
            log_bootstrap "Installing missing global NPM package $pkg..."
            run_silent_log npm install -g "$pkg" || true
        fi
    done

    local npm_outdated; npm_outdated="$(npm outdated -g --json 2>/dev/null || true)"
    if [ -n "$npm_outdated" ] && [ "$npm_outdated" != "{}" ]; then
        log_action "Updating outdated global NPM packages..."
        run_silent_log npm update -g || true
        log_ok "NPM global packages updated."
    else
        log_ok "NPM global config synced (all packages current)."
    fi

    if command -v pnpm &>/dev/null || [ -x "$HOME/.npm-global/bin/pnpm" ]; then
        local pnpm_cmd="${HOME}/.npm-global/bin/pnpm"
        [ -x "$pnpm_cmd" ] || pnpm_cmd="pnpm"
        export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
        mkdir -p "$PNPM_HOME" "$PNPM_HOME/bin" 2>/dev/null || true
        [[ ":$PATH:" != *":$PNPM_HOME:"* ]] && PATH="$PNPM_HOME:$PATH"
        [[ ":$PATH:" != *":$PNPM_HOME/bin:"* ]] && PATH="$PNPM_HOME/bin:$PATH"
        export PATH
        run_silent_log "$pnpm_cmd" update -g 2>/dev/null || true
    fi
    _NPM_GLOBAL_SYNCED=true
else
    skip_step "NPM Global" "npm not found"
fi
