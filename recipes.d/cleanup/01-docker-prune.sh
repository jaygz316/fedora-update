#!/usr/bin/env bash
if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
    step "Cleanup: Docker images & BuildKit caches"
    docker image prune -f 2>/dev/null || true
    if [ "${DO_TRIM:-false}" = "true" ]; then
        docker builder prune -f --reserved-space 5GB 2>/dev/null || docker builder prune -f --keep-storage 5GB 2>/dev/null || true
        docker image prune -a -f --filter "until=168h" 2>/dev/null || true
    else
        docker builder prune -f --reserved-space 15GB 2>/dev/null || docker builder prune -f --keep-storage 15GB 2>/dev/null || true
    fi
    log_ok "Docker cache optimized."
else
    skip_step "Docker cleanup" "inactive or not installed"
fi
