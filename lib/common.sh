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
#
# Older state files (≤ 0.1.2) wrote PALIMPSEST_VERSION="<install-time version>"
# which collides with the runtime VERSION. Preserve the runtime value across
# the source so update-check still works on legacy state files.
load_state() {
  if state_exists; then
    local _runtime_version="$PALIMPSEST_VERSION"
    # shellcheck disable=SC1090
    . "$PALIMPSEST_STATE_FILE"
    PALIMPSEST_VERSION="$_runtime_version"
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
PALIMPSEST_INSTALLED_VERSION="$PALIMPSEST_VERSION"
PALIMPSEST_VAULT_PATH="$vault"
PALIMPSEST_TARGET="$target"
PALIMPSEST_INSTALLED_AT="$now"
PALIMPSEST_REPO_DIR="$repo"
PALIMPSEST_INSTALL_MODE="$PALIMPSEST_INSTALL_MODE"
EOF
}

# ── Update check ────────────────────────────────────────────────────────
# Hits api.github.com once a day to see if a newer release exists.
# Result is cached at ~/.palimpsest/update-check (epoch + version).
# Honors PALIMPSEST_NO_UPDATE_CHECK=1 (skips silently). Network failure
# is silent — the user's actual command still runs.

PALIMPSEST_UPDATE_CACHE="$PALIMPSEST_STATE_DIR/update-check"
PALIMPSEST_UPDATE_TTL=86400  # 24h

# Print latest version (e.g. "0.1.3") to stdout, or empty on failure.
check_latest_version() {
  [ "${PALIMPSEST_NO_UPDATE_CHECK:-0}" = "1" ] && return 1

  # Cache hit?
  if [ -f "$PALIMPSEST_UPDATE_CACHE" ]; then
    local cached_at cached_ver age
    cached_at="$(sed -n '1p' "$PALIMPSEST_UPDATE_CACHE" 2>/dev/null)"
    cached_ver="$(sed -n '2p' "$PALIMPSEST_UPDATE_CACHE" 2>/dev/null)"
    if [ -n "$cached_at" ] && [ -n "$cached_ver" ]; then
      age=$(( $(date "+%s") - cached_at ))
      if [ "$age" -ge 0 ] && [ "$age" -lt "$PALIMPSEST_UPDATE_TTL" ]; then
        printf '%s' "$cached_ver"
        return 0
      fi
    fi
  fi

  # Cache miss — fetch from GitHub. Hard 3-second timeout so we don't hang.
  # Using /tags rather than /releases/latest because the latter 404s when
  # tags exist but no formal Release was published. Tags always work.
  local latest
  latest="$(curl -s --max-time 3 -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/Sokrix/palimpsest/tags?per_page=20" 2>/dev/null \
    | python3 -c 'import json, re, sys
try:
  tags = json.load(sys.stdin)
  if not isinstance(tags, list):
    sys.exit(0)
  vers = []
  for t in tags:
    n = t.get("name", "").lstrip("v")
    if re.match(r"^\d+\.\d+\.\d+$", n):
      vers.append(tuple(int(x) for x in n.split(".")))
  if vers:
    print(".".join(str(x) for x in max(vers)))
except Exception:
  pass' 2>/dev/null)"

  [ -z "$latest" ] && return 1

  mkdir -p "$PALIMPSEST_STATE_DIR"
  printf '%s\n%s\n' "$(date "+%s")" "$latest" > "$PALIMPSEST_UPDATE_CACHE"
  printf '%s' "$latest"
}

# version_gt A B → exit 0 if A > B (strict). Semver, three-part.
version_gt() {
  [ "$1" = "$2" ] && return 1
  local IFS=.
  local v1 v2 i
  read -r -a v1 <<< "$1"
  read -r -a v2 <<< "$2"
  for i in 0 1 2; do
    local a="${v1[i]:-0}" b="${v2[i]:-0}"
    [ "$a" -gt "$b" ] 2>/dev/null && return 0
    [ "$a" -lt "$b" ] 2>/dev/null && return 1
  done
  return 1
}

# Show a friendly notice if a newer version is available. No-op otherwise.
print_update_notice_if_newer() {
  local latest cmd
  latest="$(check_latest_version)" || return 0
  [ -z "$latest" ] && return 0
  if version_gt "$latest" "$PALIMPSEST_VERSION"; then
    if [ "$PALIMPSEST_INSTALL_MODE" = "brew" ]; then
      cmd="brew upgrade palimpsest"
    else
      cmd="palimpsest update"
    fi
    printf "\n  ${YELLOW}🆕 palimpsest v%s is available${NC} ${DIM}(you have v%s)${NC}\n" "$latest" "$PALIMPSEST_VERSION"
    printf "  Run: ${BOLD}%s${NC}\n" "$cmd"
  fi
}
