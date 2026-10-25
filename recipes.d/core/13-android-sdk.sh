#!/usr/bin/env bash
step "Core: Android CLI & SDK Tools"
local android_sdk_dir="$HOME/Android/Sdk"
if ! command -v android &>/dev/null && [ ! -d "$android_sdk_dir/cmdline-tools" ]; then
    log_bootstrap "Installing Android SDK Command-line Tools..."
    mkdir -p "$android_sdk_dir/cmdline-tools"
    local tmp_cmdline; tmp_cmdline="$(mktemp -d -t android-cmdline-XXXXXX)"
    if curl -# -fSL -o "$tmp_cmdline/cmdline.zip" \
        "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" 2>/dev/null; then
        unzip -q "$tmp_cmdline/cmdline.zip" -d "$tmp_cmdline"
        rm -rf "$android_sdk_dir/cmdline-tools/latest"
        mv "$tmp_cmdline/cmdline-tools" "$android_sdk_dir/cmdline-tools/latest"
        mkdir -p "$HOME/.local/bin"
        cat << 'WRAPPER' > "$HOME/.local/bin/android"
#!/usr/bin/env bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
exec "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "$@"
WRAPPER
        chmod +x "$HOME/.local/bin/android"
        log_ok "Android SDK Command-line Tools installed."
    else
        log_warn "Failed to download Android commandlinetools."
    fi
    rm -rf "$tmp_cmdline"
elif command -v android &>/dev/null; then
    run_silent_log android update || true
    log_ok "Android CLI up to date."
fi
