# Query — Deep search in the wiki

Searches and synthesizes information from the vault.

> `<vault>` = `{{VAULT_PATH}}`

## Steps

### 1. Read the index

Read `<vault>/wiki/index.md` to identify which category and which note is most likely to contain the answer.

### 2. Navigate

Open the identified wiki note. If the answer requires several notes, read them all.

### 3. Synthesize

Formulate a structured answer based solely on the wiki content.

### 4. Propose enrichment

If the search produces a useful new synthesis (cross-referencing several notes, new conclusion):

- Propose to the user to create or enrich a wiki note with this synthesis
- NEVER write without explicit validation from the user

### 5. Write to the log

Append to `<vault>/wiki/log.md`:

```
YYYY-MM-DD HH:MM — Query: "question asked" → wiki/path/note.md
```

## Rules

- NEVER invent information absent from the wiki — if the data does not exist, say so clearly
- NEVER scan all wiki files — use the index as the entry point
- NEVER modify `<vault>/raw/`
- Always cite the source (wiki note name) in the answer
