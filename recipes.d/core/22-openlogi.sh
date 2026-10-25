#!/usr/bin/env bash
if ! command -v openlogi &>/dev/null && ! rpm -q openlogi &>/dev/null; then
    skip_step "OpenLogi" "not installed"
    return 0
fi

step "Core: OpenLogi (Logitech HID++ Control)"
log_action "Checking OpenLogi version..."

local current_ver
current_ver="$(rpm -q --qf '%{VERSION}' openlogi 2>/dev/null || true)"
if [ -z "$current_ver" ] && command -v openlogi &>/dev/null; then
    current_ver="$(openlogi --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
fi

local latest_tag=""
if command -v gh &>/dev/null; then
    latest_tag="$(gh release view -R AprilNEA/OpenLogi --json tagName -q .tagName 2>/dev/null || true)"
fi
if [ -z "$latest_tag" ]; then
    latest_tag="$(curl -s --max-time 5 'https://api.github.com/repos/AprilNEA/OpenLogi/releases/latest' 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)"
fi

local latest_ver="${latest_tag#v}"

if [ -z "$latest_ver" ]; then
    log_warn "Unable to query latest OpenLogi release from GitHub; continuing..."
    return 0
fi

if [ -n "$current_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
    log_ok "OpenLogi up to date ($current_ver)."
    return 0
fi

local was_running=false
if is_openlogi_running; then
    if [ "${FORCE_UPDATE:-false}" != "true" ]; then
        echo -e "  ${YELLOW}[SKIP] OpenLogi desktop window is open; update ($current_ver -> $latest_ver) is available (use --force to update).${RESET}"
        return 0
    elif ! safe_stop_app "OpenLogi" get_openlogi_pids is_openlogi_running; then
        return 1
    else
        was_running=true
    fi
fi

if [ "${DRY_RUN:-false}" = "true" ]; then
    log_info "[DRY-RUN] Would update OpenLogi (${current_ver:-none} -> $latest_ver)..."
    [ "$was_running" = "true" ] && restart_app "OpenLogi" "openlogi" "openlogi-desktop" is_openlogi_running
    return 0
fi

local pkg_arch="${ARCH:-$(uname -m)}"
case "$pkg_arch" in
    x86_64|amd64)  pkg_arch="amd64" ;;
    aarch64|arm64) pkg_arch="arm64" ;;
    *)
        log_warn "Unsupported architecture for OpenLogi RPM: $pkg_arch"
        return 0
        ;;
esac

local rpm_url=""
if command -v gh &>/dev/null; then
    rpm_url="$(gh release view -R AprilNEA/OpenLogi "$latest_tag" --json assets -q ".assets[] | select(.name | test(\"^openlogi-.*-linux-${pkg_arch}\\\\.rpm$\")) | .url" 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$rpm_url" ]; then
    rpm_url="$(curl -s --max-time 5 'https://api.github.com/repos/AprilNEA/OpenLogi/releases/latest' 2>/dev/null | grep -o "https://github.com/AprilNEA/OpenLogi/releases/download/[^\"]*-linux-${pkg_arch}\\.rpm" | head -n 1 || true)"
fi
if [ -z "$rpm_url" ]; then
    rpm_url="https://github.com/AprilNEA/OpenLogi/releases/download/${latest_tag}/openlogi-${latest_tag}-linux-${pkg_arch}.rpm"
fi

log_info "Updating OpenLogi (${current_ver:-none} -> $latest_ver)..."
log_action "Downloading OpenLogi RPM..."
local tmp_dir; tmp_dir="$(mktemp -d -t "openlogi-update-XXXXXX")"
local rpm_file="$tmp_dir/openlogi-${latest_ver}-linux-${pkg_arch}.rpm"

if ! curl -# -fSL -o "$rpm_file" "$rpm_url" 2>/dev/null; then
    log_warn "Failed to download OpenLogi RPM from $rpm_url; continuing..."
    rm -rf "$tmp_dir"
    [ "$was_running" = "true" ] && restart_app "OpenLogi" "openlogi" "openlogi-desktop" is_openlogi_running
    return 1
fi

log_action "Installing verified OpenLogi RPM package..."
if with_rpm_lock sudo dnf install --assumeyes "$rpm_file" >> "$LOG_FILE" 2>&1; then
    log_ok "OpenLogi updated to $latest_ver."
else
    log_warn "DNF install encountered issues; attempting fallback rpm upgrade..."
    with_rpm_lock sudo rpm -Uvh --replacepkgs "$rpm_file" >> "$LOG_FILE" 2>&1 \
        && log_ok "OpenLogi updated to $latest_ver." \
        || log_warn "RPM upgrade had issues, continuing..."
fi
rm -rf "$tmp_dir"

if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
    if systemctl --user is-active --quiet openlogi-agent.service 2>/dev/null; then
        log_action "Restarting openlogi-agent user service..."
        systemctl --user restart openlogi-agent.service 2>/dev/null || true
    fi
fi

if [ "$was_running" = "true" ]; then
    restart_app "OpenLogi" "openlogi" "openlogi-desktop" is_openlogi_running
fi
