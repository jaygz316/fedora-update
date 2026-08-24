#!/usr/bin/env bash
# modules/02_flatpak.sh - Flatpak Applications, Runtimes, and Unused Cleanup
#

set -u

_check_and_mask_downgraded_flatpaks() {
    local installed_apps
    installed_apps="$(flatpak list --app --columns=application,origin,installation 2>/dev/null | tail -n +1 || true)"
    [ -z "$installed_apps" ] && return 0

    while read -r app origin inst; do
        [ -z "$app" ] || [ -z "$origin" ] && continue
        
        # Check if already masked
        local masked
        if [ "$inst" = "user" ]; then
            masked="$(flatpak mask --user 2>/dev/null || true)"
        else
            masked="$(flatpak mask 2>/dev/null || true)"
        fi

        if echo "$masked" | grep -q "$app"; then
            # If masked, check if upstream has released a newer build than our local one
            local local_date remote_date
            local_date="$(flatpak info ${inst:+--$inst} "$app" 2>/dev/null | grep -E '^ +Date:' | awk '{print $2, $3}' || true)"
            remote_date="$(flatpak remote-info "$origin" "app/$app/$(uname -m)/master" 2>/dev/null | grep -E '^ +Date:' | awk '{print $2, $3}' || true)"
            if [ -n "$local_date" ] && [ -n "$remote_date" ]; then
                local local_ts remote_ts
                local_ts="$(date -d "$local_date" +%s 2>/dev/null || echo 0)"
                remote_ts="$(date -d "$remote_date" +%s 2>/dev/null || echo 0)"
                if [ "$remote_ts" -gt "$local_ts" ]; then
                    log_info "New upstream version detected for $app ($remote_date > $local_date); unmasking..."
                    if [ "$inst" = "user" ]; then
                        flatpak mask --user --remove "$app" >/dev/null 2>&1 || true
                    else
                        flatpak mask --remove "$app" >/dev/null 2>&1 || true
                    fi
                fi
            fi
            continue
        fi

        # Check if remote repository serves an older commit than currently installed
        local local_date remote_date
        local_date="$(flatpak info ${inst:+--$inst} "$app" 2>/dev/null | grep -E '^ +Date:' | awk '{print $2, $3}' || true)"
        remote_date="$(flatpak remote-info "$origin" "app/$app/$(uname -m)/master" 2>/dev/null | grep -E '^ +Date:' | awk '{print $2, $3}' || true)"

        if [ -n "$local_date" ] && [ -n "$remote_date" ]; then
            local local_ts remote_ts
            local_ts="$(date -d "$local_date" +%s 2>/dev/null || echo 0)"
            remote_ts="$(date -d "$remote_date" +%s 2>/dev/null || echo 0)"
            if [ "$local_ts" -gt "$remote_ts" ] && [ "$remote_ts" -gt 0 ]; then
                log_info "Remote $origin repo serves older build for $app ($remote_date < $local_date); masking to prevent redundant downloads."
                if [ "$inst" = "user" ]; then
                    flatpak mask --user "$app" >/dev/null 2>&1 || true
                else
                    flatpak mask "$app" >/dev/null 2>&1 || true
                fi
            fi
        fi
    done <<< "$installed_apps"
}

run_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        skip_step "Flatpak Applications & Runtimes" "flatpak CLI not found"
        return 0
    fi

    step "Flatpaks: Updating applications and runtimes"
    log_action "Checking for Flatpak application and runtime updates..."

    # Pre-flight check: mask any upstream rollbacks to prevent downloading and failing
    _check_and_mask_downgraded_flatpaks 2>/dev/null || true

    # Update flatpaks with live progress
    if ! flatpak update -y; then
        log_warn "Standard Flatpak update reported issues; checking static-delta fallback..."
        flatpak update --no-static-deltas -y || true
    fi

    step "Flatpaks: Cleaning unused runtimes"
    log_action "Searching for unused Flatpak runtimes and extensions..."
    flatpak uninstall --unused -y || sudo flatpak uninstall --unused -y || true
    log_ok "Flatpaks checked and updated."
}
