#!/usr/bin/env bash
# install.sh - 1-step installer for new Fedora nodes
#
# Links fedora-update executables into ~/.local/bin and ensures Syncthing is installed and configured.

set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.local/bin"

# Ensure all scripts have executable permissions
chmod +x \
    "$REPO_DIR/update" \
    "$REPO_DIR/update-all" \
    "$REPO_DIR/bin/fedora-update" \
    "$REPO_DIR/lib/"*.sh \
    "$REPO_DIR/modules/"*.sh

# Create symlinks in ~/.local/bin
ln -sf "$REPO_DIR/update" "$HOME/.local/bin/update"
ln -sf "$REPO_DIR/update-all" "$HOME/.local/bin/update-all"
ln -sf "$REPO_DIR/bin/fedora-update" "$HOME/.local/bin/fedora-update"

echo -e "\033[1;32m[OK] fedora-update successfully registered in ~/.local/bin!\033[0m"

# Check and bootstrap Syncthing if missing
if ! command -v syncthing &>/dev/null; then
    echo -e "\033[1;33m[*] Syncthing is not installed. Installing and enabling user service...\033[0m"
    sudo dnf install -y syncthing
    syncthing generate 2>/dev/null || true
    
    # Configure 0.0.0.0:8384
    for cfg in "$HOME/.local/state/syncthing/config.xml" "$HOME/.config/syncthing/config.xml"; do
        if [ -f "$cfg" ]; then
            sed -i 's|<address>127.0.0.1:8384</address>|<address>0.0.0.0:8384</address>|g' "$cfg"
        fi
    done

    # Enable and start user service
    systemctl --user enable --now syncthing.service 2>/dev/null || true
    echo -e "\033[1;32m[OK] Syncthing installed and running (Web UI: http://0.0.0.0:8384)\033[0m"
fi

echo -e "\nYou can now run: \033[1;36mupdate\033[0m or \033[1;36mupdate-all\033[0m from any terminal."
