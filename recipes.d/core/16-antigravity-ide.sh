#!/usr/bin/env bash
step "Core: Google Antigravity IDE"
local antigravity_ide_dir="$HOME/.local/opt/antigravity-ide"

_ensure_antigravity_ide_launchers() {
    [ -f "$antigravity_ide_dir/resources/app/resources/linux/code.png" ] && [ ! -f "$antigravity_ide_dir/icon.png" ] && \
        cp "$antigravity_ide_dir/resources/app/resources/linux/code.png" "$antigravity_ide_dir/icon.png" 2>/dev/null || true
    if [ -f "$antigravity_ide_dir/icon.png" ]; then
        mkdir -p "$HOME/.local/share/icons/hicolor/512x512/apps"
        cp "$antigravity_ide_dir/icon.png" "$HOME/.local/share/icons/hicolor/512x512/apps/antigravity-ide.png" 2>/dev/null || true
    fi
    mkdir -p "$HOME/.local/share/applications" "$HOME/Desktop" "$HOME/.local/bin"
    if [ ! -f "$HOME/.local/share/applications/antigravity-ide.desktop" ] || \
       ! grep -q "^StartupWMClass=antigravity-ide" "$HOME/.local/share/applications/antigravity-ide.desktop" 2>/dev/null; then
        cat << DESKTOP > "$HOME/.local/share/applications/antigravity-ide.desktop"
[Desktop Entry]
Name=Antigravity-IDE
Exec=$antigravity_ide_dir/antigravity-ide --no-sandbox
Icon=$antigravity_ide_dir/icon.png
Type=Application
Terminal=false
Categories=Development;IDE;
StartupWMClass=antigravity-ide
DESKTOP
        cp "$HOME/.local/share/applications/antigravity-ide.desktop" "$HOME/Desktop/" 2>/dev/null || true
        chmod +x "$HOME/Desktop/antigravity-ide.desktop" 2>/dev/null || true
    fi
    if [ ! -f "$HOME/.local/bin/antigravity-ide" ] || \
       ! grep -q "exec \"$antigravity_ide_dir/antigravity-ide\"" "$HOME/.local/bin/antigravity-ide" 2>/dev/null; then
        cat << WRAPPER > "$HOME/.local/bin/antigravity-ide"
#!/bin/bash
exec "$antigravity_ide_dir/antigravity-ide" --no-sandbox "\$@"
WRAPPER
        chmod +x "$HOME/.local/bin/antigravity-ide"
    fi
}

local arch; arch="${ARCH:-$(uname -m)}"
local arch_ep=""
case "$arch" in
    x86_64|amd64) arch_ep="linux-x64" ;;
    aarch64|arm64) arch_ep="linux-arm64" ;;
    *) log_warn "Unsupported arch for Antigravity IDE: $arch" ;;
esac

if [ -n "$arch_ep" ]; then
    local response; response="$(curl -s --max-time 5 \
        "https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/api/update/${arch_ep}/stable/latest" \
        2>/dev/null || true)"
    local download_url; download_url="$(echo "$response" | grep -o '"url":"[^"]*"' | cut -d'"' -f4 || true)"
    local current_ide=""; [ -f "$antigravity_ide_dir/.version" ] && current_ide="$(cat "$antigravity_ide_dir/.version" 2>/dev/null || true)"
    local latest_ide=""; [ -n "$download_url" ] && latest_ide="$(echo "$download_url" | sed -E 's|.*/stable/([^/-]+).*|\1|')"
    if [ -n "$current_ide" ] && [ -n "$latest_ide" ] && [ "$current_ide" = "$latest_ide" ]; then
        log_ok "Antigravity IDE up to date ($current_ide)."
        _ensure_antigravity_ide_launchers
    elif [ -n "$download_url" ] && [ -n "$latest_ide" ]; then
        sync_tar_app \
            "Antigravity IDE" \
            "$antigravity_ide_dir" \
            "${download_url// /%20}" \
            "$latest_ide" \
            "${current_ide:-none}" \
            get_antigravity_ide_pids \
            is_antigravity_ide_running \
            "antigravity-ide" \
            "$antigravity_ide_dir/antigravity-ide --no-sandbox" \
            _ensure_antigravity_ide_launchers \
            "user"
    fi
fi
