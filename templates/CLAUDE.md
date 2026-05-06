## palimpsest

The user maintains a palimpsest vault (Obsidian + Karpathy 3-layer LLM Wiki architecture) at:

```
{{VAULT_PATH}}
```

In skill files and below, `<vault>` is shorthand for this absolute path.

This vault is the user's persistent memory — decisions, research, projects, patterns, session recaps. Consult it when relevant. It is accessible from any Claude Code session via the global skills (`/prime`, `/save`, `/ingest`, `/query`, `/lint`).

### Absolute rules (always)

1. NEVER modify, rename or move a file in `<vault>/raw/` — it is the human space, immutable
2. NEVER create an orphan note in `<vault>/wiki/{Context,Intelligence,Resources}/` — every topical note has at least one incoming or outgoing wiki link
3. NEVER write in the vault outside a skill — direct edits to `<vault>/raw/`, `<vault>/sessions/`, or `<vault>/wiki/` are forbidden, even when explicitly asked. Route every write through `/save` or `/ingest`.
4. NEVER delete a wiki note — archive by changing `status: archive`
5. NEVER invent information that is absent from the vault — flag when data is missing

### Vault layout

```
<vault>/
├── raw/         # external artifacts dropped by the human (immutable)
├── sessions/    # session recaps written by /save (staging for /ingest)
├── log.md       # append-only operations journal
└── wiki/        # canonized knowledge — the only durable layer
    ├── index.md # steering panel listing topical notes by bucket
    ├── Context/
    ├── Intelligence/
    └── Resources/
```

### 3-layer architecture (Karpathy LLM Wiki)

| Layer            | Path                                       | Owner | Rule                                                                           |
| ---------------- | ------------------------------------------ | ----- | ------------------------------------------------------------------------------ |
| Layer 1 — Inputs | `<vault>/raw/`, `<vault>/sessions/`        | Human / LLM staging | Two staging areas. `raw/` is immutable external content; `sessions/` is `/save`'s output, awaiting ingestion. |
| Layer 2 — Wiki   | `<vault>/wiki/`                            | LLM   | Canonized knowledge. Topical notes + index. The LLM owns quality.              |
| Layer 3 — Schema | `~/.claude/CLAUDE.md` (this file)          | Human | Rules, conventions, vault path.                                                |

`log.md` lives at the vault root because it's audit metadata, not knowledge.

### How it works

- **`<vault>/raw/`** — the human dumps external content here (articles, PDFs, notes). The LLM reads but NEVER touches.
- **`<vault>/sessions/`** — `/save` writes a per-session human-readable recap here at the end of every working session. Each file carries an `ingested:` flag flipped to a timestamp once `/ingest` has promoted its durable bits.
- **`<vault>/wiki/`** — the canonized knowledge layer. Topical notes only.
- **`<vault>/wiki/index.md`** — steering panel. The LLM reads this FIRST to navigate the wiki without scanning every folder.
- **`<vault>/log.md`** — append-only chronological journal of vault operations. Every skill invocation adds an entry.

`/ingest` canonicalizes content from both staging areas (`raw/` and `sessions/`) into the topical buckets.

### Available operations

| Command       | Role                                                                            | When to use it                                                              |
| ------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `/prime`      | Load vault context at the start of a session                                    | Start of any session that will work with the vault                          |
| `/save`       | Capture the current session as a human-readable recap                           | End of every session                                                        |
| `/ingest`     | Canonicalize durable content from `raw/` and `sessions/` into the topical buckets | After dropping files in `raw/`, or when accumulated sessions deserve promotion |
| `/query`      | Deep search across the wiki                                                     | To find information in the vault                                            |
| `/lint`       | Health-check of the vault                                                       | Periodically (1x/week recommended)                                          |

`/save` and `/ingest` are complementary, not alternatives:
- `/save` runs every session — it captures what happened.
- `/ingest` runs when you want durable knowledge promoted into Context/Intelligence/Resources, whether the source is `raw/` or accumulated session recaps.

You can run several `/save`s before a single `/ingest`. Session files are tracked with an `ingested:` frontmatter field so `/ingest` only processes new ones.

### Obsidian conventions

- **Wiki links**: `[[Note name]]` for any internal link
- **Embeds**: `![[Note]]` to include content
- **Mandatory YAML frontmatter** on every wiki note:

```yaml
---
date: YYYY-MM-DD
tags: []
type: context | intelligence | resource | session
status: active | archive
---
```

### wiki/ structure — the three topical buckets

Topical notes live in one of three buckets. The bucket is decided by the question the note answers:

#### `<vault>/wiki/Context/` — *What's the situation?*

The stable backdrop of the work. What *is*, not what we think about it.

- User profile, role, personal constraints
- Project briefs, objectives, stakeholders
- Recurring environment: tech stack, habitual tools, working conventions
- Anything that frames multiple sessions

**Test**: If I read this in 6 months, does it tell me *where I stand* rather than *what I concluded*?

#### `<vault>/wiki/Intelligence/` — *What did we conclude?*

The product of reasoning. Conclusions, decisions, analyses.

- Decisions and their justification ("we chose X over Y because Z")
- Research with a verdict (benchmarks, comparisons, evaluations)
- Analyses that reach a point of view
- Structured learnings produced by reflection

**Test**: Is there an *opinion* or *conclusion* in this note?

#### `<vault>/wiki/Resources/` — *What can I reuse as-is?*

Self-contained artifacts, ready to grab.

- Templates, snippets, prompts
- Checklists, frameworks, recipes
- Repo maps, architecture diagrams
- Documented patterns (the pattern itself, not its analysis)

**Test**: Would I copy-paste this into another context?

#### Disambiguation — common edge cases

- **Research that produced a decision** → `Intelligence` (the value is the reasoning)
- **Research that produced a reusable framework** → `Resources` (the value is the artifact); link back to `Intelligence` for the rationale
- **Project brief containing decisions** → split: `Context` for the brief, `Intelligence` for the decisions, cross-linked
- **Pattern we discovered** → `Resources` (the pattern), with a link to `Intelligence` if the analysis is worth keeping
- **Note fitting nowhere** → ask the user before writing

#### Non-bucket folders and files

| Path                    | Content                                                                                  |
| ----------------------- | ---------------------------------------------------------------------------------------- |
| `<vault>/sessions/`     | Per-session recaps written by `/save`. Chronological, not classified — staging for `/ingest`. |
| `<vault>/wiki/index.md` | Steering panel listing topical notes by bucket.                                          |
| `<vault>/log.md`        | Append-only operations journal at the vault root (audit metadata, not knowledge).        |

Folders are created as needed. NEVER create an empty folder.

### Working from outside the vault

The skills work from any Claude Code session via the absolute paths above. You do not need to `cd` into the vault directory to invoke them. The same five commands are also available in GitHub Copilot (VS Code) — both agents write to the same vault following the same rules.

If a session in another workspace produces wiki-worthy content, capture it via `/save` (it lands in `sessions/`) and let `/ingest` promote the durable bits later. `<vault>/raw/` is reserved for external artifacts (articles, PDFs, notes), not session output.
