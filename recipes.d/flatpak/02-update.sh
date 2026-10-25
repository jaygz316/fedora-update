#!/usr/bin/env bash
if ! command -v flatpak &>/dev/null; then
    skip_step "Flatpak Update" "flatpak not found"
    return 0
fi

_check_and_mask_downgraded_flatpaks() {
    local apps; apps="$(flatpak list --app --columns=application,origin,installation 2>/dev/null || true)"
    [ -z "$apps" ] && return 0
    while read -r app origin inst; do
        [ -z "$app" ] || [ -z "$origin" ] && continue
        local masked
        [ "$inst" = "user" ] && masked="$(flatpak mask --user 2>/dev/null || true)" \
                             || masked="$(flatpak mask 2>/dev/null || true)"
        local ld rd lts rts
        ld="$(flatpak info ${inst:+--$inst} "$app" 2>/dev/null | grep -E '^ +Date:' | awk '{print $2, $3}' || true)"
        rd="$(flatpak remote-info "$origin" "app/$app/$(uname -m)/master" 2>/dev/null | grep -E '^ +Date:' | awk '{print $2, $3}' || true)"
        [ -z "$ld" ] || [ -z "$rd" ] && continue
        lts="$(date -d "$ld" +%s 2>/dev/null || echo 0)"; rts="$(date -d "$rd" +%s 2>/dev/null || echo 0)"
        if echo "$masked" | grep -q "$app"; then
            [ "$rts" -gt "$lts" ] && { log_info "Newer $app upstream; unmasking...";
                [ "$inst" = "user" ] && flatpak mask --user --remove "$app" >/dev/null 2>&1 \
                                     || flatpak mask --remove "$app" >/dev/null 2>&1 || true; }
            continue
        fi
        [ "$lts" -gt "$rts" ] && [ "$rts" -gt 0 ] && { log_info "Remote rollback for $app detected; masking...";
            [ "$inst" = "user" ] && flatpak mask --user "$app" >/dev/null 2>&1 \
                                 || flatpak mask "$app" >/dev/null 2>&1 || true; }
    done <<< "$apps"
}

step "Flatpaks: Updating applications and runtimes"
_check_and_mask_downgraded_flatpaks 2>/dev/null || true
log_action "Checking remotes for application and runtime updates..."
run_or_dry flatpak update -y || { log_warn "Flatpak update had issues; trying --no-static-deltas..."; run_or_dry flatpak update --no-static-deltas -y || true; }

# Quick sweep if an application upgrade left an older runtime orphaned
if [ "${DRY_RUN:-false}" != "true" ]; then
    flatpak uninstall --unused -y >/dev/null 2>&1 || true
fi
log_ok "Flatpaks updated."
