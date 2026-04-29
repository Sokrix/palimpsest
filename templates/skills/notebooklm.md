# Notebooklm — Vault to multimedia deliverables

Orchestrates the vault → NotebookLM → deliverable pipeline (podcast, mindmap, study-guide, infographic).
Relies on the Python lib notebooklm-py (github.com/teng-lin/notebooklm-py).

> `<vault>` = `{{VAULT_PATH}}`

## Prerequisites

- Python 3.8+
- `pip install notebooklm-py`
- Google account with access to NotebookLM

## Steps

1. **Selection** — identify the wiki notes in `<vault>/wiki/` to use as sources (via pattern or explicit list)
2. **Notebook** — create or retrieve the corresponding NotebookLM notebook
3. **Sources** — inject each `.md` note as a source in the notebook
4. **Generation** — request from NotebookLM the desired deliverable (audio_overview | mindmap | study_guide | ...)
5. **Download** — retrieve the file and save it in `<vault>/wiki/Resources/`

## Expected output

Deliverable file (MP3 / PDF / JSON / MD depending on type) dropped in `<vault>/wiki/Resources/` with a corresponding index note.

## Rules

- Never overwrite an existing deliverable without explicit confirmation
- Always log the operation in `<vault>/wiki/Daily/{date}.md`
- The sources passed to NotebookLM must be validated wiki notes (not from `<vault>/raw/`)
