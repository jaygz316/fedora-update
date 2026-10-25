#!/usr/bin/env bash
step "Core: Docker Engine & Docker Compose"
if ! command -v docker &>/dev/null; then
    log_bootstrap "Installing Docker CE + Compose plugin..."
    run_or_dry sudo dnf -y install dnf-plugins-core || true
    run_or_dry sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || \
        run_or_dry sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || true
    run_or_dry sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    run_or_dry sudo systemctl enable --now docker || true
    run_or_dry sudo usermod -aG docker "$USER" || true
    log_ok "Docker installed and service activated."
else
    systemctl is-active --quiet docker 2>/dev/null || sudo systemctl enable --now docker 2>/dev/null || true
    log_ok "Docker Engine active."
fi
