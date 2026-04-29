# Save — Session recap

Captures the current session as a human-readable session recap. Run at the end of every session. Pair with `/ingest` later when accumulated session recaps deserve promotion to topical notes.

> `<vault>` = `{{VAULT_PATH}}`

## Steps

### 1. Detect the workspace

Determine the workspace label from the current working directory. The label appears in every section header so a future reader can tell at a glance what the session was about.

```bash
git -C "$PWD" rev-parse --show-toplevel 2>/dev/null
```

- **Inside a git repository** → workspace = `basename` of the repo root (e.g. `palimpsest`, `apps`)
- **Otherwise** → workspace = `global`

Use exactly that label, lowercase, no spaces. No judgment calls — the detection is deterministic.

### 2. Open or create the session file

File: `<vault>/sessions/YYYY-MM-DD.md` (today's date).

If the file does not exist, create it with this frontmatter:

```yaml
---
date: YYYY-MM-DD
tags: [session]
type: session
status: active
ingested: false
---
```

If the file already exists, leave the frontmatter and existing content untouched. Append the new entry at the bottom (after a single blank line of separation).

The `ingested: false` flag marks the recap as awaiting promotion. `/ingest` flips it to a timestamp once processed.

### 3. Write the entry

Every entry follows the exact same structure. Consistency matters — `/ingest` and the human reader rely on it.

```markdown
## HH:MM — <workspace>

### Context
…

### Goals
…

### Process & workflow
…

### Blockers & workarounds
…

### Decisions
…

### Learnings
…
```

Rules for the structure:

- **Header**: always `## HH:MM — <workspace>`. The time is the session's start time (or, if unknown, the time of `/save`). The workspace is the label from step 1.
- **Sub-sections**: always H3, always in this order, always with these exact titles. Skip a section entirely (header included) if it has no content — never leave empty headers.
- **No other top-level (`##`) headers inside the entry** — those are reserved for entry boundaries.

### 4. Section content — what goes where

Write the recap as a story a human can read in two minutes. Plain prose where prose helps, bullets where bullets help. No jargon, no copy-paste of code, no file diffs — `git log` already does that.

#### Context

Where we started. What was already on the table coming into the session — the situation, the user need, the symptom that triggered the work. Frame it functionally, not technically.

#### Goals

What we set out to achieve in this session. One or two sentences, in plain language.

#### Process & workflow

How we actually went about it. The path we took, the order we tackled things, the methods we used. Capture the *shape* of the session — was it linear, exploratory, iterative? Did we prototype, debate, then commit?

#### Blockers & workarounds

What slowed us down or stopped us. For each blocker, name what unblocked it (or what we're still waiting on). Dead ends and detours belong here.

#### Decisions

What was settled and *why*. One line per decision. Capture the alternatives considered when the reasoning isn't obvious. If we deferred a decision, say so explicitly.

#### Learnings

What we know now that we didn't going in. Surprises, mental-model shifts, assumptions invalidated, mechanisms understood. Avoid restating decisions — learnings are the things that will outlast this specific task.

### 5. Multiple distinct topics in a single session

If the session covered two unrelated problems, write **two separate entries** — each with its own `## HH:MM — <workspace>` header, even if the timestamps are close. Do not nest threads under a single entry.

### 6. Length

Match the depth of the session. A short focused session yields a short entry; a sprawling one yields a longer one. Don't artificially compress, don't pad.

### 7. Write to the log

Append to `<vault>/log.md`:

```
YYYY-MM-DD HH:MM — Save: session recap created/updated (workspace: <workspace>)
```

### 8. Confirmation

Display a one-line summary:

```
Saved → <vault>/sessions/YYYY-MM-DD.md  ## HH:MM — <workspace>  (ingested: false)
```

## Rules

- NEVER delete existing content in a session file — only add
- NEVER write technical fluff (file paths, diffs, raw command output) — sessions are for humans
- NEVER touch `<vault>/raw/`
- NEVER promote content to `Context/`, `Intelligence/`, or `Resources/` — that's `/ingest`'s job
- NEVER deviate from the entry structure (H2 header, six H3 sub-sections in fixed order)
- Execute directly without asking for confirmation
