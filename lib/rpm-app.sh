#!/usr/bin/env bash
# lib/rpm-app.sh — minimal-downtime install of an already-downloaded RPM for a GUI/tray app.
# Sourced by `update`; relies on its helpers (rpm_lock_*, safe_stop_app, restart_app, log_*).
#
# swap_rpm_app NAME RPM_FILE PIDS_FN CHECK_FN DESKTOP_ID FALLBACK_CMD [POST_INSTALL_FN]
#
# The caller downloads/builds the RPM first, while the app keeps running. This then waits
# for the RPM database (a concurrent dnf upgrade may hold it) with the app STILL running,
# and only then stops it, installs, releases the lock and relaunches it. Downtime is the
# install itself (seconds), not download + dnf queue time.
# Returns 0 if the package was installed.
swap_rpm_app() {
    local app_name="$1" rpm_file="$2" pids_fn="$3" check_fn="$4"
    local desktop_id="$5" fallback_cmd="$6" post_install_fn="${7:-}"

    "$check_fn" && log_action "Waiting for the RPM database before closing $app_name (it keeps running meanwhile)..."
    if ! rpm_lock_acquire; then
        log_warn "Timed out waiting for the RPM database; skipping $app_name install."
        return 1
    fi

    local was_running=false
    if "$check_fn"; then
        if [ "${FORCE_UPDATE:-false}" != "true" ]; then
            echo -e "  ${YELLOW}[SKIP] $app_name was launched during download; leaving it running.${RESET}"
            rpm_lock_release
            return 1
        fi
        if ! safe_stop_app "$app_name" "$pids_fn" "$check_fn"; then
            rpm_lock_release
            return 1
        fi
        was_running=true
    fi

    log_action "Installing $app_name RPM package..."
    local rc=0
    # rpm -U skips dnf's repo metadata load (shorter downtime); dnf resolves deps if it fails
    if ! sudo rpm -Uvh --replacepkgs "$rpm_file" >> "$LOG_FILE" 2>&1; then
        log_action "rpm -U could not apply it directly; retrying via dnf to resolve dependencies..."
        sudo dnf install --assumeyes "$rpm_file" >> "$LOG_FILE" 2>&1 || rc=1
    fi
    [ "$rc" -ne 0 ] && log_warn "$app_name RPM install had issues; see $LOG_FILE."
    [ -n "$post_install_fn" ] && "$post_install_fn"
    rpm_lock_release

    [ "$was_running" = "true" ] && restart_app "$app_name" "$desktop_id" "$fallback_cmd" "$check_fn"
    return "$rc"
}
