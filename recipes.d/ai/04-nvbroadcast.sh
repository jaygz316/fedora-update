#!/usr/bin/env bash
if ! command -v nvbroadcast &>/dev/null && ! rpm -q nvbroadcast &>/dev/null; then
    skip_step "NV Broadcast" "not installed"
    return 0
fi

step "AI: NV Broadcast (NVIDIA Broadcast for Linux)"
log_action "Checking NV Broadcast version..."

local current_ver
current_ver="$(rpm -q --qf '%{VERSION}' nvbroadcast 2>/dev/null || true)"

local latest_tag=""
if command -v gh &>/dev/null; then
    latest_tag="$(gh release view -R Hkshoonya/nvidia-broadcast-linux --json tagName -q .tagName 2>/dev/null || true)"
fi
if [ -z "$latest_tag" ]; then
    latest_tag="$(curl -s --max-time 5 'https://api.github.com/repos/Hkshoonya/nvidia-broadcast-linux/releases/latest' 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)"
fi

local latest_ver="${latest_tag#v}"

_clean_nvbroadcast_local_overrides() {
    [ -f "$HOME/.local/bin/nvbroadcast" ] && rm -f "$HOME/.local/bin/nvbroadcast"
    if [ -f "$HOME/.local/share/applications/com.doczeus.NVBroadcast.desktop" ]; then
        rm -f "$HOME/.local/share/applications/com.doczeus.NVBroadcast.desktop"
        command -v update-desktop-database &>/dev/null && update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
}

if [ -z "$latest_ver" ]; then
    log_warn "Unable to query latest NV Broadcast release from GitHub; continuing..."
    _clean_nvbroadcast_local_overrides
    return 0
fi

if [ -n "$current_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
    log_ok "NV Broadcast up to date ($current_ver)."
    _clean_nvbroadcast_local_overrides
    return 0
fi

local was_running=false
if is_nvbroadcast_running; then
    if [ "${FORCE_UPDATE:-false}" != "true" ]; then
        echo -e "  ${YELLOW}[SKIP] NV Broadcast is running; update ($current_ver -> $latest_ver) is available (use --force to update).${RESET}"
        return 0
    elif ! safe_stop_app "NV Broadcast" get_nvbroadcast_pids is_nvbroadcast_running; then
        return 1
    else
        was_running=true
    fi
fi

if [ "${DRY_RUN:-false}" = "true" ]; then
    log_info "[DRY-RUN] Would update NV Broadcast (${current_ver:-none} -> $latest_ver)..."
    [ "$was_running" = "true" ] && restart_app "NV Broadcast" "com.doczeus.NVBroadcast" "nvbroadcast" is_nvbroadcast_running
    return 0
fi

local rpm_url=""
if command -v gh &>/dev/null; then
    rpm_url="$(gh release view -R Hkshoonya/nvidia-broadcast-linux "$latest_tag" --json assets -q '.assets[] | select(.name | test(".*\\.noarch\\.rpm$")) | .url' 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$rpm_url" ]; then
    rpm_url="$(curl -s --max-time 5 'https://api.github.com/repos/Hkshoonya/nvidia-broadcast-linux/releases/latest' 2>/dev/null | grep -o 'https://github.com/Hkshoonya/nvidia-broadcast-linux/releases/download/[^"]*\.noarch\.rpm' | head -n 1 || true)"
fi
if [ -z "$rpm_url" ]; then
    rpm_url="https://github.com/Hkshoonya/nvidia-broadcast-linux/releases/download/${latest_tag}/nvbroadcast-${latest_ver}-1.noarch.rpm"
fi

log_info "Updating NV Broadcast (${current_ver:-none} -> $latest_ver)..."
log_action "Downloading NV Broadcast RPM..."
local tmp_dir; tmp_dir="$(mktemp -d -t "nvbroadcast-update-XXXXXX")"
local rpm_file="$tmp_dir/nvbroadcast-${latest_ver}.rpm"

if ! curl -# -fSL -o "$rpm_file" "$rpm_url" 2>/dev/null; then
    log_warn "Failed to download NV Broadcast RPM from $rpm_url; continuing..."
    rm -rf "$tmp_dir"
    [ "$was_running" = "true" ] && restart_app "NV Broadcast" "com.doczeus.NVBroadcast" "nvbroadcast" is_nvbroadcast_running
    return 1
fi

log_action "Installing verified NV Broadcast RPM package..."
if with_rpm_lock sudo dnf install --assumeyes "$rpm_file" >> "$LOG_FILE" 2>&1; then
    log_ok "NV Broadcast updated to $latest_ver."
else
    log_warn "DNF install encountered issues; attempting fallback rpm upgrade..."
    with_rpm_lock sudo rpm -Uvh --replacepkgs "$rpm_file" >> "$LOG_FILE" 2>&1 || log_warn "RPM upgrade had issues, continuing..."
fi
rm -rf "$tmp_dir"

_clean_nvbroadcast_local_overrides

if [ "$was_running" = "true" ]; then
    restart_app "NV Broadcast" "com.doczeus.NVBroadcast" "nvbroadcast" is_nvbroadcast_running
fi
