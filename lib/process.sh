#!/usr/bin/env bash
# lib/process.sh - Active application and AI agent process detection
#

set -u

# Helper to filter out self, subshells, runners, and background telemetry hooks
_is_process_excluded() {
    local pid="$1"
    local my_pid="$$"
    local bash_pid="${BASHPID:-$$}"
    local p_pid="${PPID:-0}"

    if [ "$pid" = "$my_pid" ] || [ "$pid" = "$p_pid" ] || [ "$pid" = "$bash_pid" ]; then
        return 0
    fi

    # Check executable name (comm)
    local comm
    comm=$(ps -p "$pid" -o comm= 2>/dev/null || true)
    case "$comm" in
        pgrep|grep|bash|sh|zsh) return 0 ;;
    esac

    # Read cmdline to ignore telemetry hooks and the update script itself
    local cmdline
    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
    if [[ "$cmdline" == *"telemetry_hook_bundle.js"* ]] || \
       [[ "$cmdline" == *"fedora-update"* ]] || \
       [[ "$cmdline" == *"/bin/fedora-update"* ]]; then
        return 0
    fi

    return 1 # Not excluded
}

# Check if a process is running by exact executable/command name (comm)
is_process_exact_running() {
    local proc_name="$1"
    local pids
    pids=$(pgrep -x "$proc_name" 2>/dev/null || true)

    if [ -n "$pids" ]; then
        for pid in $pids; do
            if ! _is_process_excluded "$pid"; then
                return 0 # Exact process is running
            fi
        done
    fi
    return 1 # Not running
}

# 1. Android Studio Preview (Java IDE process or studio.sh launcher)
is_android_studio_running() {
    local pids
    pids=$(pgrep -f "com.intellij.idea.Main|/android-studio/|/android-studio-preview/" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            if ! _is_process_excluded "$pid"; then
                local cmdline
                cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
                # Confirm it is Android Studio, not LM Studio or other IDEs
                if [[ "$cmdline" == *"android-studio"* ]] || [[ "$cmdline" == *"com.intellij.idea.Main"* ]]; then
                    return 0
                fi
            fi
        done
    fi
    if is_process_exact_running "studio.sh" || is_process_exact_running "studio64"; then
        return 0
    fi
    return 1
}

# 2. Visual Studio Code Desktop (only the GUI IDE binary 'code', excluding chrome/antigravity/claude)
is_vscode_running() {
    is_process_exact_running "code"
}

# 3. Google Antigravity Desktop GUI (~/.local/opt/antigravity/antigravity)
is_antigravity_desktop_running() {
    local pids
    pids=$(pgrep -x "antigravity" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            if ! _is_process_excluded "$pid"; then
                local cmdline
                cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
                # Must be the desktop electron app, excluding antigravity-cli and antigravity-ide
                if [[ "$cmdline" == *"/opt/antigravity/antigravity"* ]] && \
                   [[ "$cmdline" != *"antigravity-cli"* ]] && \
                   [[ "$cmdline" != *"antigravity-ide"* ]]; then
                    return 0
                fi
            fi
        done
    fi
    return 1
}

# 4. Google Antigravity IDE (~/.local/opt/antigravity-ide/antigravity-ide)
is_antigravity_ide_running() {
    local pids
    pids=$(pgrep -x "antigravity-ide" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            if ! _is_process_excluded "$pid"; then
                return 0
            fi
        done
    fi
    return 1
}

# 5. CLI Tool Execution Checks (Agy, Herdr, Claude)
is_cli_running() {
    local cli_name="$1"
    local pids
    pids=$(pgrep -x "$cli_name" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            if ! _is_process_excluded "$pid"; then
                # If herdr, ignore the background daemon 'herdr server'
                if [ "$cli_name" = "herdr" ]; then
                    local cmdline
                    cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
                    if [[ "$cmdline" == *"server"* ]]; then
                        continue
                    fi
                fi
                return 0
            fi
        done
    fi
    return 1
}

# Generic fallback / backward-compatible check
is_app_running() {
    local pattern="$1"
    case "$pattern" in
        studio|android-studio) is_android_studio_running ;;
        code|vscode) is_vscode_running ;;
        antigravity) is_antigravity_desktop_running ;;
        antigravity-ide) is_antigravity_ide_running ;;
        agy|herdr|claude) is_cli_running "$pattern" ;;
        *)
            local pids
            pids=$(pgrep -f "(^|/)$pattern(\$|[[:space:]])" 2>/dev/null || pgrep -f "$pattern" 2>/dev/null || true)
            if [ -n "$pids" ]; then
                for pid in $pids; do
                    if ! _is_process_excluded "$pid"; then
                        return 0
                    fi
                done
            fi
            return 1
            ;;
    esac
}

# Check if an agent or application is currently active/working
# Returns 0 if busy (should skip), 1 if idle (safe to update)
check_agent_busy() {
    local app_name="$1"
    local process_pattern="$2"

    if is_app_running "$process_pattern"; then
        echo -e "  \033[0;33m[SKIP] ${app_name} is currently active/working; skipping update to prevent interrupting ongoing work.\033[0m"
        return 0
    fi
    return 1
}
