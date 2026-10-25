#!/usr/bin/env bash
step "Core: GitHub CLI (gh)"
if ! command -v gh &>/dev/null; then
    log_bootstrap "Installing GitHub CLI..."
    run_or_dry sudo dnf install -y gh || true
fi
if command -v gh &>/dev/null; then
    gh auth status &>/dev/null && gh extension upgrade --all 2>/dev/null || true
    log_ok "GitHub CLI ready."
else
    log_warn "GitHub CLI installation could not be completed."
fi
