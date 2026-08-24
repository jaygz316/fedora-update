#!/usr/bin/env bash
# modules/01_system_dnf.sh - DNF Package Manager Upgrade, Autoremove, and Cache Clean
#

set -u

run_system_dnf() {
    if ! command -v dnf &>/dev/null; then
        skip_step "DNF Package Manager" "dnf not found"
        return 0
    fi

    step "System: Refreshing and upgrading DNF packages"
    log_action "Synchronizing repositories and checking package updates..."
    sudo dnf upgrade --refresh -y || log_warn "DNF upgrade encountered issues, continuing..."

    step "System: Removing unused DNF package dependencies (autoremove)"
    log_action "Checking for orphaned packages and unused dependencies..."
    sudo dnf autoremove -y || log_warn "DNF autoremove encountered issues, continuing..."

    step "System: Cleaning DNF package cache"
    log_action "Purging expired metadata and downloaded RPM packages..."
    sudo dnf clean packages -y || true
    log_ok "DNF package management steps completed."
}
