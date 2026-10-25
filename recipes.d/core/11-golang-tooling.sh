#!/usr/bin/env bash
step "Core: Go Compiler & Developer Tooling"
if ! command -v go &>/dev/null; then
    log_bootstrap "Installing Go via DNF..."
    run_or_dry sudo dnf install -y golang || true
fi
if command -v go &>/dev/null; then
    local _go_step_t0="$_STEP_START_TIME"
    local _go_tmp; _go_tmp="$(mktemp -d -t go-tools-XXXXXX)"
    local _go_pids=()
    ( _STEP_START_TIME=$(date +%s); _update_or_install_go_tool "gopls"  "golang.org/x/tools/gopls" || true ) > "$_go_tmp/1.log" 2>&1 & _go_pids+=($!)
    ( _STEP_START_TIME=$(date +%s); _update_or_install_go_tool "dlv"    "github.com/go-delve/delve/cmd/dlv" || true ) > "$_go_tmp/2.log" 2>&1 & _go_pids+=($!)
    ( _STEP_START_TIME=$(date +%s); _update_or_install_go_tool "goplay" "github.com/haya14busa/goplay/cmd/goplay" || true ) > "$_go_tmp/3.log" 2>&1 & _go_pids+=($!)
    wait "${_go_pids[@]}" 2>/dev/null || true
    for _gi in 1 2 3; do [ -f "$_go_tmp/$_gi.log" ] && cat "$_go_tmp/$_gi.log"; done
    rm -rf "$_go_tmp"
    _STEP_START_TIME="$_go_step_t0"
    log_ok "Go tooling verified."
else
    log_warn "Go compiler could not be verified."
fi
