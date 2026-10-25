#!/usr/bin/env bash
step "System: Checking for required reboots & service restarts"

if command -v dnf &>/dev/null; then
    if with_rpm_lock sudo dnf needs-restarting -q -r >/dev/null 2>&1; then
        log_ok "No reboot required."
    else
        echo -e "\n${BOLD}${RED}╔══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${RED}║  ⚠  REBOOT REQUIRED — kernel or core libs updated        ║${RESET}"
        echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
        echo -e "  Run: ${BOLD}systemctl reboot${RESET}"
    fi
    local restart_services; restart_services="$(with_rpm_lock sudo dnf needs-restarting -q -s 2>/dev/null || true)"
    if [ -n "$restart_services" ]; then
        log_info "Services requiring restart:"
        echo "$restart_services" | sed 's/^/      /'
    else
        log_ok "No services require restart."
    fi
fi

# Desktop Shell Health Check (detect post-update icon/theme/D-Bus churn leaks)
if pgrep -x "plasmashell" &>/dev/null; then
    local plasma_rss
    plasma_rss=$(ps -o rss= -C plasmashell 2>/dev/null | awk '{s+=$1} END {print s}')
    if [ -n "$plasma_rss" ] && [ "$plasma_rss" -gt 1572864 ]; then
        log_warn "Plasmashell RSS elevated after updates ($((plasma_rss / 1024)) MB); reloading desktop shell..."
        systemctl --user restart plasma-plasmashell.service 2>/dev/null || true
        log_ok "Desktop shell refreshed."
    fi
fi
