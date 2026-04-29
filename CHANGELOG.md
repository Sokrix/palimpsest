# Changelog

Notable changes to palimpsest. Reinstall (`./install.sh --reinstall`) to pull in changes to kit-owned files.

## 2026-04-29 (later still)

### Layout — `Daily/` renamed `sessions/` and moved out of `wiki/`; `log.md` moved to vault root

The `wiki/` folder now contains *only* canonized knowledge: the index plus the three topical buckets (Context, Intelligence, Resources). Two things that were artificially nested inside it have been pulled up:

- **Session recaps**: `wiki/Daily/` → `sessions/` at the vault root. They sit alongside `raw/` as a sibling staging area — both feed `/ingest`. The new name reflects what they are (per-session recaps), not when they're written. The frontmatter `type: daily` becomes `type: session`, and `tags: [daily]` becomes `tags: [session]`.
- **Operations log**: `wiki/log.md` → `log.md` at the vault root. It's audit metadata, not knowledge — it doesn't belong in the canonized layer.

### Updated 3-layer architecture

| Layer            | Path                                | Owner               | Rule                                                                 |
| ---------------- | ----------------------------------- | ------------------- | -------------------------------------------------------------------- |
| Layer 1 — Inputs | `<vault>/raw/`, `<vault>/sessions/` | Human / LLM staging | Two staging areas. Immutable external content + un-ingested recaps.  |
| Layer 2 — Wiki   | `<vault>/wiki/`                     | LLM                 | Canonized knowledge. Topical notes + index only.                     |
| Layer 3 — Schema | `~/.claude/CLAUDE.md`               | Human               | Rules, conventions, vault path.                                      |

### Migration

Running `./install.sh` (or `--reinstall`) on an existing install:

- Moves any files from `<vault>/wiki/Daily/` to `<vault>/sessions/` and removes the empty legacy folder.
- Moves `<vault>/wiki/log.md` to `<vault>/log.md` if the new location is absent.
- Creates `sessions/` and the topical bucket folders explicitly (no longer relies on `wiki/Daily/`).

`/save`, `/ingest`, `/prime`, `/lint`, `/query`, `/notebooklm` all updated to write/read from the new paths. `lint` now exempts `sessions/` from the orphan check (chronological, not part of the topical graph) and warns when the un-ingested session backlog grows beyond seven recaps.

## 2026-04-29 (later)

### Architecture — `/compile` merged into `/ingest`

`/compile` and `/save` were stepping on each other's toes: both wrote daily notes, and the only real difference was depth. The split forced a binary "is this session worth canonicalizing right now?" decision at the wrong moment — at the end of every session, when fatigue is high and the value of the content isn't yet obvious.

**New shape:**

- **`/save`** — runs every session. Writes a human-readable daily recap with six sections: Context, Goals, Process & workflow, Blockers & workarounds, Decisions, Learnings. The daily lands in `Daily/` flagged as `ingested: false`.
- **`/ingest`** — now the single canonization operation. Scans both `raw/` (external artifacts) and `Daily/` (un-ingested session recaps) and proposes a promotion plan into the three topical buckets. After validation, durable content is written to `Context/`, `Intelligence/`, or `Resources/`, and the source dailies are stamped `ingested: <timestamp>`.
- **`/compile`** — removed. Its rendering of session content into topical notes is now part of `/ingest`'s remit.

The daily structure shifted from "narrative arc" (Context / Exploration / Convergence / Learnings / Blockers / Actions / Next) to "session report" (Context / Goals / Process / Blockers / Decisions / Learnings) — closer to a human-readable post-mortem, lighter on technical detail.

### Schema — bucket rubric tightened in `CLAUDE.md`

Previously the three topical buckets (Context / Intelligence / Resources) were defined in a one-liner-per-folder table. The new `CLAUDE.md` carries a real classification rubric: a decisive question per bucket, a "test" sentence to apply when in doubt, and disambiguation rules for the common edge cases (research that produced a decision vs a framework, project briefs containing decisions, patterns we discovered vs analyzed). Both `/ingest` and the model now reference this single source of truth instead of restating the rubric in each skill.

### Migration

Running `./install.sh --reinstall` on an existing install:

- Removes the orphaned `~/.claude/commands/compile.md` (backed up first).
- Rewrites `save.md` and `ingest.md` with the new behavior.
- Refreshes the `## palimpsest` section in `~/.claude/CLAUDE.md` with the new rubric and operations table.

Existing daily notes written by the old `/compile` are not migrated — they remain valid, just structured differently from new ones. To promote durable content from them into the topical buckets, they need an `ingested: false` field added manually (or just say so in the next `/ingest` invocation).

## 2026-04-29

### Renamed

- **Project renamed: `secondbrain-kit` → `palimpsest`.** The CLAUDE.md section header is now `## palimpsest` (was `## Second Brain vault`). The installer migrates legacy installs cleanly: existing users running `./install.sh --reinstall` have their old `## Second Brain vault` section detected, stripped, and replaced with the new `## palimpsest` section. The default local vault path moved from `~/Documents/secondbrain` to `~/Documents/palimpsest`. Backup directory moved from `~/.claude/backups/secondbrain-kit/` to `~/.claude/backups/palimpsest/`.

### Changed

- **`/compile` daily note** — replaced the three-bullet template (Actions / Decisions / Next step) with a richer narrative structure: Context, Exploration, Convergence, Learnings, Blockers, Actions, Next. The daily note is now the functional story of the session — what we did, why, what paths we explored, what we converged on, what we learned, what blocked us — rather than a changelog of file changes. Topical notes (Context / Intelligence / Resources) are unchanged.
