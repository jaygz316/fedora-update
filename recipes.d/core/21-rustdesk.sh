#!/usr/bin/env bash
if ! command -v rustdesk &>/dev/null && ! rpm -q rustdesk &>/dev/null; then
    skip_step "RustDesk" "not installed"
    return 0
fi

step "Core: RustDesk Remote Desktop"
log_action "Checking RustDesk version..."

local current_ver
current_ver="$(rpm -q --qf '%{VERSION}' rustdesk 2>/dev/null || true)"
if [ -z "$current_ver" ] && command -v rustdesk &>/dev/null; then
    current_ver="$(rustdesk --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
fi

local latest_tag=""
if command -v gh &>/dev/null; then
    latest_tag="$(gh release view -R rustdesk/rustdesk --json tagName -q .tagName 2>/dev/null || true)"
fi
if [ -z "$latest_tag" ]; then
    latest_tag="$(curl -s --max-time 5 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)"
fi

local latest_ver="${latest_tag#v}"

if [ -z "$latest_ver" ]; then
    log_warn "Unable to query latest RustDesk release from GitHub; continuing..."
    return 0
fi

if [ -n "$current_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
    log_ok "RustDesk up to date ($current_ver)."
    return 0
fi

# Not forced: leave a running session alone (checked before downloading anything)
if is_rustdesk_session_running && [ "${FORCE_UPDATE:-false}" != "true" ]; then
    echo -e "  ${YELLOW}[SKIP] RustDesk has an active window or session; update ($current_ver -> $latest_ver) is available (use --force to update).${RESET}"
    return 0
fi

if [ "${DRY_RUN:-false}" = "true" ]; then
    log_info "[DRY-RUN] Would download RustDesk ${latest_ver}, then stop/install/restart it (${current_ver:-none} -> $latest_ver)..."
    return 0
fi

local rpm_arch="${ARCH:-$(uname -m)}"
case "$rpm_arch" in
    x86_64|amd64)  rpm_arch="x86_64" ;;
    aarch64|arm64) rpm_arch="aarch64" ;;
    *)
        log_warn "Unsupported architecture for RustDesk RPM: $rpm_arch"
        return 0
        ;;
esac

local rpm_url=""
if command -v gh &>/dev/null; then
    rpm_url="$(gh release view -R rustdesk/rustdesk "$latest_tag" --json assets -q ".assets[] | select(.name | test(\"^rustdesk-.*\\\\.${rpm_arch}\\\\.rpm$\")) | .url" 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$rpm_url" ]; then
    rpm_url="$(curl -s --max-time 5 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' 2>/dev/null | grep -o "https://github.com/rustdesk/rustdesk/releases/download/[^\"]*\\.${rpm_arch}\\.rpm" | head -n 1 || true)"
fi
if [ -z "$rpm_url" ]; then
    rpm_url="https://github.com/rustdesk/rustdesk/releases/download/${latest_tag}/rustdesk-${latest_ver}-0.${rpm_arch}.rpm"
fi

log_info "Updating RustDesk (${current_ver:-none} -> $latest_ver)..."
log_action "Downloading RustDesk RPM (RustDesk keeps running)..."
local tmp_dir; tmp_dir="$(mktemp -d -t "rustdesk-update-XXXXXX")"
local rpm_file="$tmp_dir/rustdesk-${latest_ver}.${rpm_arch}.rpm"

if ! fast_download "$rpm_url" "$rpm_file"; then
    log_warn "Failed to download RustDesk RPM from $rpm_url; continuing..."
    rm -rf "$tmp_dir"
    return 1
fi

swap_rpm_app "RustDesk" "$rpm_file" get_rustdesk_session_pids is_rustdesk_session_running \
    "rustdesk" "rustdesk" \
    && log_ok "RustDesk updated to $latest_ver."
rm -rf "$tmp_dir"
