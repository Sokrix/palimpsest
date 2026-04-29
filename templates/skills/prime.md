# Prime — Context loading

Loads the vault context at the start of every Claude Code session.

> `<vault>` = `{{VAULT_PATH}}`

The global vault rules and schema are loaded automatically from `~/.claude/CLAUDE.md` — `/prime` does not need to read them.

## Steps

1. **Read `<vault>/wiki/index.md`** — the wiki's steering panel.
2. **Read the latest session recap** in `<vault>/sessions/` — the summary of the previous session.

## Expected output

Confirm what was loaded by summarizing:

- Number of categories populated in the index
- Last session recap read (date)
- Key points from the previous session

## Rules

- NEVER write in the vault during `/prime` — it is a read-only operation
- NEVER scan all wiki files — use the index as the entry point
- If the index does not exist or is empty, flag it to the user
