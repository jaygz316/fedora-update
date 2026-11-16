#!/usr/bin/env bash
if ! command -v claude-desktop &>/dev/null && ! rpm -q claude-desktop &>/dev/null && [ ! -d "$HOME/projects/claude-desktop-fedora" ]; then
    skip_step "Claude Desktop" "not installed"
    return 0
fi

step "AI: Claude Desktop (Official Linux RPM)"

local arch; arch="${ARCH:-$(uname -m)}"
if [ "$arch" != "x86_64" ] && [ "$arch" != "amd64" ]; then
    log_warn "Claude Desktop official Linux build is only available for x86_64 (detected: $arch)."
    return 0
fi

local builder_script=""
for candidate in \
    "$HOME/projects/claude-desktop-fedora/build-official.sh" \
    "/usr/libexec/claude-desktop-builder/build-official.sh"
do
    if [ -x "$candidate" ]; then
        builder_script="$candidate"
        break
    fi
done

if [ -z "$builder_script" ]; then
    log_warn "Claude Desktop builder script (build-official.sh) not found; skipping."
    return 0
fi

log_action "Checking Anthropic's signed apt repository for latest Claude Desktop..."
local latest_info=""
latest_info="$("$builder_script" --print-latest 2>/dev/null || true)"
local latest_raw_ver latest_sha256 latest_deb
read -r latest_raw_ver latest_sha256 latest_deb <<< "$latest_info"
local latest_ver="${latest_raw_ver//-/.}"

if [ -z "$latest_ver" ] || [ -z "$latest_sha256" ]; then
    log_warn "Unable to query latest Claude Desktop release from Anthropic's signed index; continuing..."
    return 0
fi

local current_ver=""
current_ver="$(rpm -q --qf '%{VERSION}' claude-desktop 2>/dev/null || true)"

if [ -n "$current_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
    log_ok "Claude Desktop up to date ($current_ver)."
    return 0
fi

# Not forced: leave a running app alone (checked before downloading/building anything)
if is_claude_desktop_running && [ "${FORCE_UPDATE:-false}" != "true" ]; then
    echo -e "  ${YELLOW}[SKIP] Claude Desktop is running; update (${current_ver:-none} -> $latest_ver) is available (use --force to update).${RESET}"
    return 0
fi

if [ "${DRY_RUN:-false}" = "true" ]; then
    log_info "[DRY-RUN] Would build Claude Desktop ${latest_ver} RPM, then stop/install/restart it (${current_ver:-none} -> $latest_ver)..."
    return 0
fi

# Ensure rpmbuild dependencies are present
for req_cmd in rpmbuild ar file xz gpg; do
    if ! command -v "$req_cmd" &>/dev/null; then
        log_bootstrap "Installing rpm-build & packaging tools for Claude Desktop..."
        with_rpm_lock sudo dnf install -y rpm-build binutils file xz gnupg2 >> "$LOG_FILE" 2>&1 || true
        break
    fi
done

log_info "Updating Claude Desktop (${current_ver:-none} -> $latest_ver)..."
log_action "Downloading & repackaging official .deb into Fedora RPM (Claude Desktop keeps running)..."
local tmp_dir; tmp_dir="$(mktemp -d -p /var/tmp -t "claude-desktop-update-XXXXXX")"
local build_ok=false

if [ -n "$latest_deb" ] && fast_download "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/${latest_deb}" "$tmp_dir/$latest_deb"; then
    if [ "$(sha256sum "$tmp_dir/$latest_deb" 2>/dev/null | cut -d' ' -f1)" = "$latest_sha256" ]; then
        TMPDIR="/var/tmp" "$builder_script" --outdir "$tmp_dir" --deb "$tmp_dir/$latest_deb" >> "$LOG_FILE" 2>&1 && build_ok=true
    fi
    rm -f "$tmp_dir/$latest_deb"
fi

if [ "$build_ok" != "true" ]; then
    TMPDIR="/var/tmp" "$builder_script" --outdir "$tmp_dir" --expect-sha256 "$latest_sha256" >> "$LOG_FILE" 2>&1 && build_ok=true
fi

local rpm_file=""
[ "$build_ok" = "true" ] && rpm_file="$(find "$tmp_dir" -maxdepth 1 -type f -name 'claude-desktop-*.rpm' -print -quit)"

if [ "$build_ok" != "true" ]; then
    log_warn "Failed to build Claude Desktop RPM from upstream .deb; check $LOG_FILE."
elif [ -z "$rpm_file" ] || [ ! -f "$rpm_file" ]; then
    log_warn "Claude Desktop build completed but no RPM file was found."
else
    swap_rpm_app "Claude Desktop" "$rpm_file" get_claude_desktop_pids is_claude_desktop_running \
        "com.anthropic.Claude" "claude-desktop" \
        && log_ok "Claude Desktop updated to $latest_ver."
fi

rm -rf "$tmp_dir"
