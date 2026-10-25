#!/usr/bin/env bash
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
    step "Dev: SDKMAN! candidates & framework"
    log_action "Checking SDKMAN! candidates & framework..."
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would update SDKMAN framework and upgrade candidates..."
    else
        ( set +u; source "$HOME/.sdkman/bin/sdkman-init.sh"
          sdk selfupdate force >/dev/null 2>&1 || true
          sdk update >/dev/null 2>&1 || true
          echo "Y" | sdk upgrade ) >> "$LOG_FILE" 2>&1 \
            || log_warn "SDKMAN! update had issues, continuing..."
    fi
    log_ok "SDKMAN! updated."
else
    skip_step "SDKMAN!" "not installed"
fi
