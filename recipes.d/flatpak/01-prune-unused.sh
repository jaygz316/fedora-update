#!/usr/bin/env bash
if ! command -v flatpak &>/dev/null; then
    skip_step "Flatpak Prune" "flatpak not found"
    return 0
fi

_reconcile_split_flatpak_runtimes() {
    local user_apps; user_apps="$(flatpak list --user --app --columns=application,runtime,origin 2>/dev/null | cat || true)"
    [ -z "$user_apps" ] && return 0
    while IFS=$'\t' read -r app runtime origin; do
        [ -z "$app" ] || [ -z "$runtime" ] && continue
        if ! flatpak info --user "runtime/$runtime" &>/dev/null && flatpak info --system "runtime/$runtime" &>/dev/null; then
            local rt_origin
            rt_origin="$(flatpak info --system --show-origin "runtime/$runtime" 2>/dev/null | tr -d '[:space:]' || true)"
            [ -z "$rt_origin" ] && rt_origin="${origin:-flathub}"
            log_info "User app $app uses system-only runtime $runtime; migrating runtime to user installation..."
            run_or_dry flatpak install --user -y "$rt_origin" "runtime/$runtime" || true
        fi
    done <<< "$user_apps"
}

step "Flatpaks: Pruning unused runtimes (pre-update cleanup)"
log_action "Checking for obsolete or unused Flatpak runtimes..."
_reconcile_split_flatpak_runtimes
if [ "${DRY_RUN:-false}" = "true" ]; then
    run_or_dry flatpak uninstall --unused -y
else
    pruned_out="$(flatpak uninstall --unused -y 2>&1 || true)"
    if echo "$pruned_out" | grep -q "Uninstall complete"; then
        count="$(echo "$pruned_out" | grep -cE "Uninstalling|Pruning" || true)"
        log_ok "Pruned $count unused runtime(s) before download."
    else
        log_ok "No unused Flatpak runtimes found."
    fi
fi
