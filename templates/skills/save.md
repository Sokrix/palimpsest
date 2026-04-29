# Save — Session recap

Captures the current session as a human-readable daily note. Run at the end of every session. Pair with `/ingest` later when accumulated dailies deserve promotion to topical notes.

> `<vault>` = `{{VAULT_PATH}}`

## Steps

### 1. Write or update the daily note

File: `<vault>/wiki/Daily/YYYY-MM-DD.md` (today's date).

If the file already exists, append a new dated section at the bottom — never delete or rewrite earlier content from the same day.

Frontmatter:

```yaml
---
date: YYYY-MM-DD
tags: [daily]
type: daily
status: active
ingested: false
---
```

The `ingested: false` flag marks the daily as awaiting promotion. `/ingest` flips it to a timestamp once processed.

### 2. Content — six sections

Write the recap as a story a human can read in two minutes. Plain prose where prose helps, bullets where bullets help. No jargon, no copy-paste of code, no file diffs — `git log` already does that.

If a section is empty, skip it rather than padding.

#### 1. Context

Where we started. What was already on the table coming into the session — the situation, the user need, the symptom that triggered the work. Frame it functionally, not technically.

#### 2. Goals

What we set out to achieve in this session. One or two sentences, in plain language.

#### 3. Process & workflow

How we actually went about it. The path we took, the order we tackled things, the methods we used. Capture the *shape* of the session — was it linear, exploratory, iterative? Did we prototype, debate, then commit?

#### 4. Blockers & workarounds

What slowed us down or stopped us. For each blocker, name what unblocked it (or what we're still waiting on). Dead ends and detours belong here.

#### 5. Decisions

What was settled and *why*. One line per decision. Capture the alternatives considered when the reasoning isn't obvious. If we deferred a decision, say so explicitly.

#### 6. Learnings

What we know now that we didn't going in. Surprises, mental-model shifts, assumptions invalidated, mechanisms understood. Avoid restating decisions — learnings are the things that will outlast this specific task.

### 3. Multi-thread sessions

If the session covered several distinct problems, structure each thread under its own header (`## Thread name`) and place the six sections beneath. Don't mash unrelated threads into a single narrative.

### 4. Length

Match the depth of the session. A short focused session yields a short note; a sprawling one yields a longer one. Don't artificially compress, don't pad.

### 5. Write to the log

Append to `<vault>/wiki/log.md`:

```
YYYY-MM-DD HH:MM — Save: daily note created/updated
```

### 6. Confirmation

Display a one-line summary:

```
Saved → <vault>/wiki/Daily/YYYY-MM-DD.md (ingested: false)
```

## Rules

- NEVER delete existing content in a daily note — only add
- NEVER write technical fluff (file paths, diffs, raw command output) — the daily is for humans
- NEVER touch `<vault>/raw/`
- NEVER promote content to `Context/`, `Intelligence/`, or `Resources/` — that's `/ingest`'s job
- Execute directly without asking for confirmation
