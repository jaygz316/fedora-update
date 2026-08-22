# Fedora Update (`fedora-update`)

A modular, standalone system update and maintenance automation suite tailored for **Fedora Linux** power users and developers.

It unifies OS packages, Flatpaks, developer toolchains, AI runtimes, CLI utilities, local documentation repositories, and system cleanup into a single streamlined command.

---

## ⚡ Key Features

- **Package Managers & System**:
  - Refreshes repositories and upgrades DNF packages (`dnf upgrade --refresh`, `dnf autoremove`, `dnf clean packages`).
  - Updates Flatpaks with automatic fallback for Flathub delta decompression limits (`--no-static-deltas`) and prunes orphaned runtimes.
  - Checks hardware & system firmware via LVFS (`fwupdmgr`).
- **Developer & AI Toolchains**:
  - **AI Engines & CLI Agents**: Google Antigravity Desktop & IDE, Agy CLI (`agy`), Claude Code (`claude`), Herdr CLI (`herdr`), Ollama runtime & models (`ollama`), and agent skills.
  - **Runtimes & Package Managers**: Astral `uv` & tools, `bun`, global `npm` packages, Go tooling (`gopls`, `dlv`), and user `pip` CLI tools.
  - **SDKs & Editors**: Android SDK (`android`), Visual Studio Code extensions, Micro editor plugins, and GitHub CLI extensions (`gh`).
- **Documentation & Git Repositories**:
  - Safely fetches and syncs local Git repositories and documentation frameworks with upstream (`git pull --rebase --autostash`).
- **System Maintenance & Cleanup**:
  - Prunes dangling Docker images (`docker image prune -f`).
  - Vacuums old systemd journal logs (`journalctl --vacuum-time=14d --vacuum-size=500M`).
  - **`update-all` only:** Executes full SSD TRIM (`fstrim -av`).
- **Post-Update Intelligence**:
  - Checks if a kernel, glibc, or systemd reboot is required (`dnf needs-restarting -r`).
  - Lists active background services requiring restarts (`dnf needs-restarting -s`).
- **Logging**:
  - Full execution output is automatically mirrored to terminal and logged under `~/.local/state/update/`.

---

## 📦 Scripts Included

| Script | Purpose |
| :--- | :--- |
| **`update`** | **Fast routine maintenance.** Runs all package and toolchain updates, Docker prune, and journal log vacuuming. |
| **`update-all`** | **Complete deep maintenance.** Includes everything in `update` plus full storage hardware maintenance (SSD `fstrim`). |

---

## 🚀 Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jaygz316/fedora-update.git ~/projects/update/fedora
   ```

2. **Install scripts into your user path:**
   ```bash
   mkdir -p ~/.local/bin
   cp ~/projects/update/fedora/update ~/.local/bin/
   cp ~/projects/update/fedora/update-all ~/.local/bin/
   chmod +x ~/.local/bin/update ~/.local/bin/update-all
   ```

3. **Ensure `~/.local/bin` is in your `PATH`:**
   ```bash
   export PATH="$HOME/.local/bin:$PATH"
   ```

4. **(Optional) Configure passwordless `sudo`:**
   To run unattended without interactive sudo prompts, configure a sudoers drop-in file:
   ```bash
   echo "$USER ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$USER
   sudo chmod 0440 /etc/sudoers.d/$USER
   ```

---

## 🛠️ Usage

Simply run:
```bash
update
```

Or for complete maintenance including SSD trim:
```bash
update-all
```

Logs are preserved in `~/.local/state/update/last-update.log` and archived chronologically (retaining the last 10 runs).
