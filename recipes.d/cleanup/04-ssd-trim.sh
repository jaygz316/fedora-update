#!/usr/bin/env bash
if [ "${DO_TRIM:-false}" = "true" ]; then
    step "Storage: SSD TRIM (fstrim -av)"
    log_info "(Note: TRIM on large Btrfs pools may take several minutes)"
    sudo fstrim -av || log_warn "fstrim had issues, continuing..."
    log_ok "SSD trimmed."
fi
