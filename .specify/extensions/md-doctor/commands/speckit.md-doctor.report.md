---
description: "Render the latest (or a specific) health report: average truthfulness, counts of truthful/stale/false/obsolete docs, and the queue of update/delete/create actions"
---

# MD Doctor — Report

Show the project's current documentation health from MD Doctor's recorded facts.
This is read-only: it aggregates state and prints; it never grades or edits.

## User Input

```text
$ARGUMENTS
```

Recognized modifiers:

- `--run <run-id>`: render a specific past report from
  `.specify/md-doctor/reports/<run-id>.md` instead of the latest.
- `--json`: print the aggregated summary as JSON.

With no input, show the latest health summary.

## Workflow

### Phase 1: Aggregate

```bash
bash .specify/extensions/md-doctor/scripts/bash/md-doctor.sh report
```

(Dev fallback: `bash <extension-root>/md-doctor/scripts/bash/md-doctor.sh report`.)

This reads `.specify/md-doctor/state/facts.json` and prints the health summary:
average truthfulness, counts of `truthful`/`stale`/`false`/`obsolete`, and the
`update`/`delete`/`create` action queue. Add `--json` for machine form.

### Phase 2: Present

If a specific `--run` was requested, `cat` that report file and present it.

Otherwise present, in order:

1. **Headline** — average truthfulness /100 and the verdict breakdown.
2. **Danger first** — every `false` and `obsolete` file, with its rationale. These
   are the docs a new agent would wrongly believe.
3. **Action queue** — `update`, then `delete`, then `create`, each as a path list.
4. **Healthy** — count of `truthful` files (so the user sees the good news too).

If no `facts.json` exists yet, tell the user to run `/speckit.md-doctor.scan` first;
do not invent numbers.

## Report back

Print the summary and the action queue, and point to
`.specify/md-doctor/reports/` for the full latest report. Keep it short — the goal is
a one-glance health check.
