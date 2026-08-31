---
name: speckit-md-doctor-apply
description: 'Apply suggestions mechanically and safely: create stubs for missing docs and stamp verified docs by default; delete only with --delete (destructive)'
compatibility: Requires spec-kit project structure with .specify/ directory
metadata:
  author: github-spec-kit
  source: md-doctor:commands/speckit.md-doctor.apply.md
---

# MD Doctor — Apply

Mechanically act on the suggestions MD Doctor recorded during `scan`/`drift`. It is
deliberately conservative: by default it only does **safe** things (create stubs for
missing docs, stamp verified docs). Deletion is destructive and requires an explicit
flag.

## User Input

```text
$ARGUMENTS
```

Recognized modifiers:

- `--action create` — only create the missing-doc stubs.
- `--action stamp` — only append a "verified" footer to keep/update docs.
- `--action delete` — show the delete plan (destructive; see `--delete`).
- `--delete` — actually delete files the engine marked `delete`. **Destructive.**
- `--all` — do everything (create + stamp + delete); implies `--delete`.

With no flag, the safe default runs: create stubs + stamp verified docs. No deletes.

## Preconditions

A `scan` (or `drift`) must have run so `.specify/md-doctor/state/facts.json` exists
with `action` fields. If missing, stop and tell the user to run
`/speckit.md-doctor.scan` first.

## Workflow

### Phase 1: Run the engine

```bash
bash .specify/extensions/md-doctor/scripts/bash/md-doctor.sh apply [--delete] [--action <a>] [--all]
```

(Dev fallback: `bash <extension-root>/md-doctor/scripts/bash/md-doctor.sh apply ...`.)

What it does, by flag:

- **default** — for each `create` fact, write a stub at `proposed_path`; for each
  `keep`/`update` fact, append a footer `> Verified by md-doctor on <date> —
  truthfulness <n>/100.` (idempotent: skips files stamped today).
- `--action create` — stubs only.
- `--action stamp` — footers only.
- `--action delete` (no `--delete`) — prints the files it *would* delete; changes
  nothing.
- `--delete` — also removes files marked `delete`.
- `--all` — create + stamp + delete.

### Phase 2: Review the engine output

The engine prints `created=N stamped=N deleted=N` and the affected paths. Read them.

If `--delete` was used, confirm the deleted paths are exactly the `false`/`obsolete`
docs from the last report and nothing else. If something looks wrong, you may restore
from git (`git checkout -- <path>` / `git restore`) since deletes are working-tree
only until committed.

### Phase 3: Record

The engine does not mutate `facts.json`'s suggestions. After applying, open
`.specify/md-doctor/state/last-run.json` and append what you did to `actions_taken`
(e.g. `["created: docs/api.md", "stamped: README.md", "deleted: OLD-NOTES.md"]`) so
the next `drift` sees them as `resolved`.

## Hard Rules

1. **Never delete without `--delete`.** The command refuses by design; do not
   circumvent it.
2. **Do not rewrite user prose.** `apply` only creates stubs and appends footers.
   Content edits to a `false` doc are a human/authored decision, not this command's
   job — surface them as `update` suggestions instead.
3. **Treat deletions as recoverable until committed.** Warn the user they are
   untracked working-tree changes unless they commit.

## Report back

Summarize what was applied (created/stamped/deleted counts + paths) and what remains
open. If you deleted anything, remind the user it is reversible via git until commit.