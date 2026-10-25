# fedora-update

A modular, recipe-based 1-click maintenance and toolchain sync suite for a fleet of Fedora machines. Designed for high efficiency, complete fault isolation, and seamless pair programming with AI agents.

## How It Works

* **Core Orchestrator (`update`)**: Lightweight CLI dispatcher (~380 lines) handling argument parsing, logging, passwordless sudo, process shutdown/restart, and dynamic recipe discovery.
* **Isolated Tool Recipes (`recipes.d/`)**: Every toolchain, runtime, and cleanup task lives in its own small, single-purpose recipe file (~10–40 lines).
* **Fault Isolation**: Each recipe is verified with `bash -n` at runtime before execution. A syntax error in one tool will safely skip without aborting the rest of the system update.
* **Zero Blast Radius**: To add or edit a tool, an AI or human only touches that tool's recipe. No manual step math to desync (`TOTAL_STEPS` is counted dynamically).
* **Verification Gate (`./test`)**: A 1-second automated syntax and dry-run check to verify the entire suite before committing changes.

The project is synced across all machines via **Syncthing** (`~/projects/` and `~/.gemini`).

## Quickstart

```bash
# Clone to a new Fedora machine (before Syncthing is running)
git clone https://github.com/jaygz316/fedora-update ~/projects/update/fedora-update
bash ~/projects/update/fedora-update/install.sh

# Then just run:
update
```

## Usage

```bash
update              # Full run: core → dnf → flatpak → firmware → ai → dev → git → self → cleanup
update-all          # Same + SSD TRIM (fstrim -av)
```

### Options

```bash
update --app, -a                   # Interactive terminal menu to force-update specific app(s)
update --app rustdesk              # Immediately force-update only RustDesk (or comma-separated list)
update --force, -f                 # Safely close all running apps for updates, then restart them
update --force=rustdesk,vscode     # Full update run, but only force-restart specified app(s)
update --dry-run, -n               # Preview all steps, no system changes
update --only=core                 # Run only one section
update --skip=dnf,flatpak          # Skip sections (comma-separated)
update --skip=dnf --skip=flatpak   # Skip sections (repeated flag)
update --trim                      # Include SSD TRIM step
```

### Section Keys (for `--only=` / `--skip=`)

| Key       | What it does | Recipe Directory |
| :-------- | :--- | :--- |
| `core`    | Baseline tools on every node (Node.js, npm, pip, uv, Rust, Bun, Go, Docker, Android SDK, Studio, Antigravity, Agy, Herdr, Syncthing, RustDesk, OpenLogi) | `recipes.d/core/` |
| `dnf`     | DNF system upgrade, autoremove, cache clean | `recipes.d/dnf/` |
| `flatpak` | Flatpak app + runtime updates, prune unused | `recipes.d/flatpak/` |
| `firmware`| LVFS hardware firmware checks (fwupdmgr) | `recipes.d/firmware/` |
| `ai`      | Claude Code, LM Studio, Ollama + installed models, NV Broadcast | `recipes.d/ai/` |
| `dev`     | SDKMAN!, gcloud, VS Code extensions, Agent Skills | `recipes.d/dev/` |
| `git`     | git pull on docs repos and Hermes agent framework | `recipes.d/git/` |
| `self`    | git pull on this fedora-update repo itself | `recipes.d/self/` |
| `cleanup` | Docker prune, caches, journal vacuum, reboot check | `recipes.d/cleanup/` |

## Project Structure

```
fedora-update/
├── update                 # Core runner & lifecycle engine
├── update-all             # 4-line wrapper: exec update --trim "$@"
├── install.sh             # Bootstrap symlinks, permissions & Syncthing
├── test                   # Automated verification gate (bash -n, py_compile, dry-run)
├── helpers/               # Standalone polyglot scripts
│   ├── android_canary.py  # Android Studio Canary metadata resolver
│   └── asar_icon.py       # Electron asar icon extractor
├── recipes.d/             # Isolated tool recipes by category
│   ├── core/              # Baseline fleet tools
│   ├── dnf/               # DNF upgrades & cleanups
│   ├── flatpak/           # Flatpak applications & runtimes
│   ├── firmware/          # Hardware firmware checks
│   ├── ai/                # AI agents & LLM runtimes
│   ├── dev/               # Developer SDKs & extensions
│   ├── git/               # Parallel git documentation sync
│   ├── self/              # Self-update logic
│   └── cleanup/           # Docker, caches & journal vacuum
├── AGENTS.md              # Agent operating manual
└── README.md
```

## Adding a New Tool

1. Decide the appropriate category directory in `recipes.d/` (e.g. `recipes.d/core/` or `recipes.d/dev/`).
2. Add a new `.sh` file (e.g. `recipes.d/core/20-zig.sh`).
3. Call `step "Core: Zig Compiler"` and implement your check/install logic.
4. Run `./test` to verify syntax and dry-run execution.
5. That's it! `TOTAL_STEPS` and module filtering auto-detect the new file.

## Logs

Every run is saved to `~/.local/state/update/last-update.log` and archived as `update_YYYYMMDD_HHMMSS.log` (last 10 kept).
