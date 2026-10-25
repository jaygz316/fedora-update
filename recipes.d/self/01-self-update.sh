#!/usr/bin/env bash
step "Self-Update: Checking fedora-update suite"
local repo_path="${SCRIPT_DIR:-$HOME/projects/update/fedora-update}"
[ ! -d "$repo_path/.git" ] && repo_path="$HOME/projects/update/fedora-update"
if [ ! -d "$repo_path" ]; then
    log_warn "Repo not found at $repo_path; skipping."
    return 0
fi
safe_git_repo_update "$repo_path"
log_ok "fedora-update suite is up to date."
