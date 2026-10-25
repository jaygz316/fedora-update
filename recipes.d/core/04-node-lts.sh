#!/usr/bin/env bash
step "Core: Node.js Runtime"
local node_updated=false
if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
    export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    \. "$NVM_DIR/nvm.sh" 2>/dev/null || true
fi

if type -t nvm &>/dev/null; then
    local current_node remote_lts
    current_node="$(nvm current 2>/dev/null || true)"
    remote_lts="$(nvm version-remote --lts 2>/dev/null || true)"
    if [ -n "$remote_lts" ] && [ "$remote_lts" != "N/A" ]; then
        if [ -n "$current_node" ] && [ "$current_node" = "$remote_lts" ]; then
            log_ok "Node.js (nvm LTS) up to date ($current_node)."
            node_updated=true
        else
            if [ "${DRY_RUN:-false}" = "true" ]; then
                log_info "[DRY-RUN] Would install Node.js LTS ($remote_lts via nvm)..."
                node_updated=true
            else
                log_action "Updating Node.js via nvm (${current_node:-none} -> $remote_lts)..."
                if nvm install --lts --reinstall-packages-from=current 2>/dev/null || nvm install --lts 2>/dev/null; then
                    nvm alias default 'lts/*' 2>/dev/null || true
                    nvm use --silent default 2>/dev/null || true
                    log_ok "Node.js updated to $(node -v 2>/dev/null || echo "$remote_lts")."
                    node_updated=true
                else
                    log_warn "Failed to update Node.js via nvm."
                fi
            fi
        fi
    fi
fi

if [ "$node_updated" = "false" ]; then
    if command -v node &>/dev/null; then
        log_ok "Node.js active ($(node -v))."
    else
        log_bootstrap "Installing Node.js via DNF..."
        if run_or_dry sudo dnf install -y nodejs npm; then
            command -v node &>/dev/null && log_ok "Node.js installed ($(node -v))." || log_warn "Node.js installation could not be verified."
        else
            log_warn "Failed to install Node.js via DNF."
        fi
    fi
fi
