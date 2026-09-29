# fedora-update

A single-file, 1-click maintenance and toolchain sync suite for a fleet of Fedora machines.

## How It Works

Everything lives in **one script** — [`update`](./update). There's nothing to source, no module directories, no loading order to debug. Add a new tool? Open `update`, find the right section, add a block.

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
update --force, -f                 # Safely close running apps for updates, then restart them
update --dry-run, -n               # Preview all steps, no system changes
update --only=core                 # Run only one section
update --skip=dnf,flatpak          # Skip sections (comma-separated)
update --skip=dnf --skip=flatpak   # Skip sections (repeated flag)
update --trim                      # Include SSD TRIM step
```

### Section Keys (for `--only=` / `--skip=`)

| Key       | What it does |
| :-------- | :--- |
| `core`    | Installs/updates all baseline tools on every node (Node.js, npm, pip, uv, Rust, Bun, Go, Docker, Android SDK, Antigravity, Agy, Herdr, Syncthing) |
| `dnf`     | DNF system upgrade, autoremove, cache clean |
| `flatpak` | Flatpak app + runtime updates, prune unused |
| `firmware`| LVFS hardware firmware checks (fwupdmgr) |
| `ai`      | Claude Code, LM Studio, Ollama + installed models |
| `dev`     | SDKMAN!, gcloud, VS Code extensions, Agent Skills |
| `git`     | git pull on docs repos and Hermes agent framework |
| `self`    | git pull on this fedora-update repo itself |
| `cleanup` | Docker prune, caches, journal vacuum, reboot check |

## Files

```
fedora-update/
├── update      ← everything is here (~970 lines, well-sectioned)
├── update-all  ← 4-line wrapper: exec update --trim
├── install.sh  ← first-time symlink + Syncthing bootstrap
├── AGENTS.md   ← agent operating manual
└── README.md
```

## Adding a New Tool

Open [`update`](./update), find the appropriate `### SECTION` block (or add one), and add your steps there. No sourcing, no module files, no loading order. `grep -n "tool_name" update` finds anything instantly.

## Logs

Every run is saved to `~/.local/state/update/last-update.log` and archived as `update_YYYYMMDD_HHMMSS.log` (last 10 kept).
