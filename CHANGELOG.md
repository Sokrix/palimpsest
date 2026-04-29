# Changelog

Notable changes to palimpsest. Reinstall (`./install.sh --reinstall`) to pull in changes to kit-owned files.

## 2026-04-29

### Renamed

- **Project renamed: `secondbrain-kit` → `palimpsest`.** The CLAUDE.md section header is now `## palimpsest` (was `## Second Brain vault`). The installer migrates legacy installs cleanly: existing users running `./install.sh --reinstall` have their old `## Second Brain vault` section detected, stripped, and replaced with the new `## palimpsest` section. The default local vault path moved from `~/Documents/secondbrain` to `~/Documents/palimpsest`. Backup directory moved from `~/.claude/backups/secondbrain-kit/` to `~/.claude/backups/palimpsest/`.

### Changed

- **`/compile` daily note** — replaced the three-bullet template (Actions / Decisions / Next step) with a richer narrative structure: Context, Exploration, Convergence, Learnings, Blockers, Actions, Next. The daily note is now the functional story of the session — what we did, why, what paths we explored, what we converged on, what we learned, what blocked us — rather than a changelog of file changes. Topical notes (Context / Intelligence / Resources) are unchanged.
