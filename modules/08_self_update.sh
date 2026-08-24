#!/usr/bin/env bash
# modules/08_self_update.sh - Self-update the fedora-update suite from origin/main
#
# Extracted from 06_git_docs.sh so the suite can update itself independently
# via: fedora-update --only=self
#
# Note: Self-update is safe even mid-run because all shell functions are loaded
# into memory at startup. Updated scripts take effect on the next invocation.

set -u

run_self_update() {
    step "Self-Update: Checking fedora-update suite for upstream changes"
    local repo_path="$HOME/projects/update/fedora-update"

    if [ ! -d "$repo_path" ]; then
        log_warn "fedora-update repo not found at $repo_path; skipping self-update."
        return 0
    fi

    safe_git_repo_update "$repo_path"
    log_ok "fedora-update suite is up to date."
}
