# palimpsest

> A persistent memory layer for Claude Code, built on Obsidian.

A *palimpsest* is a manuscript scraped clean and reused, with traces of the older writing still showing through the new. That's how this kit treats your knowledge: a raw layer of inputs that is never erased, a wiki layer that the LLM re-inscribes on top, and a schema layer of rules that governs both. Old layers stay legible underneath; new ones accumulate above.

## The problem

Claude Code forgets between sessions. Obsidian remembers everything but curates nothing. You end up either pasting the same context into every conversation, or watching your vault grow into a junk drawer.

palimpsest sits between the two. Claude reads and writes your vault according to a strict protocol, so every session contributes to a structured, queryable knowledge base — and every future session can start with that knowledge already loaded.

## Architecture

Three layers, three owners.

| Layer | Path | Owner | Rule |
| --- | --- | --- | --- |
| **Inputs** | `<vault>/raw/`, `<vault>/sessions/` | Human / LLM staging | Two staging areas. `raw/` is immutable external content (articles, PDFs, notes the human drops in). `sessions/` is `/save`'s output, awaiting ingestion. |
| **Wiki** | `<vault>/wiki/` | LLM | Canonized knowledge. Topical notes only. The LLM owns quality. |
| **Schema** | `~/.claude/CLAUDE.md` | Human | The rules, conventions, and vault path. |

`<vault>/log.md` lives at the vault root because it is audit metadata (operations journal), not knowledge.

Reads cross all layers. Writes are partitioned. The LLM cannot edit `raw/`. The human shouldn't edit `wiki/` directly — every change is routed through a slash command so the LLM can keep the index, log, and links coherent.

## Anatomy of a session

```
1. Drop a long article into <vault>/raw/clippings/
   (it stays there — raw/ is immutable)

2. Open a fresh Claude Code session in any project
   └─ /prime
      Claude loads the wiki index and the latest daily note.
      You don't need to re-explain what you're working on.

3. Have a deep working session — explore options, make decisions
   └─ /save
      Claude writes a human-readable session recap covering
      context, goals, process, blockers, decisions, learnings.
      The recap lands in sessions/ flagged as not-yet-ingested.

4. After a few sessions, when durable knowledge has accumulated
   └─ /ingest
      Claude scans raw/ and the un-ingested session recaps,
      proposes a promotion plan, and (after your OK) canonicalizes
      the durable bits into Context / Intelligence / Resources.

5. A week later, in a different project
   └─ /query "how did we decide on X?"
      Claude searches the wiki, cites sources, and reconstructs
      the reasoning from the daily note and the topical note.
```

## The six commands

| Command | Role |
| --- | --- |
| `/prime` | Load vault context at session start |
| `/save` | End-of-session human-readable recap → `Daily/` |
| `/ingest` | Canonicalize durable content from `raw/` and `Daily/` into Context / Intelligence / Resources |
| `/query` | Search the wiki with citations |
| `/lint` | Vault health-check (orphans, broken links, index drift) |
| `/notebooklm` | Generate podcasts/mindmaps from wiki via NotebookLM |

`/save` and `/ingest` are complementary: `/save` runs every session and captures what happened; `/ingest` runs when accumulated dailies (or new files in `raw/`) deserve promotion to the topical buckets. Several `/save`s before a single `/ingest` is the normal cadence.

## Lineage

The 3-layer architecture (raw / wiki / schema) is from [Andrej Karpathy's LLM Wiki](https://karpathy.ai). palimpsest operationalizes it as a memory layer **decoupled from your workspace**: one vault at a fixed absolute path, accessible from any Claude Code session in any directory. Knowledge accumulates centrally instead of fragmenting per-project. On top of that: six slash commands, strict ownership rules baked in, a one-line installer, and a `/save` daily note that captures the functional narrative of a session — context, goals, process, blockers, decisions, learnings — not a changelog of files.

## Install

```bash
git clone https://github.com/Sokrix/palimpsest.git
cd palimpsest
./install.sh
```

The installer:

1. Detects existing Obsidian vaults (via `~/Library/Application Support/obsidian/obsidian.json`) — pick one or create a new vault.
2. Creates the vault skeleton: `raw/{clippings,docs,notes}/`, `wiki/Daily/`, `wiki/index.md`, `wiki/log.md`.
3. Installs 6 slash commands to `~/.claude/commands/` with your vault path baked in.
4. Appends the palimpsest section to `~/.claude/CLAUDE.md` (or creates it).
5. Adds `Read/Edit/Write` permissions for the vault to `~/.claude/settings.json`.
6. Offers to `brew install --cask obsidian` if not present.

### Flags

```
./install.sh [OPTIONS]

  --vault-path PATH    Skip interactive selection; install to PATH
  --dry-run            Print actions, write nothing
  --reinstall          Force backup-and-rewrite of all kit-owned files
  -h, --help           Show usage
```

## Vault layout

```
<vault>/
├── raw/                    # external artifacts (immutable, human-only)
│   ├── clippings/
│   ├── docs/
│   └── notes/
├── sessions/               # session recaps written by /save (staging for /ingest)
├── log.md                  # append-only operations journal (audit metadata)
└── wiki/                   # canonized knowledge (LLM-managed)
    ├── index.md            # steering panel
    ├── Context/            # who/what/where notes
    ├── Intelligence/       # decisions, research, analyses
    └── Resources/          # patterns, templates, snippets
```

## Idempotency

Run the installer twice and nothing breaks.

| Path | Owner | Re-run / `--reinstall` behavior |
| --- | --- | --- |
| `~/.claude/commands/*.md` | Kit | Backup + overwrite when divergent |
| `~/.claude/CLAUDE.md` (with `## palimpsest` marker, or legacy `## Second Brain vault`) | Kit | Skip; `--reinstall` strips and re-appends |
| `~/.claude/CLAUDE.md` (without marker) | User | Append once, never overwrite |
| `<vault>/wiki/index.md` | User | Never touch |
| `<vault>/log.md` | User | Append re-init entry only |
| `<vault>/raw/**` | User | Never touch |
| `<vault>/sessions/**` | User | Never touch |
| Legacy `<vault>/wiki/Daily/` and `<vault>/wiki/log.md` | Kit migration | Migrated to `sessions/` and `log.md` at the root, then the legacy paths are removed |

Backups go to `~/.claude/backups/palimpsest/<timestamp>/`.

## Requirements

- macOS (Darwin)
- Claude Code CLI installed and run at least once (`~/.claude/` must exist)
- Python 3 (preinstalled on macOS)
- Obsidian (the installer offers to brew-install if missing)

## Repo layout

```
palimpsest/
├── install.sh                       # entry point
├── README.md                        # this file
├── CHANGELOG.md
└── templates/
    ├── CLAUDE.md                    # global config snippet appended to ~/.claude/CLAUDE.md
    ├── skills/                      # 6 slash commands installed to ~/.claude/commands/
    │   ├── prime.md
    │   ├── save.md
    │   ├── ingest.md
    │   ├── query.md
    │   ├── lint.md
    │   └── notebooklm.md
    └── vault/
        ├── log.md                   # seed for <vault>/log.md (only written if absent)
        └── wiki/
            └── index.md             # seed for <vault>/wiki/index.md (only written if absent)
```

Templates use two placeholders rendered by `sed` at install time: `{{VAULT_PATH}}` (the absolute vault path) and `{{INIT_DATE}}` / `{{INIT_TIME}}` (used in the seed log/index).

## Uninstall

There's no uninstall script — but the kit is well-bounded:

```bash
rm ~/.claude/commands/{prime,save,ingest,query,lint,notebooklm}.md
# Manually remove the "## palimpsest" section from ~/.claude/CLAUDE.md
# The vault itself stays where it is — your knowledge is yours.
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for notable changes. Run `./install.sh --reinstall` to pull updates into kit-owned files.

## License

MIT
