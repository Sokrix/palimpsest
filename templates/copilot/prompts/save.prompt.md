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

#### Process & workflow

The *shape* of the session at the human level: how we framed the problem, how many design rounds we went through, what we prototyped versus argued about, what we mocked before building. Skip the implementation order, the file moves, the build steps. If a tool or technique genuinely shaped the direction (e.g. "we mocked it as static HTML before touching native code so we could iterate visually"), keep that sentence — it tells the story. Skip the rest.

#### Blockers & workarounds

Blockers worth recording are the ones that **changed the product trajectory** — a scale realization, a platform limitation that forced a redesign, a discovery about user behaviour. Pure technical bugs (decoder errors, concurrency warnings, missing imports) do not belong here. If the blocker reshaped the plan, write it that way: "we discovered the catalog is 10x larger than estimated, which forced us to abandon client-side search and go server-side." If it was just a thing that broke and got fixed, leave it out.

#### Decisions

What was settled and *why*, expressed in product / UX / business terms. "Removed the Vous tab; profile now lives in the top-right of every screen" is the right shape. "Added `Tab(role: .search)` per iOS 26 native API" is the wrong shape — the user-facing decision is "we adopted the native search experience instead of building a custom one"; the API name is implementation noise. One line per decision; capture the alternatives only when the reasoning isn't obvious from the decision itself.

#### Learnings

What changed in your understanding of the **product, the user, the workflow, or the business** — not what you learned about the codebase or the platform. "Real-device screenshots catch design issues that mockups miss" is a workflow learning. "Auto-syncing iOS file groups remove the need for manual project edits" is platform trivia and does not belong. If the only learnings are technical, leave the section empty.

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
- A short, sharp recap with no tech fluff beats a long, thorough one drowning in it. When in doubt, cut
- Execute directly without asking for confirmation
