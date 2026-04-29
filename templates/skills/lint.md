# Lint — Vault health-check

Verifies the integrity and consistency of the vault. To be run periodically (1x/week recommended).

> `<vault>` = `{{VAULT_PATH}}`

## Checks

### 1. Orphan notes

Scan all notes in `<vault>/wiki/`. For each note, verify that at least one incoming or outgoing wiki link exists. List the orphans.

### 2. Broken links

Scan all `[[wiki links]]` in the vault. Verify that each link points to an existing note. List the broken links.

### 3. Index up to date

Compare the list of notes in `<vault>/wiki/` with the entries in `<vault>/wiki/index.md`. List the notes missing from the index.

### 4. Index size

Count the lines of `<vault>/wiki/index.md`. If > 200 lines, recommend creating sub-indexes by category.

### 5. Frontmatter consistency

Verify that each wiki note has valid frontmatter with the mandatory fields: date, tags, type, status.

## Report

Display:

```
## Lint complete

### Orphans: X
- list of notes without links

### Broken links: X
- [[Link]] in note.md → target note does not exist

### Incomplete index: X missing notes
- list of notes missing from the index

### Index: XX lines (OK | WARNING > 200)

### Invalid frontmatter: X
- list of notes with missing fields

### Recommended actions
- [ ] Add links toward orphan notes
- [ ] Fix or remove broken links
- [ ] Add missing notes to the index
```

### Write to the log

Append to `<vault>/wiki/log.md`:

```
YYYY-MM-DD HH:MM — Lint: X orphans, X broken links, X missing from index
```

## Rules

- NEVER auto-correct — propose corrections, the user validates
- NEVER modify `<vault>/raw/`
- NEVER delete notes — propose archiving (`status: archive`)
