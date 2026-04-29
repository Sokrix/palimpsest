#!/usr/bin/env bash
set -euo pipefail

# palimpsest — installer
# Sets up the vault, installs slash commands globally, configures Claude Code.

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

usage() {
  cat <<USAGE
palimpsest installer

Usage: ./install.sh [OPTIONS]

Options:
  --vault-path PATH    Skip interactive selection; install to PATH
  --dry-run            Print actions, write nothing
  --reinstall          Force backup-and-rewrite of all kit-owned files
  -h, --help           Show this message
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --vault-path) CLI_VAULT_PATH="${2:-}"; shift 2 ;;
    --dry-run)    DRY_RUN=1; shift ;;
    --reinstall)  REINSTALL=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            err "Unknown flag: $1"; usage; exit 1 ;;
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
  A persistent memory layer for Claude Code, built on Obsidian

BANNER
[ "$DRY_RUN" -eq 1 ] && warn "DRY RUN — no files will be written"
[ "$REINSTALL" -eq 1 ] && warn "REINSTALL — kit-owned files will be backed up and rewritten"

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

if [ ! -d "$HOME/.claude" ]; then
  err "~/.claude/ doesn't exist — run 'claude' once to initialize Claude Code, then re-run this installer."
  exit 1
fi
ok "~/.claude/ exists"

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

# backup_if_needed FILE — moves FILE to ~/.claude/backups/palimpsest/<ts>/...
BACKUP_TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$HOME/.claude/backups/palimpsest/$BACKUP_TS"
backup_if_needed() {
  local target="$1"
  [ -f "$target" ] || return 0
  local rel="${target#$HOME/}"
  local dest="$BACKUP_ROOT/$rel"
  run "mkdir -p \"$(dirname "$dest")\""
  run "cp \"$target\" \"$dest\""
  warn "Backed up: $target → $dest"
}

# ── Confirmation ────────────────────────────────────────────────────────
hdr "Summary — about to install"
cat <<SUMMARY
  Vault path:       $VAULT_PATH
  Skills target:    $HOME/.claude/commands/  (7 files)
  Global config:    $HOME/.claude/CLAUDE.md  (append if marker absent)
  Permissions:      $HOME/.claude/settings.json  (Read/Edit/Write on vault)
  Backups (if any): $BACKUP_ROOT/

SUMMARY
read -rp "Proceed? [y/N] " confirm
[[ "$confirm" =~ ^[Yy] ]] || { warn "Aborted by user"; exit 0; }

# ── Vault structure ─────────────────────────────────────────────────────
hdr "Creating vault structure"
run "mkdir -p \"$VAULT_PATH/raw/clippings\" \"$VAULT_PATH/raw/docs\" \"$VAULT_PATH/raw/notes\" \"$VAULT_PATH/wiki/Daily\""
ok "Folders created"

# ── Seed wiki files ─────────────────────────────────────────────────────
# These are User-owned: never overwrite if present, even on --reinstall.
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

if [ ! -f "$VAULT_PATH/wiki/log.md" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] write $VAULT_PATH/wiki/log.md (with substitutions)"
  else
    render "$REPO_DIR/templates/vault/wiki/log.md" > "$VAULT_PATH/wiki/log.md"
  fi
  ok "Seeded wiki/log.md"
else
  # Append a re-init entry; never overwrite the log (User-owned, append-only)
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] append re-init entry to $VAULT_PATH/wiki/log.md"
  else
    printf "%s %s — Init: palimpsest re-run (paths refreshed)\n" "$INIT_DATE" "$INIT_TIME" >> "$VAULT_PATH/wiki/log.md"
  fi
  warn "wiki/log.md exists — appended re-init entry"
fi

# ── Install skills ──────────────────────────────────────────────────────
hdr "Installing slash commands"
run "mkdir -p \"$HOME/.claude/commands\""

skill_count=0
skipped=0
for f in "$REPO_DIR/templates/skills/"*.md; do
  name=$(basename "$f")
  target="$HOME/.claude/commands/$name"
  rendered=$(render "$f")

  if [ -f "$target" ]; then
    existing=$(cat "$target")
    if [ "$rendered" = "$existing" ] && [ "$REINSTALL" -eq 0 ]; then
      skipped=$((skipped + 1))
      continue
    fi
    backup_if_needed "$target"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] write $target"
  else
    printf '%s' "$rendered" > "$target"
  fi
  skill_count=$((skill_count + 1))
done
ok "Installed/updated $skill_count skill(s); skipped $skipped already-current"

# ── Global CLAUDE.md ────────────────────────────────────────────────────
hdr "Configuring global CLAUDE.md"
GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
RENDERED_CLAUDE=$(render "$REPO_DIR/templates/CLAUDE.md")

if [ -f "$GLOBAL_CLAUDE" ]; then
  # Detect either the new marker (palimpsest) or the legacy one (Second Brain vault),
  # so existing installs from the prior name migrate cleanly on --reinstall.
  if grep -qE "^## (palimpsest|Second Brain vault)$" "$GLOBAL_CLAUDE"; then
    if [ "$REINSTALL" -eq 1 ]; then
      backup_if_needed "$GLOBAL_CLAUDE"
      # Strip from whichever marker is present, then re-append the current section.
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [dry-run] strip existing palimpsest/Second Brain section from $GLOBAL_CLAUDE and re-append"
      else
        awk '/^## palimpsest$/{exit} /^## Second Brain vault$/{exit} {print}' "$GLOBAL_CLAUDE" > "${GLOBAL_CLAUDE}.tmp"
        # Trim trailing blank lines
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

# ── Settings.json permissions ───────────────────────────────────────────
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

# ── Done ────────────────────────────────────────────────────────────────
hdr "Install complete"
cat <<DONE

  Vault:    $VAULT_PATH
  Skills:   $HOME/.claude/commands/  ($skill_count installed/updated, $skipped already current)
  Config:   $HOME/.claude/CLAUDE.md
  Settings: $HOME/.claude/settings.json
  Backups:  $BACKUP_ROOT/  (if any files were overwritten)

  Next steps:
  1. Open Obsidian → "Open folder as vault" → select your vault path
  2. Open Claude Code in any workspace and run /prime
  3. Drop articles/PDFs/notes into the vault's raw/ folder, then /ingest

  Slash commands available globally from any Claude Code session:
    /prime    Load vault context
    /ingest   Compile raw/ → wiki/
    /save     End-of-session checkpoint (light)
    /compile  End-of-session checkpoint (deep, with topical notes)
    /query    Search the wiki
    /lint     Health check
    /notebooklm  Generate multimedia from wiki

DONE
