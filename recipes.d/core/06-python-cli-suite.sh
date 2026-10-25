#!/usr/bin/env bash
step "Core: Python CLI Utilities Suite"
local cli_tools=( esptool meshtastic openai-whisper mcp rich-click tabulate pyinstaller uvicorn websockets )
local user_libs=( google-antigravity google-genai setuptools )
local total_tools="${#cli_tools[@]}" tidx=0
if command -v uv &>/dev/null; then
    log_action "Checking and upgrading uv-managed CLI tools..."
    run_silent_log uv tool upgrade --all || true
    local installed_tools; installed_tools="$(uv tool list --color never 2>/dev/null || true)"
    for tool in "${cli_tools[@]}"; do
        ((tidx++))
        if ! echo "$installed_tools" | grep -q "^$tool "; then
            log_substep "$tidx" "$total_tools" "Installing missing $tool via uv..."
            run_silent_log uv tool install --force "$tool" || true
        fi
    done
    log_action "Verifying user Python libraries (${user_libs[*]})..."
    python3 -m pip install --user --upgrade "${user_libs[@]}" 2>&1 | while IFS= read -r pline; do
        case "$pline" in
            *"Successfully installed"*|*"Downloading"*)
                echo -e "  ${CYAN}--> $pline${RESET}" ;;
            *) ;;
        esac
    done
    log_ok "Python CLI utilities synchronized."
elif python3 -c "import pip" &>/dev/null; then
    log_action "Checking Python CLI tools via pip..."
    for tool in "${cli_tools[@]}" "${user_libs[@]}"; do
        ((tidx++)); log_substep "$tidx" "$((total_tools + ${#user_libs[@]}))" "Verifying $tool..."
        run_silent_log python3 -m pip install --user --upgrade "$tool" || true
    done
    log_ok "Python CLI utilities synced via pip."
else
    skip_step "Python CLI Suite" "uv or pip not found"
fi
