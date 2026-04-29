#!/usr/bin/env bash
set -euo pipefail

# palimpsest — installer
# Sets up the vault and installs slash commands globally for Claude Code
# and/or GitHub Copilot (VS Code). Both targets share the same vault.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Output helpers ──────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$*"; }
err()  { printf "${RED}✗${NC} %s\n" "$*" >&2; }
hdr()  { printf "\n${BOLD}%s${NC}\n" "$*"; }

# ── Flags ───────────────────────────────────────────────────────────────
DRY_RUN=0
REINSTALL=0
CLI_VAULT_PATH=""
CLI_TARGET=""

usage() {
  cat <<USAGE
palimpsest installer

Usage: ./install.sh [OPTIONS]

Options:
  --vault-path PATH     Skip interactive vault selection; install to PATH
  --target TARGET       Skip interactive target selection.
                        TARGET ∈ {claude, copilot, both}
  --dry-run             Print actions, write nothing
  --reinstall           Force backup-and-rewrite of all kit-owned files
  -h, --help            Show this message
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --vault-path)   CLI_VAULT_PATH="${2:-}"; shift 2 ;;
    --vault-path=*) CLI_VAULT_PATH="${1#*=}"; shift ;;
    --target)       CLI_TARGET="${2:-}"; shift 2 ;;
    --target=*)     CLI_TARGET="${1#*=}"; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --reinstall)    REINSTALL=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              err "Unknown flag: $1"; usage; exit 1 ;;
  esac
done

# do() runs a command unless --dry-run, in which case it prints it
run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf "  [dry-run] %s\n" "$*"
  else
    eval "$@"
  fi
}

# ── Banner ──────────────────────────────────────────────────────────────
cat <<'BANNER'

  palimpsest
  A persistent memory layer for Claude Code & GitHub Copilot, built on Obsidian

BANNER
[ "$DRY_RUN" -eq 1 ] && warn "DRY RUN — no files will be written"
[ "$REINSTALL" -eq 1 ] && warn "REINSTALL — kit-owned files will be backed up and rewritten"

# ── Target selection ────────────────────────────────────────────────────
hdr "Setup target"

resolve_target() {
  if [ -n "$CLI_TARGET" ]; then
    case "$CLI_TARGET" in
      claude|copilot|both) TARGET="$CLI_TARGET" ;;
      *) err "Invalid --target: $CLI_TARGET (expected: claude | copilot | both)"; exit 1 ;;
    esac
    ok "Using --target: $TARGET"
    return
  fi

  printf "Where should palimpsest be installed?\n"
  printf "  [1] Claude Code only\n"
  printf "  [2] GitHub Copilot (VS Code) only\n"
  printf "  [3] Both\n\n"
  read -rp "Pick [1-3] (default 3): " choice
  case "${choice:-3}" in
    1) TARGET="claude" ;;
    2) TARGET="copilot" ;;
    3|"") TARGET="both" ;;
    *) err "Invalid choice: $choice"; exit 1 ;;
  esac
  ok "Target: $TARGET"
}

resolve_target

want_claude()  { [ "$TARGET" = "claude" ]  || [ "$TARGET" = "both" ]; }
want_copilot() { [ "$TARGET" = "copilot" ] || [ "$TARGET" = "both" ]; }

# ── Prereqs ─────────────────────────────────────────────────────────────
hdr "Checking prerequisites"
[ "$(uname)" = "Darwin" ] || { err "macOS only for v1 (detected: $(uname))"; exit 1; }
ok "macOS"
command -v python3 >/dev/null || { err "python3 required (preinstalled on macOS — install from python.org otherwise)"; exit 1; }
ok "python3"

if [ ! -d "$REPO_DIR/templates" ]; then
  err "Templates directory missing. Are you running this from inside the cloned repo?"
  exit 1
fi
ok "Templates found at $REPO_DIR/templates"

if want_claude; then
  if [ ! -d "$HOME/.claude" ]; then
    err "~/.claude/ doesn't exist — run 'claude' once to initialize Claude Code, then re-run this installer (or use --target=copilot)."
    exit 1
  fi
  ok "~/.claude/ exists"
fi

if want_copilot; then
  if [ -d "/Applications/Visual Studio Code.app" ] || command -v code >/dev/null 2>&1; then
    ok "VS Code detected"
  else
    warn "VS Code not detected — install it from https://code.visualstudio.com/ (or 'brew install --cask visual-studio-code')"
    warn "Continuing anyway — files will be in place when VS Code is installed."
  fi
fi

# ── Vault path ──────────────────────────────────────────────────────────
hdr "Vault location"

OBSIDIAN_JSON="$HOME/Library/Application Support/obsidian/obsidian.json"
ICLOUD_PARENT="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
LOCAL_DEFAULT="$HOME/Documents/palimpsest"

resolve_vault_path() {
  if [ -n "$CLI_VAULT_PATH" ]; then
    VAULT_PATH="${CLI_VAULT_PATH/#\~/$HOME}"
    ok "Using --vault-path: $VAULT_PATH"
    return
  fi

  # Auto-detect existing Obsidian vaults via obsidian.json
  local detected=""
  if [ -f "$OBSIDIAN_JSON" ]; then
    detected=$(python3 -c "
import json, sys
try:
    d = json.load(open('$OBSIDIAN_JSON'))
    for v in d.get('vaults', {}).values():
        print(v.get('path', ''))
except Exception:
    pass
" 2>/dev/null || true)
  fi

  if [ -n "$detected" ]; then
    printf "Detected existing Obsidian vault(s):\n"
    local i=1
    local -a paths
    while IFS= read -r p; do
      [ -n "$p" ] && { printf "  %d) %s\n" "$i" "$p"; paths[$i]="$p"; i=$((i+1)); }
    done <<< "$detected"
    printf "  %d) Create a new vault at a custom path\n\n" "$i"
    read -rp "Pick [1-$i]: " choice
    if [ "$choice" = "$i" ] || [ -z "$choice" ]; then
      read -rp "Custom vault path: " VAULT_PATH
    else
      local obsidian_root="${paths[$choice]}"
      [ -z "$obsidian_root" ] && { err "Invalid choice"; exit 1; }
      printf "Install palimpsest inside this vault as a subfolder?\n  [memory] (Enter to accept)\n"
      read -rp "Subfolder (leave empty for vault root): " subfolder
      subfolder="${subfolder:-memory}"
      if [ -z "$subfolder" ]; then
        VAULT_PATH="$obsidian_root"
      else
        VAULT_PATH="$obsidian_root/$subfolder"
      fi
    fi
  elif [ -d "$ICLOUD_PARENT" ]; then
    DEFAULT_VAULT="$ICLOUD_PARENT/memory"
    printf "Detected iCloud Obsidian sync. Recommended location:\n  %s\n\n" "$DEFAULT_VAULT"
    read -rp "Vault path (Enter to accept default): " INPUT_PATH
    VAULT_PATH="${INPUT_PATH:-$DEFAULT_VAULT}"
  else
    DEFAULT_VAULT="$LOCAL_DEFAULT"
    printf "No iCloud Obsidian sync detected. Recommended location:\n  %s\n\n" "$DEFAULT_VAULT"
    read -rp "Vault path (Enter to accept default): " INPUT_PATH
    VAULT_PATH="${INPUT_PATH:-$DEFAULT_VAULT}"
  fi
  VAULT_PATH="${VAULT_PATH/#\~/$HOME}"
}

resolve_vault_path
ok "Using vault path: $VAULT_PATH"

INIT_DATE="$(date '+%Y-%m-%d')"
INIT_TIME="$(date '+%H:%M')"

# render() pipes a template through sed substitutions to stdout
render() {
  sed -e "s|{{VAULT_PATH}}|$VAULT_PATH|g" \
      -e "s|{{INIT_DATE}}|$INIT_DATE|g" \
      -e "s|{{INIT_TIME}}|$INIT_TIME|g" \
      "$1"
}

# backup_if_needed FILE [SUBDIR] — moves FILE to ~/.claude/backups/palimpsest/<ts>/[SUBDIR/]...
BACKUP_TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$HOME/.claude/backups/palimpsest/$BACKUP_TS"
backup_if_needed() {
  local target="$1"
  local subdir="${2:-}"
  [ -f "$target" ] || return 0
  local rel="${target#$HOME/}"
  local dest
  if [ -n "$subdir" ]; then
    dest="$BACKUP_ROOT/$subdir/$rel"
  else
    dest="$BACKUP_ROOT/$rel"
  fi
  run "mkdir -p \"$(dirname "$dest")\""
  run "cp \"$target\" \"$dest\""
  warn "Backed up: $target → $dest"
}

# ── Confirmation ────────────────────────────────────────────────────────
hdr "Summary — about to install"
printf "  Vault path:       %s\n" "$VAULT_PATH"
printf "  Target:           %s\n" "$TARGET"
if want_claude; then
  printf "  Claude skills:    %s/.claude/commands/  (6 files)\n" "$HOME"
  printf "  Claude config:    %s/.claude/CLAUDE.md  (append if marker absent)\n" "$HOME"
  printf "  Claude perms:     %s/.claude/settings.json  (Read/Edit/Write on vault)\n" "$HOME"
fi
if want_copilot; then
  printf "  Copilot prompts:  %s/.copilot/prompts/  (6 files)\n" "$HOME"
  printf "  Copilot config:   %s/.copilot/instructions/palimpsest.instructions.md\n" "$HOME"
  printf "  VS Code settings: %s/Library/Application Support/Code/User/settings.json (chat.{prompt,instructions}FilesLocations)\n" "$HOME"
fi
printf "  Backups (if any): %s/\n\n" "$BACKUP_ROOT"
read -rp "Proceed? [y/N] " confirm
[[ "$confirm" =~ ^[Yy] ]] || { warn "Aborted by user"; exit 0; }

# ── Vault structure (shared, agent-agnostic) ────────────────────────────
hdr "Creating vault structure"
run "mkdir -p \"$VAULT_PATH/raw/clippings\" \"$VAULT_PATH/raw/docs\" \"$VAULT_PATH/raw/notes\" \"$VAULT_PATH/sessions\" \"$VAULT_PATH/wiki/Context\" \"$VAULT_PATH/wiki/Intelligence\" \"$VAULT_PATH/wiki/Resources\""
ok "Folders created"

# Migration: legacy layout placed Daily/ inside wiki/.
LEGACY_DAILY="$VAULT_PATH/wiki/Daily"
if [ -d "$LEGACY_DAILY" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] migrate $LEGACY_DAILY/* → $VAULT_PATH/sessions/ then rmdir"
  else
    shopt -s nullglob
    moved=0
    for f in "$LEGACY_DAILY"/*; do
      mv "$f" "$VAULT_PATH/sessions/"
      moved=$((moved + 1))
    done
    shopt -u nullglob
    rmdir "$LEGACY_DAILY" 2>/dev/null || true
    [ "$moved" -gt 0 ] && warn "Migrated $moved legacy daily file(s) → sessions/"
  fi
fi

# ── Seed wiki files ─────────────────────────────────────────────────────
if [ ! -f "$VAULT_PATH/wiki/index.md" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] write $VAULT_PATH/wiki/index.md (with substitutions)"
  else
    render "$REPO_DIR/templates/vault/wiki/index.md" > "$VAULT_PATH/wiki/index.md"
  fi
  ok "Seeded wiki/index.md"
else
  warn "wiki/index.md already exists — left as-is (User-owned)"
fi

LEGACY_LOG="$VAULT_PATH/wiki/log.md"
if [ -f "$LEGACY_LOG" ] && [ ! -f "$VAULT_PATH/log.md" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] migrate $LEGACY_LOG → $VAULT_PATH/log.md"
  else
    mv "$LEGACY_LOG" "$VAULT_PATH/log.md"
  fi
  warn "Migrated wiki/log.md → log.md (vault root)"
fi

if [ ! -f "$VAULT_PATH/log.md" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] write $VAULT_PATH/log.md (with substitutions)"
  else
    render "$REPO_DIR/templates/vault/log.md" > "$VAULT_PATH/log.md"
  fi
  ok "Seeded log.md"
else
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] append re-init entry to $VAULT_PATH/log.md"
  else
    printf "%s %s — Init: palimpsest re-run (paths refreshed)\n" "$INIT_DATE" "$INIT_TIME" >> "$VAULT_PATH/log.md"
  fi
  warn "log.md exists — appended re-init entry"
fi

# ── install_claude() ────────────────────────────────────────────────────
install_claude() {
  hdr "Installing Claude Code skills"
  run "mkdir -p \"$HOME/.claude/commands\""

  CLAUDE_SKILL_COUNT=0
  CLAUDE_SKIPPED=0
  for f in "$REPO_DIR/templates/skills/"*.md; do
    name=$(basename "$f")
    target="$HOME/.claude/commands/$name"
    rendered=$(render "$f")

    if [ -f "$target" ]; then
      existing=$(cat "$target")
      if [ "$rendered" = "$existing" ] && [ "$REINSTALL" -eq 0 ]; then
        CLAUDE_SKIPPED=$((CLAUDE_SKIPPED + 1))
        continue
      fi
      backup_if_needed "$target"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [dry-run] write $target"
    else
      printf '%s' "$rendered" > "$target"
    fi
    CLAUDE_SKILL_COUNT=$((CLAUDE_SKILL_COUNT + 1))
  done
  ok "Installed/updated $CLAUDE_SKILL_COUNT skill(s); skipped $CLAUDE_SKIPPED already-current"

  # Migration: /compile was merged into /ingest.
  LEGACY_COMPILE="$HOME/.claude/commands/compile.md"
  if [ -f "$LEGACY_COMPILE" ]; then
    backup_if_needed "$LEGACY_COMPILE"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [dry-run] remove legacy $LEGACY_COMPILE"
    else
      rm "$LEGACY_COMPILE"
    fi
    warn "Removed legacy /compile skill (now merged into /ingest)"
  fi

  # ── Global CLAUDE.md ──────────────────────────────────────────────────
  hdr "Configuring global CLAUDE.md"
  GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
  RENDERED_CLAUDE=$(render "$REPO_DIR/templates/CLAUDE.md")

  if [ -f "$GLOBAL_CLAUDE" ]; then
    if grep -qE "^## (palimpsest|Second Brain vault)$" "$GLOBAL_CLAUDE"; then
      if [ "$REINSTALL" -eq 1 ]; then
        backup_if_needed "$GLOBAL_CLAUDE"
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "  [dry-run] strip existing palimpsest/Second Brain section from $GLOBAL_CLAUDE and re-append"
        else
          awk '/^## palimpsest$/{exit} /^## Second Brain vault$/{exit} {print}' "$GLOBAL_CLAUDE" > "${GLOBAL_CLAUDE}.tmp"
          awk 'BEGIN{blank=0} /^$/{blank++; next} {while(blank--){print ""}; blank=0; print}' "${GLOBAL_CLAUDE}.tmp" > "$GLOBAL_CLAUDE"
          rm "${GLOBAL_CLAUDE}.tmp"
          printf "\n\n" >> "$GLOBAL_CLAUDE"
          printf '%s\n' "$RENDERED_CLAUDE" >> "$GLOBAL_CLAUDE"
        fi
        ok "Re-installed palimpsest section in ~/.claude/CLAUDE.md"
      else
        warn "Already references palimpsest (or legacy Second Brain) — leaving unchanged (use --reinstall to refresh)"
      fi
    else
      backup_if_needed "$GLOBAL_CLAUDE"
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] append palimpsest section to $GLOBAL_CLAUDE"
      else
        printf "\n\n" >> "$GLOBAL_CLAUDE"
        printf '%s\n' "$RENDERED_CLAUDE" >> "$GLOBAL_CLAUDE"
      fi
      ok "Appended palimpsest section to ~/.claude/CLAUDE.md"
    fi
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [dry-run] create $GLOBAL_CLAUDE"
    else
      printf '%s\n' "$RENDERED_CLAUDE" > "$GLOBAL_CLAUDE"
    fi
    ok "Created ~/.claude/CLAUDE.md"
  fi

  # ── Settings.json permissions ─────────────────────────────────────────
  hdr "Updating Claude Code permissions"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] add Read/Edit/Write($VAULT_PATH/**) entries to ~/.claude/settings.json"
  else
    python3 - "$VAULT_PATH" <<'PYEOF'
import json
import sys
from pathlib import Path

vault = sys.argv[1]
settings_file = Path.home() / ".claude" / "settings.json"

if settings_file.exists():
    settings = json.loads(settings_file.read_text())
else:
    settings = {}

settings.setdefault("permissions", {}).setdefault("allow", [])
allow = settings["permissions"]["allow"]

added = 0
for tool in ("Read", "Edit", "Write"):
    perm = f"{tool}({vault}/**)"
    if perm not in allow:
        allow.append(perm)
        added += 1

settings_file.write_text(json.dumps(settings, indent=2) + "\n")
print(f"  {added} new permission entries added")
PYEOF
  fi
  ok "Settings updated"
}

# ── install_copilot() ───────────────────────────────────────────────────
install_copilot() {
  hdr "Installing Copilot prompts & instructions"
  run "mkdir -p \"$HOME/.copilot/prompts\" \"$HOME/.copilot/instructions\""

  COPILOT_FILE_COUNT=0
  COPILOT_SKIPPED=0

  install_one_copilot_file() {
    local src="$1"
    local target="$2"
    local rendered
    rendered=$(render "$src")

    if [ -f "$target" ]; then
      local existing
      existing=$(cat "$target")
      if [ "$rendered" = "$existing" ] && [ "$REINSTALL" -eq 0 ]; then
        COPILOT_SKIPPED=$((COPILOT_SKIPPED + 1))
        return
      fi
      backup_if_needed "$target" "copilot"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [dry-run] write $target"
    else
      printf '%s' "$rendered" > "$target"
    fi
    COPILOT_FILE_COUNT=$((COPILOT_FILE_COUNT + 1))
  }

  # Prompts
  for f in "$REPO_DIR/templates/copilot/prompts/"*.prompt.md; do
    name=$(basename "$f")
    install_one_copilot_file "$f" "$HOME/.copilot/prompts/$name"
  done

  # Instructions
  for f in "$REPO_DIR/templates/copilot/instructions/"*.md; do
    name=$(basename "$f")
    install_one_copilot_file "$f" "$HOME/.copilot/instructions/$name"
  done

  ok "Installed/updated $COPILOT_FILE_COUNT file(s); skipped $COPILOT_SKIPPED already-current"

  # ── VS Code settings.json ─────────────────────────────────────────────
  hdr "Registering palimpsest paths in VS Code settings"
  VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] add ~/.copilot/prompts to chat.promptFilesLocations"
    echo "  [dry-run] add ~/.copilot/instructions to chat.instructionsFilesLocations"
    echo "  [dry-run] target: $VSCODE_SETTINGS"
  else
    if [ -f "$VSCODE_SETTINGS" ]; then
      backup_if_needed "$VSCODE_SETTINGS" "copilot"
    fi
    python3 - "$VSCODE_SETTINGS" "$HOME/.copilot/prompts" "$HOME/.copilot/instructions" <<'PYEOF'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
prompts_dir = sys.argv[2]
instructions_dir = sys.argv[3]

settings_path.parent.mkdir(parents=True, exist_ok=True)

if settings_path.exists():
    raw = settings_path.read_text()
    if not raw.strip():
        settings = {}
    else:
        try:
            settings = json.loads(raw)
        except json.JSONDecodeError as e:
            # VS Code accepts JSONC (comments / trailing commas). Bail safely.
            print("  ! settings.json contains JSONC (comments or trailing commas) — won't auto-edit.")
            print("  ! Add the following entries manually:")
            print()
            print('    "chat.promptFilesLocations": {')
            print(f'      "{prompts_dir}": true')
            print('    },')
            print('    "chat.instructionsFilesLocations": {')
            print(f'      "{instructions_dir}": true')
            print('    }')
            print()
            sys.exit(0)
else:
    settings = {}

added = 0

def patch_locations(key, location):
    global added
    current = settings.get(key)
    # VS Code accepts either a list of paths or an object {path: bool}.
    if isinstance(current, dict):
        if current.get(location) is not True:
            current[location] = True
            settings[key] = current
            added += 1
    elif isinstance(current, list):
        if location not in current:
            current.append(location)
            settings[key] = current
            added += 1
    else:
        settings[key] = {location: True}
        added += 1

patch_locations("chat.promptFilesLocations", prompts_dir)
patch_locations("chat.instructionsFilesLocations", instructions_dir)

settings_path.write_text(json.dumps(settings, indent=2) + "\n")
print(f"  {added} new VS Code settings entries added")
PYEOF
  fi
  ok "VS Code settings updated"
}

# ── Run the selected install(s) ─────────────────────────────────────────
CLAUDE_SKILL_COUNT=0
CLAUDE_SKIPPED=0
COPILOT_FILE_COUNT=0
COPILOT_SKIPPED=0

if want_claude;  then install_claude;  fi
if want_copilot; then install_copilot; fi

# ── Optional: Obsidian ──────────────────────────────────────────────────
hdr "Obsidian"
if [ -d "/Applications/Obsidian.app" ]; then
  ok "Obsidian.app found"
else
  warn "Obsidian not installed at /Applications/Obsidian.app"
  if command -v brew >/dev/null 2>&1; then
    read -rp "Install Obsidian via Homebrew? [y/N] " yn
    if [[ "$yn" =~ ^[Yy] ]]; then
      run "brew install --cask obsidian" && ok "Obsidian installed"
    else
      warn "Skipped — install manually from https://obsidian.md"
    fi
  else
    warn "Homebrew not found. Install Obsidian manually from https://obsidian.md"
  fi
fi

# ── Full Disk Access probe ──────────────────────────────────────────────
# When the vault lives under iCloud Drive (~/Library/Mobile Documents/...),
# macOS TCC requires the *terminal host* (Terminal.app, iTerm2, VS Code, …)
# to have Full Disk Access — otherwise existing files like log.md cannot be
# modified, even though the script can create new files. There's no API to
# grant FDA from a script (TCC DB is SIP-protected); the best we can do is
# detect, explain, and deep-link to the right Settings pane.

hdr "Checking Full Disk Access (vault writability)"

detect_terminal_host() {
  # Walk up the process tree until we hit a known terminal app. The immediate
  # parent is usually the shell (zsh/bash), not the terminal itself. We look
  # for known app names in the ancestry chain (max 8 levels up to be safe).
  local pid="$PPID"
  local raw host i
  for i in 1 2 3 4 5 6 7 8; do
    [ -z "$pid" ] || [ "$pid" = "0" ] || [ "$pid" = "1" ] && break
    raw=$(ps -o comm= -p "$pid" 2>/dev/null)
    host="${raw##*/}"
    case "$host" in
      *"Code Helper"*|"Code"|"Electron")
        echo "Visual Studio Code"; return ;;
      "iTerm2"|"iTerm")
        echo "iTerm"; return ;;
      "Terminal")
        echo "Terminal"; return ;;
      "Hyper"|"WezTerm"|"alacritty"|"kitty"|"warp"|"Warp")
        echo "$host"; return ;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
  done
  echo "your terminal app"
}

probe_vault_write() {
  # Try a no-op append to log.md. If TCC blocks us, this fails with
  # "Operation not permitted" without modifying the file.
  python3 - "$VAULT_PATH/log.md" <<'PYEOF' 2>/dev/null
import sys
from pathlib import Path
p = Path(sys.argv[1])
if not p.exists():
    sys.exit(0)
try:
    with p.open("a") as f:
        pass
    sys.exit(0)
except PermissionError:
    sys.exit(1)
except Exception:
    sys.exit(2)
PYEOF
}

if [ "$DRY_RUN" -eq 1 ]; then
  warn "Skipped FDA probe (dry-run)"
elif [ ! -f "$VAULT_PATH/log.md" ]; then
  warn "Skipped FDA probe (log.md not yet created)"
else
  if probe_vault_write; then
    ok "Vault is writable from this terminal"
  else
    TERMINAL_HOST=$(detect_terminal_host)
    err "Cannot modify $VAULT_PATH/log.md — Full Disk Access is missing."
    cat <<FDA

  Your vault is under iCloud Drive, which macOS protects via TCC.
  Creating new files works, but appending to existing ones (like log.md)
  requires Full Disk Access for the terminal host:

      $TERMINAL_HOST

  Without it, /save and /ingest will fail to update the operations log.

  To grant access:
    1. Open  System Settings → Privacy & Security → Full Disk Access
    2. Enable the toggle for: $TERMINAL_HOST
    3. Quit and relaunch $TERMINAL_HOST (TCC only re-evaluates on launch)

FDA
    read -rp "Open the Full Disk Access settings pane now? [y/N] " yn
    if [[ "$yn" =~ ^[Yy] ]]; then
      # Ventura+ deep-link first; fall back to the legacy URL on older macOS.
      open "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension" 2>/dev/null \
        || open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null \
        || warn "Could not open Settings automatically — navigate there manually."
    fi
    warn "Continuing — install itself is fine. Re-run /save once FDA is granted."
  fi
fi

hdr "Install complete"
printf "\n  Vault:    %s\n" "$VAULT_PATH"
if want_claude; then
  printf "  Claude:   %s/.claude/commands/  (%d installed/updated, %d already current)\n" "$HOME" "$CLAUDE_SKILL_COUNT" "$CLAUDE_SKIPPED"
  printf "            %s/.claude/CLAUDE.md\n" "$HOME"
  printf "            %s/.claude/settings.json\n" "$HOME"
fi
if want_copilot; then
  printf "  Copilot:  %s/.copilot/prompts/  +  %s/.copilot/instructions/\n" "$HOME" "$HOME"
  printf "            (%d installed/updated, %d already current)\n" "$COPILOT_FILE_COUNT" "$COPILOT_SKIPPED"
fi
printf "  Backups:  %s/  (if any files were overwritten)\n\n" "$BACKUP_ROOT"

cat <<'DONE'
  Next steps:
  1. Open Obsidian → "Open folder as vault" → select your vault path
  2. Open Claude Code or VS Code (Copilot Chat) in any workspace and run /prime
  3. Drop articles/PDFs/notes into the vault's raw/ folder, then /ingest

  Slash commands available globally (same names in Claude Code and Copilot):
    /prime       Load vault context
    /save        End-of-session human-readable recap (writes to sessions/)
    /ingest      Canonicalize raw/ + sessions/ into Context / Intelligence / Resources
    /query       Search the wiki
    /lint        Health check
    /notebooklm  Generate multimedia from wiki

DONE
