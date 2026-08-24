#!/usr/bin/env bash
# modules/04_ai_runtimes.sh - Secondary AI engines, Claude Code, LM Studio, Ollama & models
#

set -u

run_ai_runtimes() {
    # 1. Claude Code CLI
    if command -v claude &>/dev/null; then
        step "AI: Claude Code CLI"
        log_action "Checking Claude Code updates..."
        if is_cli_running "claude"; then
            echo -e "  ${YELLOW}[SKIP] Claude Code is currently active; skipping update to avoid interrupting session.${RESET}"
        else
            claude update || log_warn "Claude Code CLI update encountered issues, continuing..."
        fi
    else
        skip_step "Claude Code CLI" "not installed"
    fi

    # 2. LM Studio Runtime & Engines
    if command -v lms &>/dev/null; then
        step "AI: LM Studio Runtime Extensions"
        log_action "Checking LM Studio runtime extensions..."
        lms runtime update -y --all || log_warn "LM Studio runtime update encountered issues, continuing..."
    else
        skip_step "LM Studio ('lms')" "not installed"
    fi

    # 3. Ollama & Installed Models
    if command -v ollama &>/dev/null; then
        step "AI: Ollama Engine & Installed Models"
        log_action "Checking Ollama engine version..."
        local current_ollama latest_ollama
        current_ollama="$(ollama --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
        latest_ollama="$(curl -s --max-time 3 "https://api.github.com/repos/ollama/ollama/releases/latest" 2>/dev/null | grep -m1 '"tag_name":' | sed -E 's/.*"v?([0-9.]+).*/\1/' || true)"

        if [ -n "$current_ollama" ] && [ -n "$latest_ollama" ] && [ "$current_ollama" = "$latest_ollama" ]; then
            log_ok "Ollama engine is up to date ($current_ollama)."
        elif [ -n "$latest_ollama" ]; then
            log_info "Upgrading Ollama engine (${current_ollama:-unknown} -> $latest_ollama)..."
            curl -fsSL https://ollama.com/install.sh | sh || log_warn "Ollama update failed, continuing..."
        fi

        # Pull updates ONLY for currently installed models
        local ollama_list
        if ollama_list="$(ollama list 2>/dev/null)"; then
            local models
            models="$(echo "$ollama_list" | tail -n +2 | awk '{print $1}' | grep -v '^$' || true)"
            if [ -n "$models" ]; then
                local model_arr=()
                while IFS= read -r m; do
                    [ -n "$m" ] && model_arr+=("$m")
                done <<< "$models"
                local total_models="${#model_arr[@]}"
                local midx=0
                log_info "Updating locally installed Ollama models ($total_models detected)..."
                for model in "${model_arr[@]}"; do
                    ((midx++))
                    log_substep "$midx" "$total_models" "Pulling latest $model..."
                    ollama pull "$model" || log_warn "Failed to pull Ollama model '$model', continuing..."
                done
                log_ok "All installed Ollama models updated."
            else
                log_ok "No local Ollama models installed."
            fi
        else
            log_warn "Ollama service is not running; skipping model updates."
        fi
    else
        skip_step "Ollama Engine" "not installed"
    fi
}
