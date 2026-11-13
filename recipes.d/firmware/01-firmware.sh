#!/usr/bin/env bash
# Firmware via LVFS/fwupd. Check-only by default; installs when --firmware or
# --restart is set (FIRMWARE_UPDATE=true). Capsule/BIOS updates are staged and
# applied on next boot — maybe_auto_restart() in `update` reboots for them.
if ! command -v fwupdmgr &>/dev/null; then
    skip_step "Firmware (LVFS)" "fwupdmgr not found"
    return 0
fi

if [ "${FIRMWARE_UPDATE:-false}" != "true" ]; then
    step "Firmware: Checking LVFS hardware updates"
    log_action "Checking LVFS metadata for device firmware updates..."
    timeout 30s fwupdmgr refresh --no-unreported-check >/dev/null 2>&1 || true
    if timeout 30s fwupdmgr get-updates --no-unreported-check 2>/dev/null; then
        log_info "Firmware updates available — run 'update --firmware' (or -r) to install."
    else
        local s=$?
        [ "$s" -eq 2 ] && log_ok "All firmware up to date." || log_ok "Firmware check complete."
    fi
    return 0
fi

step "Firmware: Installing LVFS hardware updates"
if [ "${DRY_RUN:-false}" = "true" ]; then
    run_or_dry sudo fwupdmgr update -y --no-reboot-check --no-unreported-check
    return 0
fi

log_action "Refreshing LVFS metadata..."
timeout 60s sudo fwupdmgr refresh --force --no-unreported-check >/dev/null 2>>"${LOG_FILE:-/dev/null}" || true

log_action "Applying firmware updates (BIOS/UEFI updates are staged for next boot)..."
local fw_rc=0
timeout 15m sudo fwupdmgr update -y --no-reboot-check --no-unreported-check 2>&1 \
    | tee -a "${LOG_FILE:-/dev/null}" \
    | grep -E --line-buffered "Downloading|Writing|Decompressing|Scheduling|Successfully|reboot|No updates|up to date|rror|failed|battery|AC power" \
    | sed -u "s/^/  /" || true
fw_rc=${PIPESTATUS[0]}

case "$fw_rc" in
    0) if firmware_reboot_pending 2>/dev/null; then
           log_warn "Firmware staged — reboot to apply (or use --restart)."
       else
           log_ok "Firmware updated."
       fi ;;
    2) log_ok "All firmware up to date." ;;
    *) log_warn "fwupdmgr update exited $fw_rc (see log), continuing..." ;;
esac
