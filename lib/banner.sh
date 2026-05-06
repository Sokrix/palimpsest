#!/usr/bin/env bash
# palimpsest — terminal banner. Sourced by bin/palimpsest.
# Requires lib/common.sh to be sourced first (uses BOLD/DIM/NC + PALIMPSEST_VERSION).

banner() {
  printf "\n"
  printf "  ${BOLD}palimpsest${NC} ${DIM}v%s${NC}\n" "$PALIMPSEST_VERSION"
  printf "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
  printf "  persistent memory for Claude Code & GitHub Copilot\n"
  printf "\n"
}
