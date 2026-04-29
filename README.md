# palimpsest

> A persistent memory layer for Claude Code, built on Obsidian.

A *palimpsest* is a manuscript scraped clean and reused, with traces of the older writing still showing through the new. That's how this kit treats your knowledge: a raw layer of inputs that is never erased, a wiki layer that the LLM re-inscribes on top, and a schema layer of rules that governs both. Old layers stay legible underneath; new ones accumulate above.

## The problem

Claude Code forgets between sessions. Obsidian remembers everything but curates nothing. You end up either pasting the same context into every conversation, or watching your vault grow into a junk drawer.

palimpsest sits between the two. Claude reads and writes your vault according to a strict protocol, so every session contributes to a structured, queryable knowledge base — and every future session can start with that knowledge already loaded.

## Architecture

Three layers, three owners, three rules.

| Layer | Path | Owner | Rule |
| --- | --- | --- | --- |
| **Raw** | `<vault>/raw/` | Human | Immutable. Drop articles, PDFs, notes here. The LLM reads but never touches. |
| **Wiki** | `<vault>/wiki/` | LLM | Compiled. Concepts, syntheses, daily notes. The LLM owns quality. |
| **Schema** | `~/.claude/CLAUDE.md` | Human | The rules, conventions, and vault path. |

Reads cross all layers. Writes are partitioned. The LLM cannot edit `raw/`. The human shouldn't edit `wiki/` directly — every change is routed through a slash command so the LLM can keep the index, log, and links coherent.

## Anatomy of a session

```
1. Drop a long article into <vault>/raw/clippings/
   └─ /ingest
      Claude reads the article, classifies it, writes one or more
      structured notes in wiki/Intelligence/ or wiki/Resources/,
      and links them into the index.

2. Open a fresh Claude Code session in any project
   └─ /prime
      Claude loads the wiki index and the relevant context notes.
      You don't need to re-explain what you're working on.

3. Have a deep working session — explore options, make decisions
   └─ /compile
      Claude writes topical notes for the durable knowledge AND
      a daily note that is the functional narrative of the session:
      what we did, why, what we explored, what we converged on,
      what we learned, what blocked us.

4. A week later, in a different project
   └─ /query "how did we decide on X?"
      Claude searches the wiki, cites sources, and reconstructs
      the reasoning from the daily note and the topical note.
```

## The seven commands

| Command | Role |
| --- | --- |
| `/prime` | Load vault context at session start |
| `/ingest` | Compile new files in `raw/` into structured wiki notes |
| `/save` | End-of-session daily note (light) |
| `/compile` | End-of-session topical wiki notes + daily narrative (deep) |
| `/query` | Search the wiki with citations |
| `/lint` | Vault health-check (orphans, broken links, index drift) |
| `/notebooklm` | Generate podcasts/mindmaps from wiki via NotebookLM |

`/save` and `/compile` are mutually exclusive. Pick `/compile` when the session produced durable knowledge worth canonicalizing. Pick `/save` for a light checkpoint with nothing substantive to compile.

## Lineage

palimpsest stands on three shoulders, and is open about it.

- **[Andrej Karpathy's LLM Wiki](https://karpathy.ai)** — the 3-layer architecture (raw / wiki / schema) is his. The ownership rules, the LLM-as-curator framing, the index-as-steering-panel idea — all his. palimpsest is essentially Karpathy's concept, operationalized.
- **The "second brain" tradition** — Tiago Forte's PKM movement, and behind it the much older practice of *hypomnemata*: the personal notebooks that ancient philosophers like Seneca kept for collecting and reflecting on what they read.
- **Vannevar Bush's [memex](https://en.wikipedia.org/wiki/Memex)** (1945) — the original vision of a personal device that augments memory by linking documents associatively. The grandparent of every PKM tool, including this one.

What palimpsest adds on top:

- **Operationalized**, not theoretical. Karpathy describes the architecture; palimpsest is seven working slash commands with strict rules baked in, plus a one-line installer that bootstraps Obsidian + Claude Code together.
- **A two-tier session capture**: `/save` for daily checkpoints, `/compile` for deep sessions that deserve canonicalization into topical notes.
- **The daily note as a functional narrative**, not a changelog. It captures the *story* of the session — context, exploration, convergence, learnings, blockers — so a future session can reconstruct the *thinking*, not just the outcome.
- **Strict idempotency.** The kit owns templates; you own knowledge. Reinstall safely: kit-owned files get backed up and rewritten, user-owned files (your wiki, your raw inputs, your index, your log) are never overwritten.
- **Cross-session persistence** that works from any working directory. Skills use absolute paths, so the same vault is available whether you're in a code repo, a research project, or a one-off conversation.

## Install

```bash
git clone https://github.com/Sokrix/palimpsest.git
cd palimpsest
./install.sh
```

The installer:

1. Detects existing Obsidian vaults (via `~/Library/Application Support/obsidian/obsidian.json`) — pick one or create a new vault.
2. Creates the vault skeleton: `raw/{clippings,docs,notes}/`, `wiki/Daily/`, `wiki/index.md`, `wiki/log.md`.
3. Installs 7 slash commands to `~/.claude/commands/` with your vault path baked in.
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
├── raw/                    # human-only input layer (immutable)
│   ├── clippings/
│   ├── docs/
│   └── notes/
└── wiki/                   # LLM-managed compiled layer
    ├── index.md            # steering panel
    ├── log.md              # append-only operations journal
    ├── Context/            # who/what/where notes
    ├── Intelligence/       # decisions, research, analyses
    ├── Resources/          # patterns, templates, snippets
    └── Daily/              # daily notes
```

## Idempotency

Run the installer twice and nothing breaks.

| Path | Owner | Re-run / `--reinstall` behavior |
| --- | --- | --- |
| `~/.claude/commands/*.md` | Kit | Backup + overwrite when divergent |
| `~/.claude/CLAUDE.md` (with `## palimpsest` marker, or legacy `## Second Brain vault`) | Kit | Skip; `--reinstall` strips and re-appends |
| `~/.claude/CLAUDE.md` (without marker) | User | Append once, never overwrite |
| `<vault>/wiki/index.md` | User | Never touch |
| `<vault>/wiki/log.md` | User | Append re-init entry only |
| `<vault>/raw/**` | User | Never touch |

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
    ├── skills/                      # 7 slash commands installed to ~/.claude/commands/
    │   ├── prime.md
    │   ├── ingest.md
    │   ├── save.md
    │   ├── compile.md
    │   ├── query.md
    │   ├── lint.md
    │   └── notebooklm.md
    └── vault/wiki/
        ├── index.md                 # seed (only written if absent)
        └── log.md                   # seed (only written if absent)
```

Templates use two placeholders rendered by `sed` at install time: `{{VAULT_PATH}}` (the absolute vault path) and `{{INIT_DATE}}` / `{{INIT_TIME}}` (used in the seed log/index).

## Uninstall

There's no uninstall script — but the kit is well-bounded:

```bash
rm ~/.claude/commands/{prime,ingest,save,compile,query,lint,notebooklm}.md
# Manually remove the "## palimpsest" section from ~/.claude/CLAUDE.md
# The vault itself stays where it is — your knowledge is yours.
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for notable changes. Run `./install.sh --reinstall` to pull updates into kit-owned files.

## License

MIT
