# Ingest — raw/ to wiki/

Compiles the raw sources of the vault into structured wiki notes.

> `<vault>` = `{{VAULT_PATH}}`

## Steps

### 1. Scan raw/

List all files in `<vault>/raw/clippings/`, `<vault>/raw/docs/`, `<vault>/raw/notes/`.

### 2. Identify untreated files

For each file in `<vault>/raw/`:

- Search in `<vault>/wiki/` for a note whose `source:` frontmatter references this file
- If the wiki note exists and is up to date → skip
- If the file is new → process

### 3. Process each file

1. **Read** the full content of the raw file
2. **Extract** the key concepts, facts, decisions, insights
3. **Decide**: create a new wiki note OR enrich an existing note
   - Existing topic → enrich the corresponding wiki note
   - New topic → create in the right `<vault>/wiki/` folder

### 4. Create or enrich the wiki note

Each wiki note must have this frontmatter:

```yaml
---
date: YYYY-MM-DD
tags: []
type: research | context | resource | note
status: active
source: raw/path/of/file.md
---
```

Note content:

- **Summary** — 2-3 sentences, the essentials
- **Key concepts** — bullet points of the main ideas
- **Details** — structured sections if the content is rich
- **Links** — wiki links to existing related notes

### 5. Cross-reference

For each note created or modified:

- Add `[[wiki links]]` to related notes
- Verify that referenced notes have a back-link

### 6. Update the index

Register each new note in `<vault>/wiki/index.md` under the appropriate category.

### 7. Write to the log

Append to `<vault>/wiki/log.md`:

```
YYYY-MM-DD HH:MM — Ingest: X files scanned, Y new, Z enriched
```

### 8. Report

Display:

```
## Ingest complete

- Files scanned: X
- New: Y (list)
- Enriched: Z (list)
- Skipped: W
- Index updated: yes/no
- Log updated: yes/no
```

## Rules

- NEVER modify, rename or move a file in `<vault>/raw/`
- NEVER create a superficial note — if an article brings nothing new, do not create a note
- Prefer enriching an existing note rather than creating a new one
- Wiki notes are syntheses, not copies — reformulate, structure, extract value
- NEVER create an orphan note — at least one incoming or outgoing wiki link
