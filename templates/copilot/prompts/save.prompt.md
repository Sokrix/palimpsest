---
mode: agent
description: 'Save — End-of-session human-readable recap'
---

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
workspaces: [<workspace>]
ingested: false
---
```

If the file already exists, leave the existing entries untouched and append the new entry at the bottom (after a single blank line of separation). Two frontmatter fields get updated — see step 3.

The `ingested: false` flag marks the recap as awaiting promotion. `/ingest` flips it to a timestamp once processed.

### 3. Update the frontmatter

Two structured fields evolve as new entries land in the file:

#### `workspaces:` — which workspaces this file touches

A list of every distinct workspace label that has an entry in this file. Add `<workspace>` from step 1 if it's not already in the list. Deterministic, no judgment.

```yaml
workspaces: [palimpsest, global]
```

#### `tags:` — what the file is *about*

A merged list with two kinds of label:

1. `session` — always present (it's what the file is)
2. **2–3 topic tags** — what the new entry is actually *about*

Topic tags identify the substantive subjects of the session, picked from the conversation just before writing the entry. Examples: `architecture`, `bucket-rubric`, `obsidian-frontmatter`, `claude-skills`, `tdd`. Conventions:

- Lowercase, hyphenated when multi-word (`bucket-rubric`, not `bucketRubric` or `bucket_rubric`)
- Specific enough to discriminate, not so generic they become noise (`#code` is too vague; `#claude-skills` is good)
- 2–3 tags per entry — more dilutes signal
- Reuse tags that already appear elsewhere in the vault when applicable, to keep the Obsidian graph dense
- Do **not** put workspace names in `tags:` — that's what `workspaces:` is for

**Merging rule**: read the existing `tags:` list, add `session` and the 2–3 new topic tags, then deduplicate. Tags accumulate across the day's entries.

By end of day, a multi-entry file might carry:

```yaml
tags: [session, bucket-rubric, save-skill, obsidian-frontmatter]
workspaces: [palimpsest, global]
```

### 4. Write the entry

Every entry follows the exact same structure. Consistency matters — `/ingest` and the human reader rely on it.

```markdown
## HH:MM — <workspace>

### Context
…

### Goals
…

### Findings
…

### Open questions
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

### 5. Section content — what goes where

Write the recap as a story a human can read in two minutes. The recap is about **the product, the user, and the business** — not about the implementation. Plain prose where prose helps, bullets where bullets help.

#### The "so what" filter

Before writing any sentence, ask: *"Does this matter to the product, the user, or the business?"* If the answer is no, **cut it**. The recap is not a build log, not a code review, not an Xcode autopsy. `git log`, the diff, the PR description, and the codebase already carry the technical record — the recap is the layer above.

**Examples of what to cut, even when true and even when it took real effort:**

- Branch names, commit SHAs, file paths, line numbers
- Library/framework version specifics (`iOS 26.2`, `Swift 6.0`, `react@19`, etc.)
- API or function names from the codebase (`Tab(role: .search)`, `search_names_by_syllables`, `useEffect`)
- Compiler errors, type errors, decoder errors, concurrency warnings
- Migration SQL, schema details, RPC signatures
- Build-system artifacts (`pbxproj`, `package.json`, `Cargo.toml`, etc.)
- "We renamed X to Y" / "we moved A to B" — refactors that didn't change product behavior

**What to keep, even when it sounds product-y at first:**

- Why the user / customer cares about this work — the underlying need or friction
- What the new thing lets the user *do* that they couldn't before
- Trade-offs that shaped the experience (speed vs polish, scope cut, monetization angle)
- Scale or constraint discoveries that changed the trajectory (e.g. "the catalog is 45k rows, not 5k — that forced us to rethink the search architecture") — kept *only* because it changed the plan
- Decisions about brand, voice, navigation, layout, what stays and what goes

A good test: if you read the recap aloud to a non-technical co-founder or a designer, would they follow it without asking "what does X mean?" — if not, it's drifted into the wrong layer.

#### Context

Where we started in product / user terms. The user need, the gap in the experience, the symptom that triggered the work. Not the codebase state.

#### Goals

What we set out to achieve, framed as product outcomes. "Ship a way for users to look up a name by partial spelling" — not "implement the search ViewModel and wire it to the existing pipeline."

#### Findings

What the session actually established. The substantive output, in product / user / business terms: numbers and their shape, segments that moved, what's now true that wasn't before, what shipped, what the answer to the goal turned out to be. For an analysis: the cuts that matter, not the methodology. For a build: what users can now do. For a doc: what's now decided and where.

**Provenance rule — non-negotiable.** Only write here what the session itself **produced or confirmed**. If a claim, number, or pattern came from outside (another team's dashboard, a screenshot, a teammate's quote, a prior analysis) and was not independently verified during the session, it does **not** belong in `Findings` — it goes in `Open questions`. When in doubt, ask: *"Did we compute or confirm this here?"* If the answer is no, demote it. No extrapolation, no plausibility-based inference — report what was looked at, not what would sound right.

Keep it functional, not technical: shape and direction of the answer, not query logic, schema details, or script names.

#### Open questions

What's unresolved at the end of the session and worth carrying forward. Three things land here:

1. **Inputs we received but didn't validate** — claims from another dashboard, a screenshot, a teammate quote that weren't reconciled in-session. Attributed: *"the X dashboard shows Y; not yet aligned."*
2. **Cuts we didn't run** — segments, time windows, breakdowns explicitly out of scope or deferred.
3. **Trajectory shifts** — discoveries that changed the plan and left a follow-up: *"we found the catalog is 10× bigger than estimated, which forces a rethink before going further."*

Pure technical bugs that got fixed in-session do not belong here. If it didn't reshape the work or leave a question hanging, leave it out.

#### Decisions

What was settled and *why*, expressed in product / UX / business terms. "Removed the Vous tab; profile now lives in the top-right of every screen" is the right shape. "Added `Tab(role: .search)` per iOS 26 native API" is the wrong shape — the user-facing decision is "we adopted the native search experience instead of building a custom one"; the API name is implementation noise. One line per decision; capture the alternatives only when the reasoning isn't obvious from the decision itself.

#### Learnings

What changed in your understanding of the **product, the user, the domain, or the business** — not the codebase, not the platform, not your own workflow. *"When two teams disagree on a volume, ask for the exact filter clause first"* is a domain learning that generalises. *"Auto-syncing iOS file groups remove manual project edits"* is platform trivia. *"Real-device screenshots catch design issues"* is workflow meta. Both are out.

If the only learnings would be technical or workflow-flavoured, leave the section empty.

### 6. Multiple distinct topics in a single session

If the session covered two unrelated problems, write **two separate entries** — each with its own `## HH:MM — <workspace>` header, even if the timestamps are close. Do not nest threads under a single entry.

### 7. Length

Match the depth of the session. A short focused session yields a short entry; a sprawling one yields a longer one. Don't artificially compress, don't pad.

### 8. Write to the log

Append to `<vault>/log.md`:

```
YYYY-MM-DD HH:MM — Save: session recap created/updated (workspace: <workspace>)
```

### 9. Confirmation

Display a one-line summary:

```
Saved → <vault>/sessions/YYYY-MM-DD.md  ## HH:MM — <workspace>  (ingested: false)
```

## Rules

- NEVER delete existing content in a session file — only add
- NEVER include implementation noise: branch names, commit SHAs, file paths, line numbers, library or API names, type errors, build artifacts, or any sentence that could equally appear in a `git log`. Sessions sit at the **product / user / business** layer; the technical record lives elsewhere
- NEVER touch `<vault>/raw/`
- NEVER promote content to `Context/`, `Intelligence/`, or `Resources/` — that's `/ingest`'s job
- NEVER deviate from the entry structure (H2 header, H3 sub-sections in fixed order)
- ALWAYS write the recap in English, regardless of the session's working language. The vault is long-term memory — consistent language wins over fidelity to source
- NEVER promote unverified inputs to `Findings` — claims from external dashboards, screenshots, or teammates that weren't independently confirmed during the session belong in `Open questions`, attributed
- A short, sharp recap with no tech fluff beats a long, thorough one drowning in it. When in doubt, cut
- Execute directly without asking for confirmation
