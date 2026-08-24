#!/usr/bin/env bash
# modules/00_core_baseline.sh - Core Fleet Baseline Installer & Updater
#
# Ensures that on ANY Fedora node (bare-metal dev, personal, or fresh VM),
# all essential tools, compilers, runtimes, agents, and IDEs are automatically
# installed if missing, and kept fully up to date.

set -u

_update_or_install_go_tool() {
    local bin_name="$1"
    local install_path="$2"
    local bin_path="$HOME/go/bin/$bin_name"

    if [ -x "$bin_path" ]; then
        local mod_line mod_path current_ver latest_ver
        mod_line="$(go version -m "$bin_path" 2>/dev/null | grep -E "^\s*mod\s+" | head -n 1)"
        mod_path="$(echo "$mod_line" | awk '{print $2}')"
        current_ver="$(echo "$mod_line" | awk '{print $3}')"

        if [ -n "$mod_path" ]; then
            log_action "Querying Go proxy for latest $bin_name version..."
            latest_ver="$(curl -s --max-time 3 "https://proxy.golang.org/$mod_path/@latest" 2>/dev/null | grep -o '"Version":"[^"]*"' | cut -d'"' -f4 || true)"
        fi

        if [ -n "$current_ver" ] && [ -n "$latest_ver" ] && [ "$current_ver" = "$latest_ver" ]; then
            log_ok "$bin_name is already up to date ($current_ver)."
            return 0
        fi
    fi

    log_info "Installing/updating $bin_name ($install_path)..."
    go install "$install_path@latest"
}

run_core_baseline() {
    echo -e "\n${BOLD}${CYAN}============================================================${RESET}"
    echo -e "${BOLD}${CYAN}   Core Fleet Baseline: Verifying & Updating Essentials    ${RESET}"
    echo -e "${BOLD}${CYAN}============================================================${RESET}"

    # 1. C/C++ Build Tools (gcc, make, headers for Rust/C extensions)
    step "Core: C/C++ Build Toolchain (gcc, make, pkgconf)"
    log_action "Verifying C/C++ compiler and build tools..."
    if ! command -v gcc &>/dev/null || ! command -v make &>/dev/null; then
        log_bootstrap "Installing gcc, gcc-c++, make, and build essentials..."
        sudo dnf install -y gcc gcc-c++ make pkgconf-pkg-config 2>/dev/null || true
    fi
    if command -v gcc &>/dev/null; then
        log_ok "C/C++ build tools (gcc, make) verified."
    fi

    # 2. Python & Pip
    step "Core: Python 3 & Pip"
    log_action "Checking Python 3 pip status..."
    if ! python3 -c "import pip" &>/dev/null; then
        log_bootstrap "Installing python3-pip package via DNF..."
        sudo dnf install -y python3-pip || python3 -m ensurepip --user || true
    fi
    if python3 -c "import pip" &>/dev/null; then
        python3 -m pip install --user --upgrade pip 2>/dev/null || true
        log_ok "pip is installed and up to date."
    else
        log_warn "pip installation could not be completed."
    fi

    # 3. Astral uv
    step "Core: Astral uv package manager"
    log_action "Checking Astral uv self-update..."
    if ! command -v uv &>/dev/null; then
        log_bootstrap "Installing Astral uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    else
        uv self update 2>/dev/null || true
        log_ok "uv is installed and up to date."
    fi

    # 4. NPM User Prefix (~/.npm-global) & Global Tools
    step "Core: NPM Global Configuration & Tools"
    log_action "Checking npm global prefix configuration..."
    if command -v npm &>/dev/null; then
        local npm_prefix
        npm_prefix="$(npm config get prefix 2>/dev/null || true)"
        if [ "$npm_prefix" = "/usr" ] || [ "$npm_prefix" = "/usr/local" ] || [ -z "$npm_prefix" ]; then
            log_bootstrap "Configuring user-owned npm prefix at $HOME/.npm-global..."
            mkdir -p "$HOME/.npm-global/bin" "$HOME/.npm-global/lib"
            npm config set prefix "$HOME/.npm-global"
            export PATH="$HOME/.npm-global/bin:$PATH"
        fi
        log_action "Updating user global NPM packages (e.g. pnpm, gemini-cli)..."
        npm update -g 2>/dev/null || true
        log_ok "NPM global configuration and tools synchronized ($HOME/.npm-global)."
    fi

    # 5. User Python CLI Tools (via uv tool / pip)
    step "Core: Python CLI Utilities Suite"
    local cli_tools=(
        "esptool"
        "meshtastic"
        "openai-whisper"
        "mcp"
        "rich-click"
        "tabulate"
        "pyinstaller"
        "uvicorn"
        "websockets"
    )
    local user_libs=(
        "google-antigravity"
        "google-genai"
        "setuptools"
    )
    local total_tools="${#cli_tools[@]}"
    local tidx=0
    if command -v uv &>/dev/null; then
        log_action "Upgrading existing uv tools..."
        uv tool upgrade --all 2>/dev/null || true
        for tool in "${cli_tools[@]}"; do
            ((tidx++))
            log_substep "$tidx" "$total_tools" "Verifying Python CLI tool: $tool..."
            uv tool install --upgrade "$tool" 2>/dev/null || true
        done
        log_action "Syncing user-level Python libraries (google-genai, antigravity)..."
        python3 -m pip install --user --upgrade "${user_libs[@]}" 2>/dev/null || true
        uv cache prune 2>/dev/null || true
        log_ok "Python CLI utilities and user libraries synchronized."
    elif python3 -c "import pip" &>/dev/null; then
        for tool in "${cli_tools[@]}" "${user_libs[@]}"; do
            ((tidx++))
            log_substep "$tidx" "$((total_tools + ${#user_libs[@]}))" "Verifying Python package: $tool..."
            python3 -m pip install --user --upgrade "$tool" 2>/dev/null || true
        done
        log_ok "Python CLI utilities and user libraries synced via pip."
    fi

    # 6. Micro Editor
    step "Core: Micro Editor"
    log_action "Checking Micro editor and plugins..."
    if ! command -v micro &>/dev/null; then
        log_bootstrap "Installing Micro editor..."
        sudo dnf install -y micro 2>/dev/null || (curl https://getmic.ro | bash && mkdir -p "$HOME/.local/bin" && mv micro "$HOME/.local/bin/") 2>/dev/null || true
    fi
    if command -v micro &>/dev/null; then
        micro -plugin update 2>/dev/null || true
        log_ok "Micro editor is installed and plugins updated."
    fi

    # 7. GitHub CLI (gh)
    step "Core: GitHub CLI (gh)"
    log_action "Checking GitHub CLI extensions..."
    if ! command -v gh &>/dev/null; then
        log_bootstrap "Installing GitHub CLI..."
        sudo dnf install -y gh 2>/dev/null || true
    fi
    if command -v gh &>/dev/null; then
        if gh auth status &>/dev/null; then
            gh extension upgrade --all 2>/dev/null || true
            log_ok "GitHub CLI extensions updated."
        else
            log_ok "GitHub CLI is installed (not currently authenticated)."
        fi
    fi

    # 8. Rust (rustup)
    step "Core: Rust Toolchain & Cargo Tools (rustup)"
    log_action "Checking Rustup toolchains and components..."
    if ! command -v rustup &>/dev/null && [ ! -f "$HOME/.cargo/bin/rustup" ]; then
        log_bootstrap "Installing Rustup toolchain..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
        if [ -f "$HOME/.cargo/env" ]; then
            # shellcheck disable=SC1091
            source "$HOME/.cargo/env"
        fi
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
    if command -v rustup &>/dev/null || [ -x "$HOME/.cargo/bin/rustup" ]; then
        if [ -f "$HOME/.cargo/env" ]; then
            # shellcheck disable=SC1091
            source "$HOME/.cargo/env"
        fi
        rustup update || true
        if [ -x "$HOME/.cargo/bin/cargo-tauri" ]; then
            log_action "Updating Cargo tool: tauri-cli..."
            cargo install tauri-cli --locked 2>/dev/null || true
        fi
        log_ok "Rust toolchain and Cargo tools are up to date."
    fi

    # 9. Bun Runtime
    step "Core: Bun JavaScript/TypeScript Runtime"
    log_action "Checking Bun runtime updates..."
    if ! command -v bun &>/dev/null; then
        log_bootstrap "Installing Bun runtime..."
        curl -fsSL https://bun.sh/install | bash
        export PATH="$HOME/.bun/bin:$PATH"
    else
        bun upgrade 2>/dev/null || true
        log_ok "Bun runtime is up to date."
    fi

    # 10. Go & Go Tooling (gopls, dlv)
    step "Core: Go Compiler & Developer Tooling"
    log_action "Checking Go toolchain and language servers..."
    if ! command -v go &>/dev/null; then
        log_bootstrap "Installing Go compiler via DNF..."
        sudo dnf install -y golang 2>/dev/null || true
    fi
    if command -v go &>/dev/null; then
        _update_or_install_go_tool "gopls" "golang.org/x/tools/gopls" || true
        _update_or_install_go_tool "dlv" "github.com/go-delve/delve/cmd/dlv" || true
        log_ok "Go compiler and tooling verified."
    fi

    # 11. Docker Engine & Docker Compose
    step "Core: Docker Engine & Docker Compose"
    log_action "Verifying Docker Engine service status..."
    if ! command -v docker &>/dev/null; then
        log_bootstrap "Installing Docker CE, containerd, and Docker Compose plugin..."
        sudo dnf -y install dnf-plugins-core 2>/dev/null || true
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || \
            sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || true
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
        sudo systemctl enable --now docker 2>/dev/null || true
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        log_ok "Docker Engine installed and systemd service activated."
    else
        if systemctl is-active --quiet docker 2>/dev/null; then
            log_ok "Docker Engine is active and managed via DNF."
        else
            sudo systemctl enable --now docker 2>/dev/null || true
            log_ok "Docker Engine service started."
        fi
    fi

    # 12. Android CLI & SDK
    step "Core: Android CLI & SDK Tools"
    log_action "Checking Android SDK and tools..."
    local android_sdk_dir="$HOME/Android/Sdk"
    if ! command -v android &>/dev/null && [ ! -d "$android_sdk_dir/cmdline-tools" ]; then
        log_bootstrap "Installing Android SDK Command-line Tools..."
        mkdir -p "$android_sdk_dir/cmdline-tools"
        local tmp_cmdline="$(mktemp -d -t android-cmdline-XXXXXX)"
        local cmdline_url="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
        if curl -# -fSL -o "$tmp_cmdline/cmdline.zip" "$cmdline_url" 2>/dev/null; then
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
            log_ok "Android SDK Commandline Tools installed."
        else
            log_warn "Failed to download Android commandlinetools."
        fi
        rm -rf "$tmp_cmdline"
    elif command -v android &>/dev/null; then
        android update 2>/dev/null || true
        log_ok "Android CLI is installed and up to date."
    fi

    # 13. Android Studio Latest Preview
    step "Core: Android Studio Latest Preview"
    log_action "Verifying Android Studio Preview installation..."
    local studio_preview_dir="$HOME/.local/opt/android-studio-preview"
    if is_android_studio_running; then
        echo -e "  ${YELLOW}[SKIP] Android Studio is currently running; skipping update to avoid interrupting active work.${RESET}"
    else
        if [ ! -d "$studio_preview_dir" ] && [ ! -f "$HOME/.local/bin/android-studio-preview" ]; then
            log_bootstrap "Setting up Android Studio Preview directory structure..."
            mkdir -p "$studio_preview_dir" "$HOME/.local/share/applications" "$HOME/.local/bin"
            cat << DESKTOP > "$HOME/.local/share/applications/android-studio-preview.desktop"
[Desktop Entry]
Name=Android Studio Preview
Exec=$studio_preview_dir/bin/studio.sh
Icon=$studio_preview_dir/bin/studio.png
Type=Application
Terminal=false
Categories=Development;IDE;
DESKTOP
            cat << WRAPPER > "$HOME/.local/bin/android-studio-preview"
#!/usr/bin/env bash
exec "$studio_preview_dir/bin/studio.sh" "\$@"
WRAPPER
            chmod +x "$HOME/.local/bin/android-studio-preview"
            log_ok "Android Studio Preview desktop and CLI launchers registered."
        else
            log_ok "Android Studio Preview installation verified."
        fi
    fi

    # 14. Google Antigravity Desktop
    step "Core: Google Antigravity Desktop"
    log_action "Checking Google Antigravity Desktop releases..."
    local antigravity_dir="$HOME/.local/opt/antigravity"
    if is_antigravity_desktop_running; then
        echo -e "  ${YELLOW}[SKIP] Google Antigravity Desktop is currently active; skipping update.${RESET}"
    else
        local arch
        arch=$(uname -m)
        local arch_dir=""
        case "$arch" in
            x86_64|amd64) arch_dir="linux-x64" ;;
            aarch64|arm64) arch_dir="linux-arm" ;;
            *) log_warn "Unsupported architecture for Antigravity: $arch" ;;
        esac

        if [ -n "$arch_dir" ]; then
            local manifest_url="https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/latest-x64-linux.yml"
            local manifest_data
            manifest_data="$(curl -s --max-time 5 "$manifest_url" 2>/dev/null || true)"
            
            local current_antigravity=""
            if [ -f "$antigravity_dir/.version" ]; then
                current_antigravity="$(cat "$antigravity_dir/.version" 2>/dev/null || true)"
            fi

            local latest_antigravity
            latest_antigravity="$(echo "$manifest_data" | grep -E '^version:' | awk '{print $2}' || true)"

            if [ -n "$current_antigravity" ] && [ -n "$latest_antigravity" ] && [ "$current_antigravity" = "$latest_antigravity" ]; then
                log_ok "Google Antigravity Desktop is up to date ($current_antigravity)."
            elif [ -n "$manifest_data" ] && [ -n "$latest_antigravity" ]; then
                log_info "Installing/updating Google Antigravity Desktop (${current_antigravity:-none} -> $latest_antigravity)..."
                local base_url
                base_url="$(echo "$manifest_data" | grep -o 'https://storage.googleapis.com/antigravity-public/antigravity-hub/[^/]*' | head -n 1)"
                local download_url="${base_url}/${arch_dir}/Antigravity.tar.gz"

                local tmp_work_dir
                tmp_work_dir="$(mktemp -d -t antigravity-update-XXXXXX)"
                local tarball_tmp="${tmp_work_dir}/Antigravity.tar.gz"
                local extract_dir="${tmp_work_dir}/extract"
                mkdir -p "$extract_dir"

                if curl -# -fSL -o "$tarball_tmp" "$download_url" 2>/dev/null; then
                    tar -xzf "$tarball_tmp" -C "$extract_dir"
                    local payload_dir
                    payload_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
                    [ -z "$payload_dir" ] && payload_dir="$extract_dir"

                    if [ -d "$payload_dir" ] && [ -f "$payload_dir/antigravity" ]; then
                        rm -rf "$antigravity_dir"
                        mkdir -p "$antigravity_dir"
                        mv "$payload_dir"/* "$antigravity_dir/"
                        chmod +x "$antigravity_dir/antigravity"
                        echo "$latest_antigravity" > "$antigravity_dir/.version"

                        mkdir -p "$HOME/.local/share/applications" "$HOME/Desktop" "$HOME/.local/bin"
                        cat << DESKTOP > "$HOME/.local/share/applications/antigravity.desktop"
[Desktop Entry]
Name=Antigravity
Exec=$antigravity_dir/antigravity --no-sandbox
Icon=$antigravity_dir/icon.png
Type=Application
Terminal=false
Categories=Development;IDE;
DESKTOP
                        cp "$HOME/.local/share/applications/antigravity.desktop" "$HOME/Desktop/" 2>/dev/null || true
                        chmod +x "$HOME/Desktop/antigravity.desktop" 2>/dev/null || true

                        cat << WRAPPER > "$HOME/.local/bin/antigravity"
#!/bin/bash
exec "$antigravity_dir/antigravity" --no-sandbox "\$@"
WRAPPER
                        chmod +x "$HOME/.local/bin/antigravity"
                        log_ok "Google Antigravity Desktop updated to $latest_antigravity."
                    fi
                fi
                rm -rf "$tmp_work_dir"
            fi
        fi
    fi

    # 15. Google Antigravity IDE
    step "Core: Google Antigravity IDE"
    log_action "Checking Google Antigravity IDE releases..."
    local antigravity_ide_dir="$HOME/.local/opt/antigravity-ide"
    if is_antigravity_ide_running; then
        echo -e "  ${YELLOW}[SKIP] Google Antigravity IDE is currently active; skipping update to avoid interrupting active work.${RESET}"
    else
        local arch
        arch=$(uname -m)
        local arch_ep=""
        case "$arch" in
            x86_64|amd64) arch_ep="linux-x64" ;;
            aarch64|arm64) arch_ep="linux-arm64" ;;
            *) log_warn "Unsupported architecture for Antigravity IDE: $arch" ;;
        esac

        if [ -n "$arch_ep" ]; then
            local update_api="https://antigravity-ide-auto-updater-974169037036.us-central1.run.app/api/update/${arch_ep}/stable/latest"
            local response
            response="$(curl -s --max-time 5 "$update_api" 2>/dev/null || true)"
            local download_url
            download_url="$(echo "$response" | grep -o '"url":"[^"]*"' | cut -d'"' -f4 || true)"
            
            local current_ide=""
            if [ -f "$antigravity_ide_dir/.version" ]; then
                current_ide="$(cat "$antigravity_ide_dir/.version" 2>/dev/null || true)"
            fi

            local latest_ide=""
            if [ -n "$download_url" ]; then
                latest_ide="$(echo "$download_url" | sed -E 's|.*/stable/([^/-]+).*|\1|')"
            fi

            if [ -n "$current_ide" ] && [ -n "$latest_ide" ] && [ "$current_ide" = "$latest_ide" ]; then
                log_ok "Google Antigravity IDE is up to date ($current_ide)."
            elif [ -n "$download_url" ] && [ -n "$latest_ide" ]; then
                log_info "Installing/updating Google Antigravity IDE (${current_ide:-none} -> $latest_ide)..."
                local encoded_url="${download_url// /%20}"
                local tmp_work_dir
                tmp_work_dir="$(mktemp -d -t antigravity-ide-update-XXXXXX)"
                local tarball_tmp="${tmp_work_dir}/Antigravity-IDE.tar.gz"
                local extract_dir="${tmp_work_dir}/extract"
                mkdir -p "$extract_dir"

                if curl -# -fSL -o "$tarball_tmp" "$encoded_url" 2>/dev/null; then
                    tar -xzf "$tarball_tmp" -C "$extract_dir"
                    local payload_dir
                    payload_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
                    [ -z "$payload_dir" ] && payload_dir="$extract_dir"

                    if [ -d "$payload_dir" ] && ([ -f "$payload_dir/antigravity-ide" ] || [ -f "$payload_dir/antigravity" ]); then
                        rm -rf "$antigravity_ide_dir"
                        mkdir -p "$antigravity_ide_dir"
                        mv "$payload_dir"/* "$antigravity_ide_dir/"
                        if [ -f "$antigravity_ide_dir/antigravity-ide" ]; then
                            chmod +x "$antigravity_ide_dir/antigravity-ide"
                        elif [ -f "$antigravity_ide_dir/antigravity" ]; then
                            chmod +x "$antigravity_ide_dir/antigravity"
                        fi
                        echo "$latest_ide" > "$antigravity_ide_dir/.version"

                        if [ -f "$antigravity_ide_dir/resources/app/resources/linux/code.png" ]; then
                            cp "$antigravity_ide_dir/resources/app/resources/linux/code.png" "$antigravity_ide_dir/icon.png"
                        fi

                        mkdir -p "$HOME/.local/share/applications" "$HOME/Desktop" "$HOME/.local/bin"
                        cat << DESKTOP > "$HOME/.local/share/applications/antigravity-ide.desktop"
[Desktop Entry]
Name=Antigravity-IDE
Exec=$antigravity_ide_dir/antigravity-ide --no-sandbox
Icon=$antigravity_ide_dir/icon.png
Type=Application
Terminal=false
Categories=Development;IDE;
DESKTOP
                        cp "$HOME/.local/share/applications/antigravity-ide.desktop" "$HOME/Desktop/" 2>/dev/null || true
                        chmod +x "$HOME/Desktop/antigravity-ide.desktop" 2>/dev/null || true

                        cat << WRAPPER > "$HOME/.local/bin/antigravity-ide"
#!/bin/bash
exec "$antigravity_ide_dir/antigravity-ide" --no-sandbox "\$@"
WRAPPER
                        chmod +x "$HOME/.local/bin/antigravity-ide"
                        log_ok "Google Antigravity IDE updated to $latest_ide."
                    fi
                fi
                rm -rf "$tmp_work_dir"
            fi
        fi
    fi

    # 16. Agy CLI
    step "Core: Agy CLI"
    log_action "Checking Agy CLI updates..."
    if is_cli_running "agy"; then
        echo -e "  ${YELLOW}[SKIP] Agy CLI is currently active; skipping update.${RESET}"
    else
        if ! command -v agy &>/dev/null; then
            log_bootstrap "Installing Agy CLI..."
            npm install -g @google/agy 2>/dev/null || true
        else
            agy update 2>/dev/null || true
            log_ok "Agy CLI is up to date."
        fi
    fi

    # 17. Herdr CLI
    step "Core: Herdr CLI"
    log_action "Checking Herdr CLI release..."
    if is_cli_running "herdr"; then
        echo -e "  ${YELLOW}[SKIP] Herdr CLI is currently active; skipping update.${RESET}"
    else
        if ! command -v herdr &>/dev/null; then
            log_bootstrap "Installing Herdr CLI..."
            curl -fsSL https://herdr.dev/install.sh | bash 2>/dev/null || true
        else
            local current_herdr
            current_herdr="$(herdr --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
            local latest_herdr
            latest_herdr="$(curl -s --max-time 3 "https://herdr.dev/latest.json" 2>/dev/null | grep -m1 '"version":' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)"
            if [ -n "$current_herdr" ] && [ -n "$latest_herdr" ] && [ "$current_herdr" = "$latest_herdr" ]; then
                log_ok "Herdr is already up to date ($current_herdr)."
            else
                log_info "Updating Herdr CLI..."
                herdr update 2>/dev/null || true
            fi
        fi
    fi

    # 18. Syncthing Sync Engine & 0.0.0.0 GUI Configuration
    step "Core: Syncthing Sync Engine"
    log_action "Verifying Syncthing daemon and configuration..."
    if ! command -v syncthing &>/dev/null; then
        log_bootstrap "Installing Syncthing via DNF..."
        sudo dnf install -y syncthing 2>/dev/null || true
    fi

    if command -v syncthing &>/dev/null; then
        # Ensure configuration exists
        local st_config_paths=(
            "$HOME/.local/state/syncthing/config.xml"
            "$HOME/.config/syncthing/config.xml"
        )
        local found_config=""
        for cfg in "${st_config_paths[@]}"; do
            if [ -f "$cfg" ]; then
                found_config="$cfg"
                break
            fi
        done

        if [ -z "$found_config" ]; then
            log_bootstrap "Generating initial Syncthing configuration..."
            syncthing generate 2>/dev/null || syncthing --generate 2>/dev/null || true
            for cfg in "${st_config_paths[@]}"; do
                if [ -f "$cfg" ]; then
                    found_config="$cfg"
                    break
                fi
            done
        fi

        # Configure GUI to listen on 0.0.0.0:8384
        if [ -n "$found_config" ] && [ -f "$found_config" ]; then
            if grep -q "<address>127.0.0.1:8384</address>" "$found_config"; then
                log_info "Configuring Syncthing GUI to listen on 0.0.0.0:8384..."
                sed -i 's|<address>127.0.0.1:8384</address>|<address>0.0.0.0:8384</address>|g' "$found_config"
            fi
        fi

        # Open firewalld ports if firewalld is running
        if command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
            sudo firewall-cmd --add-service=syncthing --permanent >/dev/null 2>&1 || true
            sudo firewall-cmd --add-port=8384/tcp --permanent >/dev/null 2>&1 || true
            sudo firewall-cmd --reload >/dev/null 2>&1 || true
        fi

        # Enable and start user systemd service
        if ! systemctl --user is-active --quiet syncthing.service 2>/dev/null; then
            systemctl --user enable --now syncthing.service 2>/dev/null || true
        fi
        log_ok "Syncthing installed, GUI listening on 0.0.0.0:8384, and service active."
    fi
}
