#!/usr/bin/env bash
step "Core: Android Studio Latest Preview (Canary)"
local studio_preview_dir="/opt/android-studio-preview"

# Clean up empty legacy directory if present
if [ -d "$HOME/.local/opt/android-studio-preview" ] && [ -z "$(ls -A "$HOME/.local/opt/android-studio-preview" 2>/dev/null)" ]; then
    rmdir "$HOME/.local/opt/android-studio-preview" 2>/dev/null || true
fi

local arch; arch="${ARCH:-$(uname -m)}"
if [ "$arch" != "x86_64" ] && [ "$arch" != "amd64" ]; then
    log_warn "Android Studio Preview Linux builds are only available for x86_64 (detected: $arch)."
    return 0
fi

_ensure_studio_preview_launchers() {
    mkdir -p "$HOME/.local/share/applications" "$HOME/.local/bin"
    local icon_path="$studio_preview_dir/bin/studio.svg"
    [ ! -f "$icon_path" ] && [ -f "$studio_preview_dir/bin/studio.png" ] && icon_path="$studio_preview_dir/bin/studio.png"
    if [ ! -f "$HOME/.local/share/applications/android-studio-preview.desktop" ] || \
       ! grep -q "^Exec=$studio_preview_dir/bin/studio.sh" "$HOME/.local/share/applications/android-studio-preview.desktop" 2>/dev/null; then
        cat << DESKTOP > "$HOME/.local/share/applications/android-studio-preview.desktop"
[Desktop Entry]
Name=Android Studio Preview
Exec=$studio_preview_dir/bin/studio.sh
Icon=$icon_path
Type=Application
Terminal=false
Categories=Development;IDE;
DESKTOP
        [ -d "$HOME/Desktop" ] && cp "$HOME/.local/share/applications/android-studio-preview.desktop" "$HOME/Desktop/" 2>/dev/null || true
        [ -f "$HOME/Desktop/android-studio-preview.desktop" ] && chmod +x "$HOME/Desktop/android-studio-preview.desktop" 2>/dev/null || true
    fi
    if [ ! -f "$HOME/.local/bin/android-studio-preview" ] || \
       ! grep -q "exec \"$studio_preview_dir/bin/studio.sh\"" "$HOME/.local/bin/android-studio-preview" 2>/dev/null; then
        cat << WRAPPER > "$HOME/.local/bin/android-studio-preview"
#!/usr/bin/env bash
exec "$studio_preview_dir/bin/studio.sh" "\$@"
WRAPPER
        chmod +x "$HOME/.local/bin/android-studio-preview"
    fi
}

local canary_meta; canary_meta="$(python3 "$SCRIPT_DIR/helpers/android_canary.py" 2>/dev/null || true)"
local latest_ver; latest_ver="$(sed -n '1p' <<< "$canary_meta")"
local latest_build; latest_build="$(sed -n '2p' <<< "$canary_meta")"
local download_url; download_url="$(sed -n '3p' <<< "$canary_meta")"

local current_build=""
[ -f "$studio_preview_dir/build.txt" ] && current_build="$(tr -d ' \r\n' < "$studio_preview_dir/build.txt" 2>/dev/null || true)"
local current_ver=""
[ -f "$studio_preview_dir/.version" ] && current_ver="$(cat "$studio_preview_dir/.version" 2>/dev/null || true)"

if [ -n "$latest_build" ] && [ "$latest_build" != "none" ] && [ -n "$current_build" ] && [ "$current_build" = "$latest_build" ]; then
    log_ok "Android Studio Preview up to date (${latest_ver:-$current_build})."
    _ensure_studio_preview_launchers
elif [ -n "$latest_ver" ] && [ -n "$current_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
    log_ok "Android Studio Preview up to date ($latest_ver)."
    _ensure_studio_preview_launchers
elif [ -n "$download_url" ] && [ -n "$latest_ver" ]; then
    sync_tar_app \
        "Android Studio" \
        "$studio_preview_dir" \
        "$download_url" \
        "$latest_ver" \
        "${current_ver:-${current_build:-none}}" \
        get_android_studio_pids \
        is_android_studio_running \
        "android-studio-preview" \
        "$studio_preview_dir/bin/studio.sh" \
        _ensure_studio_preview_launchers \
        "sudo"
else
    if [ -d "$studio_preview_dir" ]; then
        log_ok "Android Studio Preview verified (${current_ver:-${current_build:-installed}})."
        _ensure_studio_preview_launchers
    else
        log_warn "Android Studio Canary metadata unavailable; skipping install."
    fi
fi
