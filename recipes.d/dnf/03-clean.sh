#!/usr/bin/env bash
if ! command -v dnf &>/dev/null; then
    skip_step "DNF Cache Clean" "dnf not found"
    return 0
fi

step "System: Cleaning DNF package cache"
if [ "${DRY_RUN:-false}" = "true" ]; then
    run_or_dry sudo dnf clean packages -y || true
else
    with_rpm_lock sudo dnf clean packages -y || true
fi
log_ok "DNF complete."
