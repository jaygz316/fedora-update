#!/usr/bin/env bash
if ! command -v ollama &>/dev/null; then
    skip_step "Ollama Engine" "not installed"
    return 0
fi

step "AI: Ollama Engine & Installed Models"
local _ollama_step_t0="$_STEP_START_TIME"
local cv lv
cv="$(ollama --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
log_action "Checking Ollama version (current: ${cv:-unknown})..."
lv="$(curl -s --max-time 4 'https://api.github.com/repos/ollama/ollama/releases/latest' 2>/dev/null | grep -o '"tag_name": *"[^"]*"' | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
if [ -n "$cv" ] && [ -n "$lv" ] && [ "$cv" = "$lv" ]; then
    log_ok "Ollama up to date ($cv)."
elif [ -n "$lv" ]; then
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would upgrade Ollama ($cv -> $lv)"
    else
        log_info "Upgrading Ollama ($cv -> $lv)..."
        local _ol_arch="amd64"
        case "${ARCH:-$(uname -m)}" in aarch64|arm64) _ol_arch="arm64" ;; esac
        local _ol_bin _ol_prefix="/usr/local" _ol_upgraded=false
        _ol_bin="$(command -v ollama 2>/dev/null || true)"
        [ -n "$_ol_bin" ] && _ol_prefix="$(dirname "$(dirname "$_ol_bin")")"
        if [ -f /etc/systemd/system/ollama.service ] && command -v zstd &>/dev/null; then
            local _ol_tmp; _ol_tmp="$(mktemp -d -p /var/tmp -t ollama-upgrade-XXXXXX)"
            local _ol_archive="$_ol_tmp/ollama-linux-${_ol_arch}.tar.zst"
            log_action "Downloading ollama-linux-${_ol_arch}.tar.zst ($lv)..."
            if fast_download "https://ollama.com/download/ollama-linux-${_ol_arch}.tar.zst" "$_ol_archive"; then
                log_action "Extracting Ollama $lv to $_ol_prefix..."
                sudo rm -rf "$_ol_prefix/lib/ollama"
                sudo install -o0 -g0 -m755 -d "$_ol_prefix/bin" "$_ol_prefix/lib/ollama"
                if zstd -T0 -dc "$_ol_archive" | sudo tar -xf - -C "$_ol_prefix"; then
                    sudo systemctl restart ollama 2>/dev/null || true
                    _ol_upgraded=true
                    log_ok "Ollama binary upgraded to $lv."
                fi
            fi
            rm -rf "$_ol_tmp"
        fi
        if [ "$_ol_upgraded" != "true" ]; then
            log_action "Running official Ollama installer..."
            curl -fsSL https://ollama.com/install.sh | sh >> "${RECIPE_LOG_FILE:-$LOG_FILE}" 2>&1 || log_warn "Ollama update failed, continuing..."
        fi
        log_action "Waiting for Ollama daemon to initialize..."
        for _i in {1..10}; do ollama list &>/dev/null && break || sleep 1; done
    fi
fi

local ollama_list
if ollama_list="$(ollama list 2>/dev/null)"; then
    local models; models="$(echo "$ollama_list" | tail -n +2 | awk '{print $1}' | grep -v '^$' || true)"
    if [ -n "$models" ]; then
        local model_arr=()
        while IFS= read -r m; do [ -n "$m" ] && model_arr+=("$m"); done <<< "$models"
        local total="${#model_arr[@]}"
        if [ "$total" -eq 0 ]; then
            _STEP_START_TIME="$_ollama_step_t0"
            log_ok "No local Ollama models installed."
        else
            local midx=0; log_info "Updating $total installed Ollama models concurrently..."
            local tmp_m; tmp_m="$(mktemp -d -t ollama-models-XXXXXX)"
            local mpids=()
            for model in "${model_arr[@]}"; do
                ((midx++))
                (
                    _STEP_START_TIME=$(date +%s)
                    log_substep "$midx" "$total" "Pulling $model..."
                    if [ "${DRY_RUN:-false}" = "true" ]; then
                        log_info "[DRY-RUN] Would pull $model"
                    else
                        ollama pull "$model" >/dev/null 2>&1 \
                            && log_ok "$model up to date." \
                            || log_warn "Failed to pull '$model', continuing..."
                    fi
                ) > "$tmp_m/$midx.log" 2>&1 &
                mpids+=($!)
                # Cap concurrent Ollama pulls at 4 workers
                if [ "${#mpids[@]}" -ge 4 ]; then
                    wait "${mpids[0]}" 2>/dev/null || true
                    mpids=("${mpids[@]:1}")
                fi
            done
            wait "${mpids[@]}" 2>/dev/null || true
            for i in $(seq 1 "$total"); do
                [ -f "$tmp_m/$i.log" ] && cat "$tmp_m/$i.log"
            done
            rm -rf "$tmp_m"
            _STEP_START_TIME="$_ollama_step_t0"
            log_ok "All Ollama models updated."
        fi
    else
        _STEP_START_TIME="$_ollama_step_t0"
        log_ok "No local Ollama models installed."
    fi
else
    log_warn "Ollama not running; skipping model updates."
fi
