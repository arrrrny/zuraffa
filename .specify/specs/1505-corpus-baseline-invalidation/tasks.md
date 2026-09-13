# Tasks: 1505-corpus-baseline-invalidation

- **Spec ID**: 1505-corpus-baseline-invalidation
- **Branch**: feat/1505-corpus-baseline-invalidation

MVP-first: the smallest behaviour slice that kills the reported failure is
the unit-level fingerprint flip on a `test/` change (T001) plus the driver
repro (T004). Everything else hardens or guards.

> Task ordering follows /speckit.tdd.plan: every behaviour task below is
> preceded by its failing test (tdd/test-list.md). Non-behavioural tasks
> (docs, format) come last.

## Phase 1 — MVP: fingerprint invalidation on outcome-relevant change

- [ ] T001 (RED) Unit: a created file under `test/` flips the fingerprint;
      `read()` misses after the flip (US-1 / SC-1). Test before impl.
- [ ] T002 (RED) Unit: a modified file under `lib/` flips the fingerprint
      (US-2 / SC-1). Test before impl.
- [ ] T003 (RED) Unit: creating `.zfa/manifests/corpus-manifest.json` and
      changing `.zfa/context.json` each flip the fingerprint (US-3 / SC-2).
      Test before impl.
- [ ] T004 (RED) Driver: after a test-file fix, the second feature's run
      does NOT report `corpus-wide reuse` and re-runs the live suite —
      the #1505 repro end-to-end (US-1 / SC-4). Test before impl.
- [ ] T005 (GREEN) Implement: extend `dependencyFingerprint()` in
      `corpus_baseline_cache.dart` with `test/` + `lib/` tree content
      digests and the `.zfa/` memory/manifest allow-list digest (plan.md
      hashing design). T001–T004 pass.

## Phase 2 — Guard: reuse for genuinely unchanged suites

- [ ] T006 (RED) Unit: mtime-only touch of a `test/` file does NOT flip
      the fingerprint (US-4 / SC-1, SC-3). Test before impl.
- [ ] T007 (RED) Unit: run-mutated state (`.zfa/corpus/progress.json`,
      `.zfa/corpus/run.lock`, `.zfa/receipts/…`, the cache file itself)
      does NOT flip the fingerprint (US-4 / SC-3). Test before impl.
- [ ] T008 (RED) Driver: with no outcome-relevant change, the second
      feature's run still reports `corpus-wide reuse` with zero additional
      suite spawns (US-4 / SC-4). Test before impl (this may already pass
      via T005's design — it is the economics regression guard; if green
      on first run, record as covered-by-design with evidence).
- [ ] T009 (GREEN) Implement: adjust only if T006–T008 exposed a leak
      (allow-list scope, marker semantics).

## Phase 3 — Non-behavioural

- [ ] T010 Update the library doc comment and `dependencyFingerprint()`
      doc in `corpus_baseline_cache.dart` to name the new inputs and cite
      #1505 (docs only, no behaviour).
- [ ] T011 `dart analyze` on changed files — no new warnings (SC-6).
- [ ] T012 `dart format` the changed files; corpus_economics suite green.
- [ ] T013 Write `tdd/verification.md` (red evidence, green evidence,
      constraint audit) and commit artifacts.
