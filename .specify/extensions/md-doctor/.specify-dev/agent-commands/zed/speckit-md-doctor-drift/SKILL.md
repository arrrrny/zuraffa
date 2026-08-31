---
name: speckit-md-doctor-drift
description: 'Re-evaluate since the last run: compute the git/.memsearch/TDD delta, re-score previously graded files in light of what changed, and report which past suggestions were resolved or are now stale/false'
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: github-spec-kit
  source: md-doctor:commands/speckit.md-doctor.drift.md
---

# MD Doctor — Drift (re-evaluate)

The "run it a week later" command. It loads the previous run's facts and ground
truth, computes exactly what changed since then (git commits, changed `.md` files,
new `.memsearch` records, refreshed TDD verdicts), and re-grades every previously
scored file so you can say what is newly true, what is newly false, and which past
suggestions were resolved or ignored.

## User Input

```text
$ARGUMENTS
```

Recognized modifiers:

- `--path <subdir>`: re-evaluate only one subtree.
- `--json`: emit the delta + re-graded facts as JSON.

With no input, re-evaluate the whole repo against the last run.

## Preconditions

`init` or a prior `scan` must have run (there must be
`.specify/md-doctor/state/last-run.json` and `facts.json`). If missing, stop and tell
the user to run `/speckit.md-doctor.init` first.

## Workflow

### Phase 1: Compute the delta

Forward the recognized `--path` value from `$ARGUMENTS`, shell-quoted as one
argument; omit it when absent:

```bash
bash .specify/extensions/md-doctor/scripts/bash/md-doctor.sh drift --json \
  --path "$PATH_ARG" > /tmp/md-doctor-delta.json
```

(Dev fallback: `bash <extension-root>/md-doctor/scripts/bash/md-doctor.sh drift --json`.)

The delta contains:
- `prev_run.head` / `prev_run.timestamp` — the last anchored run.
- `commits_since[]` — commits between the last run's HEAD and current HEAD: what was
  **implemented** since.
- `md_changed_since[]` — `.md` files git changed in that span.
- `memsearch_files_since[]` — new daily records: what agents actually did.

Read the delta. Open any `memsearch_files_since` and skim `commits_since` subjects —
these are the new ground truth since last week.

### Phase 2: Re-score previously graded files

Load `.specify/md-doctor/state/facts.json` (last run's grades). For each file:

- If it is in `md_changed_since`, its content changed → re-extract claims and
  re-grade from scratch against the new ground truth.
- If a `commits_since` / `memsearch_files_since` entry resolves a claim the doc was
  wrong about, upgrade its verdict (e.g. `false` → `stale` if the code caught up).
- If new ground truth contradicts a doc that was `truthful`, downgrade it (`true`
  → `false`/`stale`).
- Mark each file's status relative to last run: `resolved` (a past `update`/`delete`
  suggestion was applied), `worsened`, `improved`, or `unchanged`.

Also check for **new** `.md` files (in the scan manifest but not in last run's facts)
and grade them fresh.

### Phase 3: Write state

Rewrite `.specify/md-doctor/state/facts.json` with the re-graded set (same shape as
`scan`), adding a `status_from_last_run` field per file
(`resolved`/`worsened`/`improved`/`unchanged`/`new`).

Append a drift report to `.specify/md-doctor/reports/<run-id>.md` (run-id =
`drift-<YYYYMMDDTHHMMSS>`) that leads with:
- what changed since the last run (commits count, .md files changed, new memsearch
  records),
- files that went `false`/`obsolete` this period,
- past suggestions now `resolved` vs still open,
- the current action queue.

Update `.specify/md-doctor/state/last-run.json` with `type:"drift"`, the new
`timestamp`, and the new `head`.

## Hard Rules

1. **The delta is the source of truth for "what changed", not your memory.** Ground
   every re-grade in a commit, a `.memsearch` entry, or a TDD verdict.
2. **Do not edit user `.md` files.** Drift only reads and writes MD Doctor state.
3. **Call out drift toward false.** If a doc that was fine is now false because the
   code moved on, that is the headline.

## Report back

Print: average truthfulness now vs last run, counts by verdict, files that worsened
or went false this period, and open suggestions still awaiting action. Point to the
drift report.
