#!/usr/bin/env bash
# palimpsest — common helpers sourced by bin/palimpsest and lib/*.sh
# Defines: PALIMPSEST_HOME, PALIMPSEST_VERSION, color/log helpers, state-file IO.

# ── Colors / log helpers ────────────────────────────────────────────────
GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
ok()   { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}!${NC} %s\n" "$*"; }
err()  { printf "${RED}✗${NC} %s\n" "$*" >&2; }
hdr()  { printf "\n${BOLD}%s${NC}\n" "$*"; }
dim()  { printf "${DIM}%s${NC}\n" "$*"; }

# ── Path resolution ─────────────────────────────────────────────────────
# Resolve a path through symlinks. macOS's BSD `readlink` lacks `-f`, so
# fall back to python3 (already a hard prereq for install.sh).
realpath_compat() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target"
  else
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$target"
  fi
}

# Determine PALIMPSEST_HOME — the directory containing templates/, install.sh, lib/.
#
#   Source mode (running from a clone or symlink into a clone):
#     <bin>/../templates/     exists  →  PALIMPSEST_HOME = <bin>/..
#
#   Brew mode (Homebrew bakes the libexec path into the script via inreplace):
#     PALIMPSEST_HOME_OVERRIDE  is set →  PALIMPSEST_HOME = $PALIMPSEST_HOME_OVERRIDE
#
# The override is read from the calling script's environment — bin/palimpsest
# defines `PALIMPSEST_HOME_OVERRIDE=""` near the top, and the brew formula
# rewrites that line during install with the real libexec path.
resolve_palimpsest_home() {
  if [ -n "${PALIMPSEST_HOME_OVERRIDE:-}" ] && [ -d "$PALIMPSEST_HOME_OVERRIDE/templates" ]; then
    PALIMPSEST_HOME="$PALIMPSEST_HOME_OVERRIDE"
    PALIMPSEST_INSTALL_MODE="brew"
    return
  fi

  # Walk up from this lib file to find a sibling templates/ dir.
  local lib_dir
  lib_dir="$(cd "$(dirname "$(realpath_compat "${BASH_SOURCE[0]}")")" && pwd)"
  local candidate="$(dirname "$lib_dir")"
  if [ -d "$candidate/templates" ]; then
    PALIMPSEST_HOME="$candidate"
    PALIMPSEST_INSTALL_MODE="source"
    return
  fi

  err "Could not locate palimpsest templates/. Looked in: $candidate/templates"
  err "If you installed via Homebrew, this is a packaging bug — please report it."
  exit 1
}

resolve_palimpsest_home
export PALIMPSEST_HOME PALIMPSEST_INSTALL_MODE

# ── Version ─────────────────────────────────────────────────────────────
read_version() {
  local f="$PALIMPSEST_HOME/VERSION"
  if [ -f "$f" ]; then
    head -n1 "$f" | tr -d '[:space:]'
  else
    echo "unknown"
  fi
}

PALIMPSEST_VERSION="$(read_version)"
export PALIMPSEST_VERSION

# Short git SHA when running from a clone; empty otherwise.
read_git_sha() {
  if [ "$PALIMPSEST_INSTALL_MODE" = "source" ] && command -v git >/dev/null 2>&1; then
    git -C "$PALIMPSEST_HOME" rev-parse --short HEAD 2>/dev/null || true
  fi
}

# ── State file IO ───────────────────────────────────────────────────────
# Written by install.sh on successful completion; read by where/status/doctor/uninstall.
PALIMPSEST_STATE_DIR="$HOME/.palimpsest"
PALIMPSEST_STATE_FILE="$PALIMPSEST_STATE_DIR/state"

state_exists() {
  [ -f "$PALIMPSEST_STATE_FILE" ]
}

# Sources the state file into the current shell. After this call, the
# PALIMPSEST_VAULT_PATH / PALIMPSEST_TARGET / etc. variables are available.
load_state() {
  if state_exists; then
    # shellcheck disable=SC1090
    . "$PALIMPSEST_STATE_FILE"
    return 0
  fi
  return 1
}

# Atomically write the state file. Called from install.sh at the end of a
# successful install. Args: vault_path target repo_dir.
write_state() {
  local vault="$1" target="$2" repo="$3"
  local now
  now="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  mkdir -p "$PALIMPSEST_STATE_DIR"
  cat > "$PALIMPSEST_STATE_FILE" <<EOF
# palimpsest state — written by install.sh, read by the CLI.
# Safe to delete; \`palimpsest install\` will recreate it.
PALIMPSEST_VERSION="$PALIMPSEST_VERSION"
PALIMPSEST_VAULT_PATH="$vault"
PALIMPSEST_TARGET="$target"
PALIMPSEST_INSTALLED_AT="$now"
PALIMPSEST_REPO_DIR="$repo"
PALIMPSEST_INSTALL_MODE="$PALIMPSEST_INSTALL_MODE"
EOF
}
