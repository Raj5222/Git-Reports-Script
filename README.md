# 📘 Git Records v2.0 (Multi-Platform CLI & Workflow Suite)

`git-record` is a **high-performance, cross-platform Git branch manager, interactive workflow CLI, and analytics tool** designed for modern developers across **Ubuntu/Linux, macOS, and Windows**.

It works seamlessly from **any directory** inside any Git repository.

---

## 💻 Multi-OS & Platform Support

| Operating System | Compatibility | Clipboard Engine | Date/Time Engine |
|---|---|---|---|
| 🐧 **Ubuntu / Debian / Linux** | ✅ Fully supported (x86_64, aarch64, arm64) | `wl-copy` (Wayland), `xclip`, `xsel` | GNU Coreutils |
| 🍎 **macOS (Darwin)** | ✅ Fully supported (Apple Silicon M1/M2/M3/M4 & Intel) | `pbcopy` | BSD Coreutils |
| 🪟 **Windows** | ✅ Fully supported (Git Bash, MSYS2, MinGW64, WSL 1/2) | `clip.exe`, PowerShell `Set-Clipboard` | MSYS / GNU |
| 🌐 **SSH / Remote Servers** | ✅ Supported across any terminal | `OSC 52` ANSI Terminal Escape | Automatic Epoch Fallback |

---

## ✨ Key Features & Highlights

- ⚡ **Ultra-Fast Engine**: Pure Bash parameter parsing and single-pass queries; loads 1,000+ branches instantly without lag.
- 🎨 **Modern Responsive UI**: Dynamic terminal width detection, 256-color gradient themes, Unicode box drawing, and automatic ASCII fallback.
- 🛡️ **Built-In Safety Protections**: Protected branch deletion warnings (`main`, `master`, `production`), unmerged commit checks, and working tree validation.
- 📦 **Pixel-Perfect Error Boxes**: Clear, non-intrusive error summaries with helpful hints and copy-pasteable examples.
- 🎮 **Interactive Selector (FZF & TUI)**: Fuzzy search branches, live diff preview pane, and single-key actions (`Enter` to checkout, `Ctrl-S` to inspect, `Ctrl-D` to delete).
- 🔍 **Conflict Prediction & Divergence**: Identifies merge conflicts and file collisions in advance before merging.
- 📊 **Team Velocity & Health**: 30-day commit velocity sparklines, contributor volume distributions, and daily activity trends.
- 🦊 **CI/CD Integration**: GitHub Actions and GitLab CI status checks via native CLI (`gh`/`glab`) or REST APIs with real-time live monitoring.
- 🩺 **System Diagnostics (`--sys-info`)**: Built-in environment inspector showing detected OS, architecture, clipboard tools, and optional dependencies.

---

## 📦 Quick Installation

### One-line automatic install (Ubuntu, macOS, Windows Git Bash):
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/install.sh)
```

### User-space install (No sudo required):
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/raj5222/Git-Reports-Script/main/install.sh) --user
```

### Manual installation from repository:
```bash
# Ubuntu / Linux / macOS
sudo cp git-records.sh /usr/local/bin/git-record
sudo chmod +x /usr/local/bin/git-record

# Windows (Git Bash / MSYS2)
cp git-records.sh /usr/bin/git-record
chmod +x /usr/bin/git-record
```

### Verify installation & environment:
```bash
git-record --version
git-record --sys-info
```

---

## 🚀 Usage & Quick Start

### 1. View Branch Table
```bash
git-record          # Show top 10 recent branches
git-record 25       # Show top 25 branches
git-record -a       # Show all branches
git-record -l       # Show local branches only
git-record -r       # Show remote branches only
git-record -f api   # Filter branches matching 'api'
```

### 2. Output Example
```text
  📦 GIT-REPORTS-SCRIPT   🌿 main   ✨ clean
  Local: 4   Remote: 28   Total Shown: 10/32

  ┌──────┬────────┬────────────────────────────────┬───────┬──────────┬───────────────┬──────────────┐
  │  NO  │  TYPE  │ BRANCH NAME                    │ SYNC  │  COMMIT  │ LAST UPDATED  │ AUTHOR       │
  ├──────┼────────┼────────────────────────────────┼───────┼──────────┼───────────────┼──────────────┤
  │  1   │ LOCAL  │ ➜ feature/new-api              │  ↑2   │ 7f8a91c  │ 2 hours ago   │ Alex Chen    │
  │  2   │ REMOTE │ origin/feature/new-api         │   ✔   │ 7f8a91c  │ 2 hours ago   │ Alex Chen    │
  │  3   │ REMOTE │ origin/develop                 │  ↓4   │ c968167  │ 1 day ago     │ Sarah Jenkins│
  │  4   │ LOCAL  │ develop                        │   ✔   │ 0a5bafc  │ 3 days ago    │ Sarah Jenkins│
  └──────┴────────┴────────────────────────────────┴───────┴──────────┴───────────────┴──────────────┘

  🚀 QUICK WORKFLOW ACTIONS
  🌿 WORKFLOW                 🔍 INSPECT                  📊 ANALYTICS & CI         
  git-record -c <ID>  (Checkout)  git-record -s <ID>  (Show)    git-record -X <ID>  (Stats) 
  git-record -m <ID>  (Merge)   git-record -C <A:B> (Compare)  git-record -V       (Velocity)
  git-record -d <ID>  (Delete)  git-record -M <ID>  (Conflicts)  git-record -G       (Graph) 
  git-record -b <IDs> (Bulk Del)  git-record -k <ID>  (Copy Hash)  git-record -N <ID>  (CI Status)
```

---

## 🛠️ Complete Command Reference

| Flag | Long Flag | Description | Example |
|---|---|---|---|
| `-c <ID>` | `--checkout <ID>` | Checkout branch (auto-tracks remote branches) | `git-record -c 3` |
| `-m <ID>` | `--merge <ID>` | Merge branch into current branch with checks | `git-record -m 2` |
| `-d <ID>` | `--delete <ID>` | Safely delete local branch | `git-record -d 4` |
| `-D <ID>` | `--force-delete <ID>` | Force delete local branch | `git-record -D 4` |
| `-b <IDs>` | `--bulk-delete <IDs>` | Bulk delete multiple branches | `git-record -b 2,4,5` |
| `-R <ID>` | `--rename <ID> [name]` | Rename local branch safely | `git-record -R 1 new-name` |
| `-k <ID>` | `--copy <ID>` | Copy commit hash to clipboard (Wayland/X11/macOS/Windows) | `git-record -k 1` |
| `-s <ID>` | `--show <ID>` | Show commit details and diffstat | `git-record -s 2` |
| `-X <ID>` | `--stats <ID>` | Deep branch metrics (churn, files, authors) | `git-record -X 3` |
| `-C <A:B>` | `--compare <A:B>` | Two-way branch comparison | `git-record -C 1:3` |
| `-M <ID>` | `--conflicts <ID>` | Predict merge conflicts before merging | `git-record -M 2` |
| `-V [days]` | `--velocity [days]` | Team commit velocity dashboard | `git-record -V 30` |
| `-G` | `--graph` | Branch divergence & topology graph | `git-record -G` |
| `-A` | `--cleanup` | Smart cleanup auditor for merged & stale branches | `git-record -A` |
| `-T [N]` | `--tags [N]` | List repository tags and releases | `git-record -T 10` |
| `-L` | `--stash` | View stashed changes stack | `git-record -L` |
| `-H [N]` | `--history [N]` | Formatted direct commit history log | `git-record -H 20` |
| `-S <code\>` | `--search <code>` | Search code content across all branches | `git-record -S "func"` |
| `-W` | `--worktrees` | List active Git worktrees | `git-record -W` |
| `-i` | `--interactive` | Launch interactive TUI / FZF branch selector | `git-record -i` |
| `-N <ID>` | `--ci <ID>` | Inspect GitHub / GitLab CI/CD pipeline | `git-record -N 1` |
| `--watch-ci <ID>` | `--watch-ci <ID> [sec]` | Real-time live CI/CD monitoring dashboard | `git-record --watch-ci 1 5` |
| `--sys-info` | `--doctor`, `--info` | Environment & platform diagnostics | `git-record --sys-info` |
| `--no-color` | `--no-color` | Disable colored terminal output | `git-record --no-color` |
| `-v` | `--version` | Display version and platform information | `git-record -v` |
| `-h` | `--help` | Display manual and help text | `git-record -h` |

---

## ❌ Professional Error Handling

Clear, formatted error boxes with suggested hints and copy-pasteable examples:

```text
  ┌─ ERROR ───────────────────────────────────────────────┐
  │ Message : Branch ID out of range: 999                 │
  │ Hint    : Select an ID between 1 and 10               │
  │ Example : git-record -c 1                             │
  └───────────────────────────────────────────────────────┘
```

---

## 🔒 Configuration (`~/.gitrecordrc`)

You can customize default settings globally in `~/.gitrecordrc` or per-repository in `.gitrecord`:

```bash
# ~/.gitrecordrc
DEFAULT_LIMIT=15          # Default number of branches to show
STALE_DAYS=60             # Highlight branches older than 60 days
CLEANUP_THRESHOLD=45      # Flag branches inactive for >45 days
COLOR_MODE="auto"         # auto | always | never
USE_UNICODE=1             # 1 for Unicode borders, 0 for ASCII
```

---

## 📄 License & Notes

- **License**: MIT
- **Platforms**: Ubuntu / Debian / Fedora / Arch Linux, macOS (Apple Silicon & Intel), Windows (Git Bash / MSYS2 / WSL).
- **Dependencies**: Native Bash & Git (Optional: `fzf` for fuzzy selector, `jq` for API CI parsing, `gh`/`glab` for native CI inspection, `wl-copy`/`xclip`/`pbcopy`/`clip.exe` for clipboard).
