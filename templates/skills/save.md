# Save — Session save (light)

Saves the state of the current session — daily note only. For deep sessions worth canonicalizing into topical notes, use `/compile` instead. Never run both.

> `<vault>` = `{{VAULT_PATH}}`

## Steps

### 1. Daily note

Create or update `<vault>/wiki/Daily/YYYY-MM-DD.md` (today's date):

```yaml
---
date: YYYY-MM-DD
tags: [daily]
type: daily
status: active
---
```

Content:

- **Actions** — what was done this session (bullet points)
- **Decisions** — choices made and why
- **Next step** — what remains to be done

### 2. Update the index

If new wiki notes were created during the session, register them in `<vault>/wiki/index.md`.

### 3. Write to the log

Append to `<vault>/wiki/log.md`:

```
YYYY-MM-DD HH:MM — Save: daily note created/updated, index verified
```

### 4. Confirmation

Display a short summary of what was saved.

## Rules

- NEVER delete existing content in a daily note — only add
- NEVER modify `<vault>/raw/` during `/save`
- NEVER create an orphan note
- Execute directly without asking for confirmation
