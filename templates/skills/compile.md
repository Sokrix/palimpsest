# Compile — Session → topical wiki notes + save

Synthesizes the current session into two complementary outputs: (1) structured topical notes (Context, Intelligence, Resources) that canonicalize durable knowledge, and (2) a daily note that captures the functional narrative of the session — what we did, why, what we explored, what we converged on, what we learned, what blocked us. Use at the end of a deep session worth canonicalizing. For light sessions, use `/save` instead.

`/compile` is a strict superset of `/save`. Never run both.

> `<vault>` = `{{VAULT_PATH}}`

## Steps

### 1. Read the index

Read `<vault>/wiki/index.md` to identify existing notes — prefer enriching over creating duplicates.

### 2. Identify threads

Extract the session's substantive content and classify each thread:

- **Context** — problem framing, project setup, stakeholders, constraints → `<vault>/wiki/Context/`
- **Intelligence** — analyses, data findings, decisions and reasoning, alternatives weighed → `<vault>/wiki/Intelligence/`
- **Resources** — reusable patterns, templates, snippets, repo maps → `<vault>/wiki/Resources/`

If a thread does not fit any of these categories, ask the user where it belongs before proceeding.

### 3. Propose a compilation plan

Show the user a structured plan:

```
## Compilation plan

### To create
- <vault>/wiki/Intelligence/<note>.md — <one-line summary>
- <vault>/wiki/Context/<note>.md — <one-line summary>

### To enrich
- <vault>/wiki/Resources/<existing-note>.md — <what is being added>
```

Wait for explicit validation before writing. NEVER write topical notes without the user's OK.

### 4. Write the topical notes

For each note in the validated plan, apply this frontmatter:

```yaml
---
date: YYYY-MM-DD
tags: []
type: context | research | resource | note
status: active
---
```

Note content structure:

- **Summary** — 2-3 sentences, the essentials
- **Key concepts** — bullet points of the main ideas
- **Details** — structured sections if the content is rich
- **Links** — `[[wiki links]]` to related existing notes

For each note, verify at least one incoming or outgoing wiki link — no orphans.

### 5. Update the index

Register every new note in `<vault>/wiki/index.md` under the appropriate category.

### 6. Create the daily note

Create or update `<vault>/wiki/Daily/YYYY-MM-DD.md` (today's date).

The daily note is the **functional narrative** of the session — the human-readable story of what happened, not a changelog of file changes. Write it as prose where prose helps, bullets where bullets help. Keep it grounded: name what we actually did, not what we might do later.

```yaml
---
date: YYYY-MM-DD
tags: [daily]
type: daily
status: active
---
```

Content (use the sections that apply — skip what is empty rather than padding):

- **Context** — what problem or goal we were tackling this session, and why it mattered now. Frame it functionally (the user need, the question, the symptom) rather than technically.
- **Exploration** — the paths and options we considered, including ones we discarded. Capture the *thinking*: what looked promising, what we ruled out, what tradeoffs surfaced. Dead ends belong here — they are part of the record.
- **Convergence** — what we settled on and the reasoning. If we did not converge, say so explicitly and note what is still open.
- **Learnings** — what emerged that we did not know going in: surprises, mental-model shifts, mechanisms understood, assumptions invalidated.
- **Blockers** — what slowed us down, what we could not resolve, what is waiting on someone or something else.
- **Actions** — concrete things produced or changed this session, with `[[wiki links]]` to every topical note created or enriched in step 4. Keep this short — the narrative above already tells the story.
- **Next** — what still needs to happen, in priority order. One line per item.

If the session was multi-threaded (several distinct problems tackled), structure the narrative thread by thread rather than mashing them together. A clear header per thread, then the relevant sections under each.

Length should match session depth. A short focused session yields a short note; a sprawling exploratory session yields a longer one. Do not artificially compress a rich session into bullet points, and do not pad a thin session with filler.

### 7. Write to the log

Append to `<vault>/wiki/log.md`:

```
YYYY-MM-DD HH:MM — Compile: created N topical notes, enriched M, daily note updated
```

### 8. Report

Display:

```
## Compile complete

- Topical notes created: N (list with paths)
- Topical notes enriched: M (list with paths)
- Daily note: <vault>/wiki/Daily/YYYY-MM-DD.md
- Index updated: yes/no
- Log updated: yes/no
```

## Rules

- NEVER write topical notes without explicit validation of the compilation plan
- NEVER modify `<vault>/raw/`
- NEVER create an orphan note — every new note must link or be linked
- NEVER delete existing content in a daily note — only add
- Prefer enriching existing notes over creating duplicates
- Wiki notes are syntheses, not transcripts — reformulate, structure, extract value
- The daily note (step 6) executes directly without asking for confirmation
