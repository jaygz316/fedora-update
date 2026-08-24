#!/usr/bin/env bash
# modules/06_git_docs.sh - Documentation repositories and local agent framework Git sync
#

set -u

run_git_docs() {
    step "Git Docs: Synchronizing local Git documentation and agent frameworks"

    local all_repos=()
    [ -d "$HOME/projects/update/fedora-update" ] && all_repos+=("$HOME/projects/update/fedora-update")
    [ -d "$HOME/.hermes/hermes-agent" ] && all_repos+=("$HOME/.hermes/hermes-agent")
    all_repos+=(
        "$HOME/projects/docs/androidx"
        "$HOME/projects/docs/compose-samples"
        "$HOME/projects/docs/horologist"
        "$HOME/projects/docs/nowinandroid"
    )

    local total_repos="${#all_repos[@]}"
    local idx=0

    for repo in "${all_repos[@]}"; do
        ((idx++))
        local rname
        rname="$(basename "$repo")"
        if [ "$rname" = "androidx" ]; then
            log_substep "$idx" "$total_repos" "Checking AndroidX documentation ($rname - ~55k files)..."
        else
            log_substep "$idx" "$total_repos" "Checking $rname repository..."
        fi

        if [ -d "$repo" ]; then
            safe_git_repo_update "$repo"
        else
            skip_step "$rname" "directory not found"
        fi

        # If Hermes venv is present, sync editable package
        if [ "$rname" = "hermes-agent" ] && [ -d "$HOME/.hermes/hermes-agent/venv" ]; then
            log_action "Updating Hermes editable python environment..."
            timeout 60s "$HOME/.hermes/hermes-agent/venv/bin/pip" install --upgrade -e "$HOME/.hermes/hermes-agent" 2>/dev/null || true
        fi
    done

    log_ok "All Git repositories checked and synchronized."
}
