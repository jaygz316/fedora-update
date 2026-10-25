#!/usr/bin/env bash
step "Core: Python 3 & pip"
if ! python3 -c "import pip" &>/dev/null; then
    log_bootstrap "Installing python3-pip..."
    run_or_dry sudo dnf install -y python3-pip || python3 -m ensurepip --user || true
fi
if python3 -c "import pip" &>/dev/null; then
    run_silent_log python3 -m pip install --user --upgrade pip || true
    log_ok "pip up to date."
else
    log_warn "pip installation could not be completed."
fi
