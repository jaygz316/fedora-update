#!/usr/bin/env bash
step "Cleanup: PackageKit & development caches"
if [ "${DRY_RUN:-false}" = "true" ]; then
    log_info "[DRY-RUN] Would prune PackageKit, uv, and pip caches."
    log_ok "Caches pruned."
    return 0
fi
[ -d "/var/cache/PackageKit" ] && sudo rm -rf /var/cache/PackageKit/* 2>/dev/null || true
command -v uv &>/dev/null && timeout 5s uv cache prune 2>/dev/null || true
python3 -c "import pip" &>/dev/null && python3 -m pip cache purge >/dev/null 2>&1 || true
log_ok "Caches pruned."
