#!/usr/bin/env bash
if ! command -v lms &>/dev/null; then
    skip_step "LM Studio" "not installed"
    return 0
fi

step "AI: LM Studio Runtime Extensions"
log_action "Checking LM Studio runtimes..."
lms runtime update -y --all || log_warn "LM Studio update had issues, continuing..."
