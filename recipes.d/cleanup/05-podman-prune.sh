#!/usr/bin/env bash
if command -v podman &>/dev/null; then
    step "Cleanup: Podman storage & dangling images"
    podman image prune -f 2>/dev/null || true
    podman container prune -f 2>/dev/null || true
    if [ "${DO_TRIM:-false}" = "true" ]; then
        podman system prune -f 2>/dev/null || true
    fi
    log_ok "Podman storage optimized."
else
    skip_step "Podman cleanup" "not installed"
fi
