#!/usr/bin/env bash
if ! command -v dnf &>/dev/null; then
    skip_step "DNF Autoremove" "dnf not found"
    return 0
fi

step "System: Removing unused DNF dependencies"
if [ "${DRY_RUN:-false}" = "true" ]; then
    run_or_dry sudo dnf autoremove -y
else
    with_rpm_lock sudo dnf autoremove -y 2>&1 | grep -E "(Removing:|Freed space|Nothing to do|Complete)" | sed 's/^/  /' || log_warn "DNF autoremove had issues, continuing..."
fi
