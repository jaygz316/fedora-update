#!/usr/bin/env bash
step "Cleanup: System journal vacuum (14d / 500MB)"
sudo journalctl --vacuum-time=14d --vacuum-size=500M 2>&1 | sed 's/^/  /' \
    || log_warn "Journal vacuum had issues, continuing..."
log_ok "System logs vacuumed."
