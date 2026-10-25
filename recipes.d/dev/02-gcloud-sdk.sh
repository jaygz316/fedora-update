#!/usr/bin/env bash
if [ -d "$HOME/google-cloud-sdk" ] && command -v gcloud &>/dev/null; then
    step "Dev: Google Cloud SDK components"
    log_action "Checking Google Cloud SDK components..."
    gcloud components update --quiet || log_warn "gcloud update had issues, continuing..."
    log_ok "Google Cloud SDK updated."
else
    skip_step "Google Cloud SDK" "not installed"
fi
