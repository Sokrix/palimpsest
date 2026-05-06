#!/usr/bin/env bash
# bash completion for palimpsest. Installed by Homebrew to
# /opt/homebrew/etc/bash_completion.d/palimpsest

_palimpsest() {
  local cur prev cmds
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  cmds="install reinstall uninstall update upgrade doctor status where version help"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi

  # Strip a leading slash so `palimpsest /install --<tab>` works.
  local subcmd="${COMP_WORDS[1]#/}"

  case "$subcmd" in
    install|reinstall)
      case "$prev" in
        --target)      COMPREPLY=( $(compgen -W "claude copilot both" -- "$cur") ); return 0 ;;
        --vault-path)  COMPREPLY=( $(compgen -d -- "$cur") ); return 0 ;;
      esac
      COMPREPLY=( $(compgen -W "--vault-path --target --dry-run --reinstall -h --help" -- "$cur") )
      ;;
    uninstall)
      COMPREPLY=( $(compgen -W "--dry-run -h --help" -- "$cur") )
      ;;
  esac
}

complete -F _palimpsest palimpsest
