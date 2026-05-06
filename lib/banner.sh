#!/usr/bin/env bash
# palimpsest — terminal banner. Sourced by bin/palimpsest.
# Requires lib/common.sh first (uses BOLD/DIM/NC + PALIMPSEST_VERSION).

banner() {
  printf "\n"
  cat <<'BANNER'
             _ _                               _
 _ __   __ _| (_)_ __ ___  _ __  ___  ___  ___| |_
| '_ \ / _` | | | '_ ` _ \| '_ \/ __|/ _ \/ __| __|
| |_) | (_| | | | | | | | | |_) \__ \  __/\__ \ |_
| .__/ \__,_|_|_|_| |_| |_| .__/|___/\___||___/\__|
|_|                       |_|
BANNER
  printf "\n  ${BOLD}v%s${NC}  ${DIM}·  persistent memory for Claude Code & GitHub Copilot${NC}\n\n" "$PALIMPSEST_VERSION"
}
