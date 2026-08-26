#!/usr/bin/env bash
# install.sh — Bootstrap fedora-update on a new Fedora node
#
# Run once after cloning: bash install.sh
# Subsequent runs are safe (idempotent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\n\033[1;36m========================================\033[0m"
echo -e "\033[1;36m  fedora-update: Install & Bootstrap     \033[0m"
echo -e "\033[1;36m========================================\033[0m\n"

# 1. Make scripts executable
chmod +x "$SCRIPT_DIR/update" "$SCRIPT_DIR/update-all" "$SCRIPT_DIR/install.sh"
echo -e "\033[0;32m[OK] Scripts marked executable.\033[0m"

# 2. Create symlinks in ~/.local/bin
mkdir -p "$HOME/.local/bin"
ln -sf "$SCRIPT_DIR/update"     "$HOME/.local/bin/update"
ln -sf "$SCRIPT_DIR/update-all" "$HOME/.local/bin/update-all"
echo -e "\033[0;32m[OK] Symlinks created in ~/.local/bin.\033[0m"

# 3. Install + bootstrap Syncthing (if not already present)
if ! command -v syncthing &>/dev/null; then
    echo -e "\033[1;33m[*] Installing Syncthing via DNF...\033[0m"
    sudo dnf install -y syncthing
fi

# Configure Syncthing to listen on all interfaces (not just localhost)
for cfg in "$HOME/.local/state/syncthing/config.xml" "$HOME/.config/syncthing/config.xml"; do
    if [ -f "$cfg" ] && grep -q "<address>127.0.0.1:8384</address>" "$cfg"; then
        sed -i 's|<address>127.0.0.1:8384</address>|<address>0.0.0.0:8384</address>|g' "$cfg"
        echo -e "\033[0;32m[OK] Syncthing GUI set to 0.0.0.0:8384.\033[0m"
    fi
done

# Enable Syncthing user service
systemctl --user enable --now syncthing.service 2>/dev/null \
    && echo -e "\033[1;32m[OK] Syncthing installed and running (Web UI: http://0.0.0.0:8384)\033[0m" \
    || echo -e "\033[0;33m[!] Could not auto-start Syncthing service. Start it manually.\033[0m"

# 4. Warn if ~/.local/bin is not in PATH
if [[ ":${PATH}:" != *":$HOME/.local/bin:"* ]]; then
    echo -e "\n\033[0;33m[!] NOTE: ~/.local/bin is not in your current PATH.\033[0m"
    echo -e "    Add the following to your ~/.bashrc or ~/.zshrc and restart your shell:"
    echo -e "    \033[1mexport PATH=\"\$HOME/.local/bin:\$PATH\"\033[0m\n"
fi

echo -e "\nYou can now run: \033[1;36mupdate\033[0m or \033[1;36mupdate-all\033[0m from any terminal."
