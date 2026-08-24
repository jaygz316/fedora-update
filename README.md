# Fedora Update (`fedora-update`)

A robust, 1-click multi-node system maintenance and toolchain synchronization suite tailored for **Fedora Linux** power users, developers, and multi-machine fleets.

Designed to keep 3 to 5 heterogeneous Fedora machines (development workstations, personal machines, lightweight VMs) synchronized and up to date without manual friction.

---

## ⚡ Key Highlights

- **1-Click Fleet Experience**: Run `update` or `update-all` on any Fedora machine. No manual profile management required.
- **Core Fleet Baseline**: Automatically bootstraps and keeps updated all essential toolchains on any machine (even a fresh minimal VM):
  - **AI Ecosystem**: Google Antigravity Desktop, Google Antigravity IDE, Agy CLI (`agy`), Herdr CLI (`herdr`).
  - **Development Languages**: Rust (`rustup`), Bun (`bun`), Go + `gopls`/`dlv`, Astral `uv`, Python `pip`.
  - **Containers & Sync**: Docker Engine & Compose, Syncthing (with Web GUI configured on `0.0.0.0:8384` and systemd service enabled).
  - **Android Toolchains**: Android SDK / CLI (`android`), Android Studio Latest Preview.
  - **Utilities & Package Managers**: Micro editor, GitHub CLI (`gh`), safe NPM user prefix (`~/.npm-global`), C/C++ build tools (`gcc`, `make`).
  - **Python CLI Tools**: `esptool`, `meshtastic`, `openai-whisper`, `google-antigravity`, `google-genai`, `mcp`, `rich-click`, `tabulate`, `pyinstaller`, `uvicorn`, `websockets`, `setuptools`.
- **Dynamic Installed-Only Updates**: If present on the host, automatically updates:
  - DNF packages & repositories (`upgrade --refresh`, `autoremove`, `clean packages`).
  - Flatpaks & runtimes (with delta decompression fallback and unused runtime pruning).
  - Hardware & system firmware via LVFS (`fwupdmgr`).
  - Secondary AI tools (Claude Code, LM Studio, Ollama engine & locally installed models).
  - SDKMAN! candidates, Google Cloud SDK (`gcloud`), VS Code extensions, Micro plugins, Agent skills.
  - Git documentation repositories (`~/projects/docs/*`, `~/.hermes/hermes-agent`).
- **Active Agent & App Protection**: Checks if an AI agent, IDE, or app is actively working. If busy, cleanly skips updating that component to prevent crashing your session.
- **Syncthing & Concurrency Safe**: Protects Git repos in synced folders (`~/projects/`) from dirty-tree rebase conflicts.
- **Automated Passwordless Sudo & Polkit**: Verifies sudo and Polkit permissions on launch and configures `/etc/sudoers.d/$USER` and `/etc/polkit-1/rules.d/` for promptless 1-click execution.
- **Post-Update Intelligence**: Checks for required kernel/glibc reboots (`dnf needs-restarting -r`) and active services requiring restart (`dnf needs-restarting -s`).

---

## 📦 Scripts & Architecture

```
fedora-update/
├── install.sh                  # 1-step installer & Syncthing bootstrapper for new nodes
├── update                      # Top-level 1-click routine maintenance runner
├── update-all                  # Top-level 1-click maintenance + SSD TRIM runner
├── bin/
│   └── fedora-update           # Unified modular engine (supports --trim, --only=, --skip=)
├── lib/
│   ├── common.sh               # Colors, logging, dynamic steps, passwordless sudo & polkit setup
│   ├── process.sh              # Active process & agent busy detection
│   └── git_guard.sh            # Syncthing-safe Git dirty-tree checks
└── modules/
    ├── 00_core_baseline.sh     # Core Fleet Baseline installer & updater (includes Syncthing 0.0.0.0)
    ├── 01_system_dnf.sh        # DNF upgrade, autoremove, clean
    ├── 02_flatpak.sh           # Flatpak updates + static-delta fallback + unused cleanup
    ├── 03_firmware.sh          # LVFS firmware updates
    ├── 04_ai_runtimes.sh       # Claude Code, LM Studio, Ollama & installed models
    ├── 05_dev_toolchains.sh    # SDKMAN!, gcloud, VS Code extensions, Agent skills
    ├── 06_git_docs.sh          # Local Git doc repos & Hermes framework
    └── 07_cleanup.sh           # Docker image prune, journalctl vacuum, optional fstrim
```

---

## 🚀 Setting Up a New Computer

### Scenario A: Syncthing is Already Connected (Standard Flow)
Because Syncthing automatically replicates `~/projects/` across all your nodes, the repository will already exist on your new computer at `~/projects/update/fedora-update`.

1. Run the 1-step installer:
   ```bash
   ~/projects/update/fedora-update/install.sh
   ```
   *(Or simply run `~/projects/update/fedora-update/update` once—it will self-register the symlinks into `~/.local/bin/` automatically!)*

2. From then on, simply type:
   ```bash
   update
   ```

---

### Scenario B: Brand New Computer (Before Syncthing is Set Up)
If setting up a fresh Fedora installation or a clean VM before Syncthing has synced:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jaygz316/fedora-update.git ~/projects/update/fedora-update
   ```

2. **Run the 1-step installer:**
   ```bash
   ~/projects/update/fedora-update/install.sh
   ```
   *This automatically registers `update` in `~/.local/bin`, installs **Syncthing**, configures its Web UI to listen on `0.0.0.0:8384` across your LAN, and activates its systemd user service.*

3. **Run your first update:**
   ```bash
   update
   ```
   *The first run will prompt for your sudo password once to configure passwordless sudo & Polkit, then bootstrap all Core Fleet Baseline tools (compilers, Docker, Android SDK/Studio, Antigravity Desktop/IDE, uv, pip, Python CLI tools).*

---

## 🛠️ Usage

- **Routine Daily Maintenance:**
  ```bash
  update
  ```

- **Deep Maintenance (Including SSD TRIM):**
  ```bash
  update-all
  ```

- **Targeted Single Module Update:**
  ```bash
  fedora-update --only=core
  fedora-update --only=dnf
  fedora-update --only=flatpak
  fedora-update --only=firmware
  fedora-update --only=git
  ```

Logs are preserved in `~/.local/state/update/last-update.log` and archived chronologically (retaining the last 10 runs).
