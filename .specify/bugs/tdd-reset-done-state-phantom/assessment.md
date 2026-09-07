# Assessment — 1264 tdd reset leaves done-state for deleted artifacts

## Root cause

`zfa tdd reset <feature>` deletes the generated test+subject files it owns and
resets `tdd/run-state.json`, but it deliberately never touches
`tdd/cycle-log.md` / `tdd/journal.json` (append-only evidence, "never touch
foreign files" rule). The TDD driver then re-derives per-behavior done-state
from that surviving green evidence, so behaviors whose artifacts were dropped
remain "done". `zfa tdd doctor` only checks store-to-store agreement
(run-state ↔ journal/registry), not store-to-tree agreement (green evidence ↔
artifact files on disk), so it reports the feature healthy. `zfa tdd run` skips
behaviors already marked done, and `zfa tdd status` reports engine green for
behaviors with no test files on disk.

Chain of failures:

1. reset drops test+subject files but leaves green evidence in
   journal/cycle-log intact;
2. driver re-derives done-state from surviving evidence (no tree check);
3. doctor checks store-to-store only — misses evidence-without-artifact;
4. `run` trusts done-state → skips the dropped behaviors ("already done");
5. `status` reports green on nonexistent tests.

## Remediation (must ship together; belt and braces)

- **(a) Reset invalidates green evidence for dropped behaviors.** When reset
  drops a behavior's artifacts it appends a tombstone entry to the journal
  (and cycle-log where applicable) marking the behavior's prior green evidence
  as invalidated (`invalidated: true` / `tombstone: reset-1264`), so no later
  reader can treat the stale green as live.
- **(b) Driver honors "done" only when green evidence is backed by artifacts
  on disk.** Before treating a behavior as done, the driver verifies the
  registered test file (and subject file where required) exists; evidence
  without backing files is not honored as done → the behavior is re-driven.
- **(c) Doctor reports `evidence-without-artifact` as a drift** with exactly
  one prescribed recovery (re-run the behavior / re-drive, i.e. run
  `zfa tdd run <feature>` which re-drives behaviors whose artifacts are
  missing — never delete the append-only store).
- **(d) Status does not report green** for behaviors whose backing files are
  missing; they count as not-done/pending.

## Hard constraints

- Fix ONLY through the generation pipeline; never hand-edit source the
  assessment says must stay pipeline-owned.
- One PR per bug (this PR: 1264).
- reset's "never touch foreign files" rule stays intact for files it does not
  own; the tombstone is an append to the journal, not a rewrite of history.
- After the fix: run re-drives every behavior whose artifacts were dropped,
  doctor detects orphaned evidence as a drift with one recovery, status does
  not report green for nonexistent tests.

## Acceptance criteria

1. RED: a failing test reproduces the phantom done-state — after reset, run
   skips dropped behaviors / doctor reports healthy / status shows green
   without backing files.
2. GREEN: with the fix, after reset the driver re-drives dropped behaviors,
   doctor reports `evidence-without-artifact` drift with one recovery, and
   status no longer reports green without backing artifacts.
3. No new failures in the chunked suite; `dart analyze` clean on changed
   files; `dart format .` leaves zero diffs.
