#!/usr/bin/env bash
step "Core: C/C++ Build Toolchain (gcc, make, pkgconf, aria2, zstd)"
if ! command -v gcc &>/dev/null || ! command -v make &>/dev/null || ! command -v aria2c &>/dev/null || ! command -v zstd &>/dev/null; then
    log_bootstrap "Installing gcc, gcc-c++, make, pkgconf, aria2, zstd..."
    run_or_dry sudo dnf install -y gcc gcc-c++ make pkgconf-pkg-config aria2 zstd 2>/dev/null || true
fi
command -v gcc &>/dev/null && log_ok "C/C++ build tools & download accelerators verified." || log_warn "C/C++ build tools not verified."
