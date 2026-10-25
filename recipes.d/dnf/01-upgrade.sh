#!/usr/bin/env bash
if ! command -v dnf &>/dev/null; then
    skip_step "DNF Upgrade" "dnf not found"
    return 0
fi

# Ensure max_parallel_downloads is active across fleet nodes (default is only 3)
if [ -f /etc/dnf/dnf.conf ] && ! grep -q "^max_parallel_downloads" /etc/dnf/dnf.conf 2>/dev/null; then
    sudo sed -i '/^\[main\]/a max_parallel_downloads=10' /etc/dnf/dnf.conf 2>/dev/null || true
fi

step "System: Refreshing and upgrading DNF packages"
if [ "${DRY_RUN:-false}" = "true" ]; then
    run_or_dry sudo dnf upgrade --refresh -y
else
    log_action "Refreshing metadata & resolving updates in a single pass..."
    with_rpm_lock sudo dnf upgrade --refresh -y 2>&1 | while IFS= read -r line; do
        case "$line" in
            *"Upgrading:"*|*"Installing:"*|*"Removing:"*|*"Replacing:"*|*"Replaced:"*)
                echo -e "  ${CYAN}$line${RESET}" ;;
            *"Total download size"*|*"Downloading Packages"*)
                echo -e "  ${BOLD}$line${RESET}" ;;
            *"Running transaction"*)
                log_action "Applying package updates (this may take several minutes if kernel/drivers update)..." ;;
            *"Preparing"*)
                echo -e "  ${CYAN}... $line${RESET}" ;;
            *"Upgrading "*|*"Installing "*|*"Cleanup "*|*"Reinstalling "*)
                echo -e "  ${CYAN}-->${RESET} $line" ;;
            *"Running scriptlet"*|*"akmods"*|*"dracut"*)
                echo -e "  ${YELLOW}--> [system hook] $line${RESET}" ;;
            *"Nothing to do"*|*"Dependencies resolved"*)
                echo -e "  ${GREEN}$line${RESET}" ;;
            *"Complete!"*)
                echo -e "  ${GREEN}$line${RESET}" ;;
            *) ;;
        esac
    done
    local dnf_rc=${PIPESTATUS[0]}
    [ "$dnf_rc" -ne 0 ] && log_warn "DNF upgrade had issues (exit $dnf_rc), continuing..." || true
fi
