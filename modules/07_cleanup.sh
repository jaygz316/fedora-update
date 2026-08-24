#!/usr/bin/env bash
# modules/07_cleanup.sh - Docker cleanup, cache optimization, journal vacuum, optional SSD TRIM, and reboot check
#

set -u

run_cleanup() {
    local do_trim="${1:-false}"

    # 1. Docker Cleanup (Images & BuildKit Builder Cache)
    if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
        step "Cleanup: Docker images & BuildKit caches"
        log_action "Pruning dangling container images and excess builder cache..."
        docker image prune -f 2>/dev/null || true
        
        if [ "$do_trim" = "true" ]; then
            log_action "Deep cleaning unused Docker images and build caches (keeping 5GB)..."
            docker builder prune -f --reserved-space 5GB 2>/dev/null || docker builder prune -f --keep-storage 5GB 2>/dev/null || true
            docker image prune -a -f --filter "until=168h" 2>/dev/null || true
        else
            docker builder prune -f --reserved-space 15GB 2>/dev/null || docker builder prune -f --keep-storage 15GB 2>/dev/null || true
        fi
        log_ok "Docker images and builder cache optimized."
    else
        skip_step "Docker cleanup" "docker service inactive or not installed"
    fi

    # 2. PackageKit & Development Cache Vacuum
    step "Cleanup: PackageKit & Development Caches"
    log_action "Optimizing PackageKit metadata and developer caches..."
    if [ -d "/var/cache/PackageKit" ]; then
        sudo rm -rf /var/cache/PackageKit/* 2>/dev/null || true
    fi
    if command -v uv &>/dev/null; then
        uv cache prune 2>/dev/null || true
    fi
    if python3 -c "import pip" &>/dev/null; then
        python3 -m pip cache purge >/dev/null 2>&1 || true
    fi
    log_ok "PackageKit and developer build caches optimized."

    # 3. System Journal Vacuum
    step "Cleanup: Optimizing system logs (journalctl vacuum)"
    log_action "Vacuuming systemd journal logs (keeping 14 days / max 500MB)..."
    sudo journalctl --vacuum-time=14d --vacuum-size=500M 2>&1 | sed 's/^/  /' || log_warn "Journal vacuuming encountered issues, continuing..."
    log_ok "System logs vacuumed."

    # 4. SSD TRIM (fstrim) if requested
    if [ "$do_trim" = "true" ]; then
        step "Storage: Performing SSD TRIM (fstrim -av)"
        log_action "Issuing TRIM discards across mounted SSD filesystems..."
        log_info "(Note: SSD TRIM on large Btrfs storage pools may take several minutes to complete)"
        sudo fstrim -av || log_warn "fstrim encountered issues, continuing..."
        log_ok "SSD storage trimmed."
    fi

    # 5. Post-Update Reboot & Service Checks
    echo -e "\n${BOLD}${CYAN}============================================================${RESET}"
    echo -e "${BOLD}${CYAN}          Checking for Required Service Restarts            ${RESET}"
    echo -e "${BOLD}${CYAN}============================================================${RESET}"

    if command -v dnf &>/dev/null; then
        log_action "Evaluating system state for pending kernel or library reboots..."
        if sudo dnf needs-restarting -r >/dev/null 2>&1; then
            log_ok "No system reboot required."
        else
            echo -e "  ${YELLOW}[!] A system reboot is RECOMMENDED (kernel or core system libraries updated).${RESET}"
        fi

        log_info "Active services requiring restart:"
        sudo dnf needs-restarting -s 2>/dev/null | sed 's/^/      /' || true
    fi
}
