#!/usr/bin/env bash
step "Core: Google Antigravity Desktop"
local antigravity_dir="$HOME/.local/opt/antigravity"

_ensure_antigravity_desktop_launchers() {
    mkdir -p "$HOME/.local/share/applications" "$HOME/Desktop" "$HOME/.local/bin"
    local asar_file="$antigravity_dir/resources/app.asar"
    if [ -f "$asar_file" ] && [ ! -f "$antigravity_dir/icon.png" ]; then
        python3 "$SCRIPT_DIR/helpers/asar_icon.py" "$asar_file" "$antigravity_dir/icon.png" 2>/dev/null || true
    fi
    if [ -f "$antigravity_dir/icon.png" ]; then
        mkdir -p "$HOME/.local/share/icons/hicolor/512x512/apps"
        cp "$antigravity_dir/icon.png" "$HOME/.local/share/icons/hicolor/512x512/apps/antigravity.png" 2>/dev/null || true
    fi
    if [ ! -f "$HOME/.local/share/applications/antigravity.desktop" ] || \
       ! grep -q "^StartupWMClass=Antigravity" "$HOME/.local/share/applications/antigravity.desktop" 2>/dev/null; then
        cat << DESKTOP > "$HOME/.local/share/applications/antigravity.desktop"
[Desktop Entry]
Name=Antigravity
Exec=$antigravity_dir/antigravity --no-sandbox
Icon=$antigravity_dir/icon.png
Type=Application
Terminal=false
Categories=Development;IDE;
StartupWMClass=Antigravity
DESKTOP
        cp "$HOME/.local/share/applications/antigravity.desktop" "$HOME/Desktop/" 2>/dev/null || true
        chmod +x "$HOME/Desktop/antigravity.desktop" 2>/dev/null || true
    fi
    if [ ! -f "$HOME/.local/bin/antigravity" ] || \
       ! grep -q "exec \"$antigravity_dir/antigravity\"" "$HOME/.local/bin/antigravity" 2>/dev/null; then
        cat << WRAPPER > "$HOME/.local/bin/antigravity"
#!/bin/bash
exec "$antigravity_dir/antigravity" --no-sandbox "\$@"
WRAPPER
        chmod +x "$HOME/.local/bin/antigravity"
    fi
}

local arch; arch="${ARCH:-$(uname -m)}"
local arch_dir=""
case "$arch" in
    x86_64|amd64) arch_dir="linux-x64" ;;
    aarch64|arm64) arch_dir="linux-arm64" ;;
    *) log_warn "Unsupported arch for Antigravity Desktop: $arch" ;;
esac

if [ -n "$arch_dir" ]; then
    local manifest_data; manifest_data="$(curl -s --max-time 5 \
        'https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/latest-x64-linux.yml' \
        2>/dev/null || true)"
    local current_ver=""; [ -f "$antigravity_dir/.version" ] && current_ver="$(cat "$antigravity_dir/.version" 2>/dev/null || true)"
    local latest_ver; latest_ver="$(echo "$manifest_data" | grep -E '^version:' | awk '{print $2}' || true)"
    if [ -n "$current_ver" ] && [ -n "$latest_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
        log_ok "Antigravity Desktop up to date ($current_ver)."
        _ensure_antigravity_desktop_launchers
    elif [ -n "$manifest_data" ] && [ -n "$latest_ver" ]; then
        local base_url; base_url="$(echo "$manifest_data" | grep -o 'https://storage.googleapis.com/antigravity-public/antigravity-hub/[^/]*' | head -n 1)"
        local download_url="${base_url}/${arch_dir}/Antigravity.tar.gz"
        sync_tar_app \
            "Antigravity Desktop" \
            "$antigravity_dir" \
            "$download_url" \
            "$latest_ver" \
            "${current_ver:-none}" \
            get_antigravity_desktop_pids \
            is_antigravity_desktop_running \
            "antigravity" \
            "$antigravity_dir/antigravity --no-sandbox" \
            _ensure_antigravity_desktop_launchers \
            "user"
    fi
fi
