# Bug Assessment — #1550: `tdd reset` leaves the corpus-wide baseline cache stale; the next run believes dropped behaviors are green

- **Slug**: 1550-reset-stale-corpus-baseline-cache
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1550
- **Verdict**: valid
- **Severity**: high (a documented recovery command — reset — converts a
  clean restart into a hard stop at the first behavior; the failure mode
  also fabricates green claims for dropped behaviors)

## Report (verbatim, condensed)

> `zfa tdd reset 001-todo-app` reported a clean slate (`dropped=51
> deleted=102`, green evidence tombstoned). The very next `tdd run`
> hard-stopped at the first behavior: A1 gen → ok, verify-red →
> certified, make → generation-error — `zfa tdd compose: green unit
> subject "U1" has no registry record with a subject_path in
> specs/001-todo-app/tdd/artifacts.json`, `outcome=runner-error`.
>
> U1 was NOT green — the run had only just generated A1. The "green"
> claim came from a stale cache that `tdd reset` does not invalidate:
> `.zfa/corpus/run-baseline.json` (the corpus-wide baseline cache, spec
> 069 T004, stamped 2026-09-11) and the per-feature
> `specs/001-todo-app/tdd/run-baseline.json` it materializes from. The
> run log shows the reuse: `suite baseline: corpus-wide reuse
> (fingerprint match; spec 069 T004)`.

## Root cause (confirmed against the tree)

Two independent defects combine into the observed hard stop:

**Defect 1 — reset's restart contract misses the third store.**
`ResetCommand._run`
(`lib/src/plugins/tdd/commands/reset_command.dart`) deletes the feature's
owned artifacts, the registry (`tdd/artifacts.json`), and run-state
(`tdd/run-state.json`), then appends the #1264 journal tombstone. The
corpus-wide baseline cache (`.zfa/corpus/run-baseline.json`,
`CorpusBaselineCache`, spec 069 T004) is a THIRD store with the same
restart contract and reset never touches it. Its dependency fingerprint
(sha256 over pubspec.yaml + pubspec.lock + suite template — nothing
reset mutates) still matches the post-reset tree, so the next run's
driver (`run_driver_core.dart` step 6b) hits the `corpus-wide reuse`
path and materializes the feature-local `run-baseline.json` from a
pre-reset snapshot: the suite baseline claims the dropped behaviors'
tests (deleted by reset) were green at capture time.

**Defect 2 — compose's green-unit premise check reports the wrong
outcome.** `CompositionTargets.discover`
(`lib/src/plugins/tdd/services/composition_targets.dart`) requires every
green cycle-log unit row to resolve to a registry record. After a reset
the cycle-log's green evidence survives (append-only — the tombstone
lands in the journal, which discovery does not consult) while the
registry record is gone, so discovery fails with
`missing-anchor-subject`. `ComposeCommand` then maps every non-
`no-green-units` discovery failure to `ComposeOutcome.runnerError`
(`compose_command.dart` step 4) — the operator sees `runner-error` and a
`zfa tdd gen U1` remedy that cannot unblock the run, instead of the
honest diagnosis: the green PREMISE is stale (invalidated by the reset),
so compose refuses with `stale-evidence` and the artifacts must be
re-derived.

Design tension (kept intact by the fix): reset's append-only contracts
are correct and untouched — the cycle-log and journal stay intact; the
fix adds the missing cache invalidation and reclassifies the compose
refusal. The corpus cache fingerprint (issue fix #3) is deliberately NOT
changed: the brief forbids fingerprint/state-machine edits, and deleting
the cache on reset achieves the same forced miss without widening the
fingerprint surface (#1505 family remains open for the general case).

## Expected

1. `tdd reset` invalidates the corpus baseline cache
   (`.zfa/corpus/run-baseline.json`) alongside registry + run-state —
   and the feature-local `specs/<feature>/tdd/run-baseline.json` with
   it, so no pre-reset snapshot survives the restart.
2. Compose verifies its green-unit premise against the registry before
   composing: a green unit whose registry record is absent is a
   `stale-evidence` refusal (actionable: the evidence is stale, re-derive
   the artifacts), not a `runner-error`.

## Hard constraints (from the bug brief)

- Fix ONLY the reset invalidation path and the compose registry check.
- Do NOT change the corpus cache fingerprint logic or the run state
  machine (issue fix #3 is out of scope for this fix).
- Must pass `dart analyze` with no new warnings.
- Same failure family as #1505; related #1551 (compose deadlock) is NOT
  fixed here — one PR per bug.
