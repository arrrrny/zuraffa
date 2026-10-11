# Issue 1264 — tdd: reset leaves done-state for deleted artifacts — doctor says healthy, run skips the behaviors, status reports engine green on nonexistent tests

- **Severity:** high
- **State:** open
- **Version:** 6.1.0 (master `06acd8ca`)
- **Source:** https://github.com/arrrrny/zuraffa/issues/1264

## Describe the bug

`zfa tdd reset <feature>` produces a state the rest of the toolchain trusts but
that no longer matches the tree: behaviors whose tests and subjects were deleted
remain marked done, `zfa tdd doctor` reports the feature healthy, and a
subsequent `zfa tdd run` skips those behaviors entirely ("already done").

Observed sequence on a feature with an engine lane (U1, U2) and skin lane
(A1..A3):

1. Feature had completed engine behaviors (green evidence in cycle-log.md /
   journal.json, registry records, generated test+subject files).
2. `zfa tdd reset <feature>`: "will delete 8 owned file(s)" (the 4 test+subject
   pairs), "will reset tdd/run-state.json", `dropped_records=4`. Files are
   indeed deleted.
3. `zfa tdd doctor <feature>`:
   `{"verdict":"healthy","prescription":"none","drifts":[]}` — despite
   U1/U2/A3 having zero artifacts on disk.
4. `zfa tdd run <feature>`:

   ```
   zfa tdd run: feature <f> — 2 behavior(s)
      2 already done — skipping
   ```

   The engine lane is skipped wholesale; `run-state.json` afterwards shows
   `"U1": "done", "U2": "done", "A3": "done"` with no files backing any of
   them. `zfa tdd status` reports `engine ✅ 2/2` for behaviors that do not
   exist.

## Root cause

reset honors its "never touch foreign files" rule for cycle-log.md/journal.json
(append-only evidence) but the driver then re-derives done-state from that
surviving evidence, and doctor only checks store-to-store agreement, not
store-to-tree agreement (green evidence ↔ artifact files on disk).

## Expected behavior

After reset, a `run` should re-drive every behavior whose artifacts were
dropped. Either:

- (a) reset also invalidates the green evidence for the dropped behaviors (a
  tombstone entry in the journal/cycle-log, or per-behavior evidence
  invalidation), or
- (b) the driver/doctor verify that green evidence is backed by existing
  registered artifacts before honoring it ("done" requires files on disk), with
  doctor reporting `evidence-without-artifact` as a drift and prescribing
  exactly one recovery.

## Actual behavior

Deleted behaviors count as done across status/run/prove surfaces; the only
recovery is manually deleting the whole `tdd/` store (losing the append-only
audit history) and re-planning.
