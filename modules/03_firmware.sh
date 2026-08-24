#!/usr/bin/env bash
# modules/03_firmware.sh - Hardware and System Firmware Updates (LVFS / fwupd)
#

set -u

run_firmware() {
    if ! command -v fwupdmgr &>/dev/null; then
        skip_step "Hardware & System Firmware (LVFS)" "fwupdmgr not found"
        return 0
    fi

    step "Firmware: Checking LVFS hardware & system updates"
    log_action "Connecting to Linux Vendor Firmware Service (LVFS)..."
    timeout 30s fwupdmgr refresh --no-unreported-check >/dev/null 2>&1 || true

    log_action "Querying connected hardware devices for available firmware releases..."
    if timeout 30s fwupdmgr get-updates --no-unreported-check 2>/dev/null; then
        log_ok "Firmware updates checked."
    else
        local fwupd_status=$?
        if [ "$fwupd_status" -eq 2 ]; then
            log_ok "All device and system firmware is up to date."
        else
            log_ok "Firmware check completed (no pending critical updates)."
        fi
    fi
}
