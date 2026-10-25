#!/usr/bin/env bash
if ! command -v fwupdmgr &>/dev/null; then
    skip_step "Firmware (LVFS)" "fwupdmgr not found"
    return 0
fi

step "Firmware: Checking LVFS hardware updates"
log_action "Checking LVFS metadata for device firmware updates..."
timeout 30s fwupdmgr refresh --no-unreported-check >/dev/null 2>&1 || true
if timeout 30s fwupdmgr get-updates --no-unreported-check 2>/dev/null; then
    log_ok "Firmware updates checked."
else
    local s=$?
    [ "$s" -eq 2 ] && log_ok "All firmware up to date." || log_ok "Firmware check complete."
fi
