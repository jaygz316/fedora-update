#!/usr/bin/env bash
step "Git Docs: Synchronizing documentation repos and agent frameworks"
local all_repos=()
[ -d "$HOME/.hermes/hermes-agent" ] && all_repos+=("$HOME/.hermes/hermes-agent")
[ -d "$HOME/projects/claude-desktop-fedora" ] && all_repos+=("$HOME/projects/claude-desktop-fedora")
all_repos+=( "$HOME/projects/docs/androidx" "$HOME/projects/docs/compose-samples"
             "$HOME/projects/docs/horologist" "$HOME/projects/docs/nowinandroid"
             "$HOME/projects/docs/unraid" "$HOME/projects/audiobookshelf-api-docs" )
local total="${#all_repos[@]}" idx=0
local tmp_dir; tmp_dir="$(mktemp -d -t git-docs-sync-XXXXXX)"
local pids=()
log_action "Synchronizing $total repositories in parallel..."

for repo in "${all_repos[@]}"; do
    ((idx++))
    local rname; rname="$(basename "$repo")"
    if [ -d "$repo" ]; then
        (
            _STEP_START_TIME=$(date +%s)
            [ "$rname" = "androidx" ] \
                && log_substep "$idx" "$total" "Checking AndroidX (~55k files)..." \
                || log_substep "$idx" "$total" "Checking $rname..."
            local _prev_head="" _new_head=""
            [ "$rname" = "hermes-agent" ] && _prev_head="$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)"
            safe_git_repo_update "$repo"
            [ "$rname" = "hermes-agent" ] && _new_head="$(git -C "$repo" rev-parse HEAD 2>/dev/null || true)"
            if [ "$rname" = "hermes-agent" ] && [ "${DRY_RUN:-false}" != "true" ] && [ -n "$_new_head" ] && [ "$_prev_head" != "$_new_head" ] && [ -d "$HOME/.hermes/hermes-agent/venv" ]; then
                log_action "Updating Hermes editable Python env..."
                if command -v uv &>/dev/null && [ -x "$HOME/.hermes/hermes-agent/venv/bin/python" ]; then
                    timeout 60s uv pip install --python "$HOME/.hermes/hermes-agent/venv/bin/python" --upgrade -e "$HOME/.hermes/hermes-agent" >/dev/null 2>&1 || true
                elif [ -x "$HOME/.hermes/hermes-agent/venv/bin/pip" ]; then
                    timeout 60s "$HOME/.hermes/hermes-agent/venv/bin/pip" install --upgrade -e "$HOME/.hermes/hermes-agent" >/dev/null 2>&1 || true
                fi
            fi
        ) > "$tmp_dir/$idx.log" 2>&1 &
        pids+=($!)
    else
        ( skip_step "$rname" "not found" ) > "$tmp_dir/$idx.log" 2>&1 &
        pids+=($!)
    fi
done

wait "${pids[@]}" 2>/dev/null || true

for i in $(seq 1 "$total"); do
    [ -f "$tmp_dir/$i.log" ] && cat "$tmp_dir/$i.log"
done
rm -rf "$tmp_dir"
log_ok "All Git repos checked."
