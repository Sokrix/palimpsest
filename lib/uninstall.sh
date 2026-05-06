#!/usr/bin/env bash
# palimpsest — uninstall. Sourced by bin/palimpsest.
# Removes kit-owned files. Leaves the vault and ~/.claude/CLAUDE.md alone
# (the vault is the user's data; CLAUDE.md may have user content interleaved).

# Supported flag: --dry-run

uninstall_main() {
  local dry_run=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=1 ;;
      -h|--help)
        cat <<USAGE
Usage: palimpsest uninstall [--dry-run]

Removes the slash commands and prompt files installed by palimpsest:
  ~/.claude/commands/{prime,save,ingest,query,lint,notebooklm}.md
  ~/.copilot/prompts/*.prompt.md
  ~/.copilot/instructions/palimpsest.instructions.md
  ~/.palimpsest/state

Leaves untouched (you must remove these manually if you want them gone):
  Your vault directory and its contents
  ~/.claude/CLAUDE.md (the palimpsest section can be edited by hand)
  ~/.claude/settings.json (the Read/Edit/Write permissions on the vault)
  VS Code settings.json (chat.{prompt,instructions}FilesLocations entries)
USAGE
        return 0 ;;
      *) err "Unknown flag: $arg"; return 1 ;;
    esac
  done

  banner

  local vault_hint="(unknown — install state not found)"
  if load_state; then
    vault_hint="${PALIMPSEST_VAULT_PATH:-unknown}"
  fi

  hdr "About to remove"
  printf "  ~/.claude/commands/{prime,save,ingest,query,lint,notebooklm}.md\n"
  printf "  ~/.copilot/prompts/*.prompt.md\n"
  printf "  ~/.copilot/instructions/palimpsest.instructions.md\n"
  printf "  ~/.palimpsest/state\n"
  printf "\n"
  printf "  ${BOLD}Vault left intact:${NC}  %s\n\n" "$vault_hint"

  if [ "$dry_run" -eq 1 ]; then
    warn "DRY RUN — no files will be removed"
  else
    read -rp "Proceed? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy] ]] || { warn "Aborted by user"; return 0; }
  fi

  local removed=0

  remove_one() {
    local f="$1"
    [ -e "$f" ] || return 0
    if [ "$dry_run" -eq 1 ]; then
      printf "  [dry-run] rm %s\n" "$f"
    else
      rm -f "$f"
      ok "Removed $f"
    fi
    removed=$((removed + 1))
  }

  hdr "Removing Claude Code skills"
  for name in prime save ingest query lint notebooklm; do
    remove_one "$HOME/.claude/commands/$name.md"
  done

  hdr "Removing Copilot prompts & instructions"
  if [ -d "$HOME/.copilot/prompts" ]; then
    for f in "$HOME/.copilot/prompts/"*.prompt.md; do
      [ -e "$f" ] || continue
      remove_one "$f"
    done
  fi
  remove_one "$HOME/.copilot/instructions/palimpsest.instructions.md"

  hdr "Removing CLI state"
  remove_one "$PALIMPSEST_STATE_FILE"

  hdr "Done"
  if [ "$dry_run" -eq 1 ]; then
    printf "  Would remove %d file(s).\n\n" "$removed"
  else
    printf "  Removed %d file(s).\n\n" "$removed"
  fi
  printf "  ${DIM}Vault preserved at: %s${NC}\n" "$vault_hint"
  printf "  ${DIM}~/.claude/CLAUDE.md and settings.json were not modified.${NC}\n\n"
}
