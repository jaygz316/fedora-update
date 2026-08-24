#!/usr/bin/env bash
# lib/git_guard.sh - Syncthing-safe Git repository updater and dirty-tree guard
#

set -u

# Safely updates a git repository, checking for local uncommitted changes first
safe_git_repo_update() {
    local repo_path="$1"
    local repo_name
    repo_name="$(basename "$repo_path")"

    if [ ! -d "$repo_path" ]; then
        log_warn "Directory $repo_path does not exist, skipping."
        return 0
    fi

    (
        cd "$repo_path" || return 1
        if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            log_warn "$repo_path is not a valid Git repository."
            return 1
        fi

        log_action "Inspecting $repo_name..."

        # Non-interactive and batch SSH guards to prevent any terminal stalls
        export GIT_TERMINAL_PROMPT=0
        export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15"

        # Check for uncommitted changes or active merges
        local git_status
        git_status="$(git status --porcelain 2>/dev/null || true)"
        if [ -n "$git_status" ]; then
            echo -e "  ${YELLOW}[SKIP] Local modifications detected in $repo_name; skipping pull to avoid Syncthing conflicts.${RESET}"
            return 0
        fi

        # Fetch all remotes with progress and timeout guard
        log_action "Fetching upstream remotes for $repo_name..."
        if ! timeout 45s git fetch --all --prune 2>/dev/null; then
            log_warn "Failed or timed out while fetching upstream for $repo_name (network or remote issue)."
            return 0
        fi

        local local_commit upstream_commit
        local_commit="$(git rev-parse HEAD 2>/dev/null || true)"
        upstream_commit="$(git rev-parse '@{u}' 2>/dev/null || true)"

        if [ -n "$local_commit" ] && [ -n "$upstream_commit" ] && [ "$local_commit" = "$upstream_commit" ]; then
            log_ok "$repo_name is already up to date."
        else
            log_info "Pulling latest changes for $repo_name..."
            if timeout 60s git pull --rebase --autostash; then
                log_ok "$repo_name successfully synchronized."
            else
                log_warn "Failed to complete git pull/rebase for $repo_name."
            fi
        fi
    ) || log_warn "Failed during Git operation on $repo_path"
}
