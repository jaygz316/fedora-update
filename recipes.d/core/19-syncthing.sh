#!/usr/bin/env bash
step "Core: Syncthing Sync Engine"
if ! command -v syncthing &>/dev/null; then
    log_bootstrap "Installing Syncthing..."
    run_or_dry sudo dnf install -y syncthing || true
fi
if command -v syncthing &>/dev/null; then
    local st_configs=( "$HOME/.local/state/syncthing/config.xml" "$HOME/.config/syncthing/config.xml" )
    local st_cfg=""
    for c in "${st_configs[@]}"; do [ -f "$c" ] && { st_cfg="$c"; break; }; done
    if [ -z "$st_cfg" ]; then
        log_bootstrap "Generating initial Syncthing config..."
        syncthing generate 2>/dev/null || syncthing --generate 2>/dev/null || true
        for c in "${st_configs[@]}"; do [ -f "$c" ] && { st_cfg="$c"; break; }; done
    fi
    [ -n "$st_cfg" ] && grep -q "<address>127.0.0.1:8384</address>" "$st_cfg" && \
        sed -i 's|<address>127.0.0.1:8384</address>|<address>0.0.0.0:8384</address>|g' "$st_cfg" && \
        log_info "Syncthing GUI configured → 0.0.0.0:8384"
    if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        sudo firewall-cmd --add-service=syncthing --permanent >/dev/null 2>&1 || true
        sudo firewall-cmd --add-port=8384/tcp --permanent >/dev/null 2>&1 || true
        sudo firewall-cmd --reload >/dev/null 2>&1 || true
    fi
    systemctl --user is-active --quiet syncthing.service 2>/dev/null || \
        systemctl --user enable --now syncthing.service 2>/dev/null || true
    log_ok "Syncthing running, GUI on 0.0.0.0:8384."
else
    log_warn "Syncthing could not be verified."
fi
