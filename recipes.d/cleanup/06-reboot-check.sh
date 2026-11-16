#!/usr/bin/env bash
step "System: Checking for required reboots & service restarts"

if command -v dnf &>/dev/null; then
    # -r (reboot) and -s (services) are independent; run them concurrently
    local svc_file; svc_file="$(mktemp -t update-svc-XXXXXX)"
    sudo dnf needs-restarting -q -s > "$svc_file" 2>/dev/null &
    local svc_pid=$!
    REBOOT_CHECK_RC=0
    sudo dnf needs-restarting -q -r >/dev/null 2>&1 || REBOOT_CHECK_RC=$?
    if [ "$REBOOT_CHECK_RC" -eq 0 ]; then
        log_ok "No reboot required."
    else
        echo -e "\n${BOLD}${RED}╔══════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}${RED}║  ⚠  REBOOT REQUIRED — kernel or core libs updated        ║${RESET}"
        echo -e "${BOLD}${RED}╚══════════════════════════════════════════════════════════╝${RESET}"
        if [ "${AUTO_RESTART:-false}" = "true" ]; then
            echo -e "  ${BOLD}--restart set: system will reboot after the summary.${RESET}"
        else
            echo -e "  Run: ${BOLD}systemctl reboot${RESET}  (or re-run with ${BOLD}--restart${RESET})"
        fi
    fi
    wait "$svc_pid" 2>/dev/null || true
    local restart_services; restart_services="$(cat "$svc_file" 2>/dev/null || true)"
    rm -f "$svc_file"
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
