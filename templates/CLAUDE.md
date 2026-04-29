## palimpsest

The user maintains a palimpsest vault (Obsidian + Karpathy 3-layer LLM Wiki architecture) at:

```
{{VAULT_PATH}}
```

In skill files and below, `<vault>` is shorthand for this absolute path.

This vault is the user's persistent memory — decisions, research, projects, patterns, daily logs. Consult it when relevant. It is accessible from any Claude Code session via the global skills (`/prime`, `/save`, `/ingest`, `/query`, `/lint`, `/notebooklm`).

### Absolute rules (always)

1. NEVER modify, rename or move a file in `<vault>/raw/` — it is the human space, immutable
2. NEVER create an orphan note in `<vault>/wiki/{Context,Intelligence,Resources}/` — every topical note has at least one incoming or outgoing wiki link
3. NEVER write in the vault outside a skill — direct edits to `<vault>/raw/` or `<vault>/wiki/` are forbidden, even when explicitly asked. Route every write through `/save`, `/ingest`, or `/notebooklm`.
4. NEVER delete a wiki note — archive by changing `status: archive`
5. NEVER invent information that is absent from the vault — flag when data is missing

### 3-layer architecture (Karpathy LLM Wiki)

| Layer            | Path                              | Owner | Rule                                                |
| ---------------- | --------------------------------- | ----- | --------------------------------------------------- |
| Layer 1 — Raw    | `<vault>/raw/`                    | Human | Immutable. External artifacts (clippings, docs, notes). |
| Layer 2 — Wiki   | `<vault>/wiki/`                   | LLM   | Compiled. Concepts, syntheses, index, log.          |
| Layer 3 — Schema | `~/.claude/CLAUDE.md` (this file) | Human | Rules, conventions, vault path.                     |

### How it works

- **`<vault>/raw/`** — the human dumps external content here (articles, PDFs, notes). The LLM reads but NEVER touches.
- **`<vault>/wiki/`** — compiled knowledge: topical notes, daily journal, index, log. The LLM is responsible for quality.
- **`<vault>/wiki/index.md`** — steering panel. The LLM reads this FIRST to navigate the wiki without scanning every folder.
- **`<vault>/wiki/log.md`** — append-only chronological journal. Every operation adds an entry.

Two staging areas feed the topical notes:
- `<vault>/raw/` — external artifacts dropped by the human
- `<vault>/wiki/Daily/` — session recaps written by `/save`

`/ingest` canonicalizes both into the topical buckets (Context, Intelligence, Resources).

### Available operations

| Command       | Role                                                                         | When to use it                                                              |
| ------------- | ---------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| `/prime`      | Load vault context at the start of a session                                 | Start of any session that will work with the vault                          |
| `/save`       | Capture the current session as a human-readable daily recap                  | End of every session                                                        |
| `/ingest`     | Canonicalize durable content from `raw/` and `Daily/` into the topical buckets | After dropping files in `raw/`, or when accumulated dailies deserve promotion |
| `/query`      | Deep search across the wiki                                                  | To find information in the vault                                            |
| `/lint`       | Health-check of the vault                                                    | Periodically (1x/week recommended)                                          |
| `/notebooklm` | Vault → NotebookLM → multimedia deliverable                                  | To generate podcasts, mindmaps, guides from the wiki                        |

`/save` and `/ingest` are complementary, not alternatives:
- `/save` runs every session — it captures what happened.
- `/ingest` runs when you want durable knowledge promoted into Context/Intelligence/Resources, whether the source is `raw/` or accumulated dailies.

You can run several `/save`s before a single `/ingest`. Dailies are tracked with an `ingested:` frontmatter field so `/ingest` only processes new ones.

### Obsidian conventions

- **Wiki links**: `[[Note name]]` for any internal link
- **Embeds**: `![[Note]]` to include content
- **Mandatory YAML frontmatter** on every wiki note:

```yaml
---
date: YYYY-MM-DD
tags: []
type: context | intelligence | resource | daily
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

#### Non-bucket folders

| Folder                  | Content                                                                                  |
| ----------------------- | ---------------------------------------------------------------------------------------- |
| `<vault>/wiki/Daily/`   | Per-session recaps written by `/save`. Chronological, not classified — staging for `/ingest`. |
| `<vault>/wiki/index.md` | Steering panel listing topical notes by bucket.                                          |
| `<vault>/wiki/log.md`   | Append-only operations log.                                                              |

Folders are created as needed. NEVER create an empty folder.

### Working from outside the vault

The skills work from any Claude Code session via the absolute paths above. You do not need to `cd` into the vault directory to invoke them.

If a session in another workspace produces wiki-worthy content, capture it via `/save` (it lands in `Daily/`) and let `/ingest` promote the durable bits later. `<vault>/raw/` is reserved for external artifacts (articles, PDFs, notes), not session output.
