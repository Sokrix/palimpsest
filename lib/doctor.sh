#!/usr/bin/env bash
# palimpsest — doctor. Sourced by bin/palimpsest.
# Health checks: are skills installed where we expect, is the vault writable,
# does the CLI itself resolve, and (for iCloud vaults) is Full Disk Access OK.

doctor_main() {
  banner
  hdr "palimpsest doctor"

  local fail=0

  # ── 1. CLI itself ────────────────────────────────────────────────────
  if command -v palimpsest >/dev/null 2>&1; then
    local resolved
    resolved="$(command -v palimpsest)"
    ok "palimpsest on PATH → $resolved"
  else
    warn "palimpsest is not on PATH (this run was direct: $0)"
  fi
  ok "Install mode: $PALIMPSEST_INSTALL_MODE"
  ok "PALIMPSEST_HOME: $PALIMPSEST_HOME"

  # ── 2. State file ────────────────────────────────────────────────────
  if load_state; then
    ok "State file loaded: $PALIMPSEST_STATE_FILE"
  else
    warn "No state file at $PALIMPSEST_STATE_FILE — has 'palimpsest install' been run?"
    fail=$((fail + 1))
  fi

  # ── 3. Vault ─────────────────────────────────────────────────────────
  if [ -n "${PALIMPSEST_VAULT_PATH:-}" ]; then
    if [ -d "$PALIMPSEST_VAULT_PATH" ]; then
      ok "Vault directory exists: $PALIMPSEST_VAULT_PATH"
      doctor_check_vault_layout
      doctor_check_vault_writable
    else
      err "Vault path missing on disk: $PALIMPSEST_VAULT_PATH"
      fail=$((fail + 1))
    fi
  else
    warn "No vault path recorded — skipping vault checks"
  fi

  # ── 4. Skills (per recorded target) ─────────────────────────────────
  local target="${PALIMPSEST_TARGET:-}"
  case "$target" in
    claude|both)  doctor_check_claude_skills  || fail=$((fail + 1)) ;;
  esac
  case "$target" in
    copilot|both) doctor_check_copilot_files || fail=$((fail + 1)) ;;
  esac
  if [ -z "$target" ]; then
    warn "No target recorded — skipping skill checks"
  fi

  # ── Summary ──────────────────────────────────────────────────────────
  hdr "Summary"
  local rc=0
  if [ "$fail" -eq 0 ]; then
    ok "All checks passed."
  else
    err "$fail check(s) failed."
    rc=1
  fi

  # Friendly notice if a newer version is on GitHub. Cached 24h.
  print_update_notice_if_newer
  return $rc
}

doctor_check_vault_layout() {
  local missing=0
  for sub in raw sessions wiki wiki/Context wiki/Intelligence wiki/Resources; do
    if [ ! -d "$PALIMPSEST_VAULT_PATH/$sub" ]; then
      err "Missing $PALIMPSEST_VAULT_PATH/$sub/"
      missing=$((missing + 1))
    fi
  done
  if [ "$missing" -eq 0 ]; then
    ok "Vault layout intact (raw/, sessions/, wiki/{Context,Intelligence,Resources}/)"
  else
    return 1
  fi
}

doctor_check_vault_writable() {
  local logfile="$PALIMPSEST_VAULT_PATH/log.md"
  if [ ! -f "$logfile" ]; then
    warn "log.md not yet created — re-run 'palimpsest install' to seed it"
    return 0
  fi
  if python3 - "$logfile" <<'PYEOF' 2>/dev/null; then
import sys
from pathlib import Path
p = Path(sys.argv[1])
try:
    with p.open("a"):
        pass
    sys.exit(0)
except PermissionError:
    sys.exit(1)
PYEOF
    ok "Vault is writable from this terminal"
  else
    err "Cannot append to $logfile — Full Disk Access is missing for this terminal."
    cat <<FDA
    Open System Settings → Privacy & Security → Full Disk Access
    Enable the toggle for your terminal app, then quit & relaunch it.
FDA
    return 1
  fi
}

doctor_check_claude_skills() {
  local missing=0
  for name in prime save ingest query lint; do
    if [ ! -f "$HOME/.claude/commands/$name.md" ]; then
      err "Missing ~/.claude/commands/$name.md"
      missing=$((missing + 1))
    fi
  done
  if [ "$missing" -eq 0 ]; then
    ok "Claude Code skills present (~/.claude/commands/)"
    return 0
  fi
  return 1
}

doctor_check_copilot_files() {
  local missing=0
  for f in prime save ingest query lint; do
    if [ ! -f "$HOME/.copilot/prompts/$f.prompt.md" ]; then
      err "Missing ~/.copilot/prompts/$f.prompt.md"
      missing=$((missing + 1))
    fi
  done
  if [ ! -f "$HOME/.copilot/instructions/palimpsest.instructions.md" ]; then
    err "Missing ~/.copilot/instructions/palimpsest.instructions.md"
    missing=$((missing + 1))
  fi
  if [ "$missing" -eq 0 ]; then
    ok "Copilot prompts & instructions present"
    return 0
  fi
  return 1
}
