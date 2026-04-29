# Ingest — Canonicalize raw/ and Daily/ into the topical buckets

Promotes durable content from the two staging areas — `<vault>/raw/` (external artifacts) and `<vault>/wiki/Daily/` (session recaps written by `/save`) — into the three topical buckets: `Context/`, `Intelligence/`, `Resources/`.

> `<vault>` = `{{VAULT_PATH}}`

The classification rubric for the three buckets lives in `~/.claude/CLAUDE.md` under "wiki/ structure — the three topical buckets". Apply it strictly. When in doubt, ask the user before writing.

## Steps

### 1. Read the index

Read `<vault>/wiki/index.md` first — it tells you what topical notes already exist so you can prefer enriching over creating duplicates.

### 2. Scan the staging areas

**`<vault>/raw/`**: list files in `clippings/`, `docs/`, `notes/`.

For each raw file, check whether a wiki note already references it via `source:` frontmatter.
- Already referenced and unchanged → skip
- New or modified → process

**`<vault>/wiki/Daily/`**: list daily notes.

For each daily, check the `ingested:` frontmatter field.
- `ingested:` is a timestamp (already processed) → skip
- `ingested: false` (or missing) → process

### 3. Report what you found

Before writing anything, summarize what's pending:

```
## Pending ingestion

### From raw/
- raw/clippings/<file>.md — <one-line gist>
- raw/docs/<file>.pdf — <one-line gist>

### From Daily/
- Daily/YYYY-MM-DD.md — <one-line gist of the session>
```

If nothing is pending in either source, stop here and say so.

### 4. Propose a promotion plan

For each pending source, classify the durable content into the three buckets using the CLAUDE.md rubric. Show a single consolidated plan:

```
## Promotion plan

### To create
- Context/<note>.md — <one-line summary> ← from <source>
- Intelligence/<note>.md — <one-line summary> ← from <source>

### To enrich
- Resources/<existing-note>.md — <what's being added> ← from <source>

### Skipped (no durable content)
- Daily/YYYY-MM-DD.md — purely procedural session, nothing to promote
```

Wait for explicit user validation before writing. NEVER write topical notes without the user's OK.

### 5. Write the topical notes

For each note in the validated plan:

```yaml
---
date: YYYY-MM-DD
tags: []
type: context | intelligence | resource
status: active
source: raw/path/of/file.md          # if from raw/
sources: [Daily/YYYY-MM-DD.md, ...]  # if from one or more dailies
---
```

A note may carry both `source:` and `sources:` if it's enriched from both kinds of staging area over time. Use a list (`sources:`) for daily notes since several may feed the same topical note.

Note content structure:

- **Summary** — 2-3 sentences, the essentials
- **Key concepts** — the main ideas, bulleted
- **Details** — structured sections if the content warrants
- **Links** — `[[wiki links]]` to related notes

For each note, verify at least one incoming or outgoing wiki link — no orphans.

### 6. Cross-reference

For every note created or enriched, add `[[wiki links]]` to related existing notes and verify back-links exist.

### 7. Update the index

Register each new topical note in `<vault>/wiki/index.md` under its bucket. Don't index daily notes — they're chronological, not topical.

### 8. Mark sources as ingested

**Daily notes**: update the `ingested:` frontmatter field to today's timestamp:

```yaml
ingested: YYYY-MM-DD HH:MM
```

This is the only modification to a daily note allowed outside `/save`. Do not touch the body.

**Raw files**: do nothing — `raw/` is immutable. The link is tracked via the `source:` field on the topical note.

### 9. Write to the log

Append to `<vault>/wiki/log.md`:

```
YYYY-MM-DD HH:MM — Ingest: R raw + D dailies processed, N notes created, M enriched
```

### 10. Report

```
## Ingest complete

- raw/ scanned: X (Y processed, Z skipped)
- Daily/ scanned: X (Y processed, Z skipped)
- Topical notes created: N (list with paths)
- Topical notes enriched: M (list with paths)
- Index updated: yes/no
- Log updated: yes/no
```

## Rules

- NEVER write topical notes without explicit validation of the promotion plan
- NEVER modify, rename, or move a file in `<vault>/raw/`
- NEVER modify the body of a daily note — only the `ingested:` frontmatter field is allowed
- NEVER create a superficial note — if a source brings nothing durable, skip it (and say so in the plan)
- NEVER create an orphan note — every topical note must link or be linked
- Prefer enriching an existing note over creating a duplicate
- Topical notes are syntheses, not transcripts — reformulate, structure, extract value
- Apply the bucket rubric from `~/.claude/CLAUDE.md` strictly; ask the user when content fits no bucket
