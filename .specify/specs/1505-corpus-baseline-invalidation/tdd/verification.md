# Verification: 1505-corpus-baseline-invalidation

- **Date**: 2026-09-13
- **Branch**: feat/1505-corpus-baseline-invalidation
- **Scope audited**: spec.md (SC-1..SC-6), plan.md hashing design,
  tdd/test-list.md, tdd/cycle-log.md, changed code, changed tests.

## Verdict: VERIFIED — all gates pass

## 1. Red evidence (recorded before implementation)

Source: `tdd/cycle-log.md` (append-only). First full run of the new tests
against the UNFIXED fingerprint:

- command: `dart test test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
- result: `+12 -4: Some tests failed.`
- red set — exactly the planned behaviors, no others:
  - T001 — fingerprint IDENTICAL (`58c0f883…`) before/after creating
    `test/broken_test.dart` (captured verbatim in cycle-log.md).
  - T002 — lib/ content change did not flip the fingerprint.
  - T003 — `.zfa/manifests/corpus-manifest.json` +
    `.zfa/context.json` did not flip the fingerprint.
  - #1505 repro (driver) — second feature reported `corpus-wide reuse`,
    suite spy stayed at 1 invocation (stale snapshot served).

## 2. Green evidence (after implementation)

- change: `lib/src/plugins/tdd/services/corpus_baseline_cache.dart` ONLY
  (the constraint's allowed surface); tests in
  `test/plugins/tdd/corpus_economics/baseline_cache_test.dart`.
- cycle: implementation (T005) → 3 economics guards failed (over-strict
  `.zfa` presence marker) → refined within the cycle (cycle-log.md) →
  **`+16: All tests passed!`** — re-confirmed after `dart format`
  (post-format run: `+16: All tests passed!`).
- in-cycle honesty note: T008 (economics guard, driver) and T006/T007/
  T008u (unit pins) were GREEN BEFORE the fix by design (the old code
  ignored those inputs entirely); they are recorded as regression pins in
  the test list, not fabricated reds.

## 3. Success-criteria audit

| criterion | verdict | evidence |
| --------- | ------- | -------- |
| SC-1 test/lib tree content changes invalidate | PASS | T001/T002 green (red first); content-based: T006 proves mtime-only does NOT flip |
| SC-2 .zfa memory/manifest state invalidates | PASS | T003 green (red first): manifests + context.json flips |
| SC-3 run-mutated state does NOT invalidate | PASS | T007 (unit): cache file, progress.json, run.lock, receipts/runs/plans, per-feature run-state → fingerprint stable, cache still hits; T008 driver guard: reuse preserved with zero extra suite spawns |
| SC-4 driver-level invalidation + preserved reuse | PASS | #1505 repro: suite re-runs, no `corpus-wide reuse` line, cache rewritten under new fingerprint; economics guard: reuse line present, spy stays at 1 |
| SC-5 no pubspec+lock → null fingerprint | PASS | R4 (pre-existing) green |
| SC-6 analyze + suite health | PASS | `dart analyze` on both changed files: `No issues found!`; `dart format` clean; repo-wide format check: 2760 files, 0 changed |

## 4. Regression net (full honest runs)

| suite | result |
| ----- | ------ |
| test/plugins/tdd/corpus_economics/baseline_cache_test.dart | 16/16 (multiple runs incl. post-format) |
| test/plugins/tdd/services/ | 935/935 |
| test/plugins/tdd/commands/ + models/ + theater/ + scenarios/ | 629/629 |
| test/plugins/tdd/*.dart (root files) | 519/519 on re-run; one off-run showed a single issue_990 concurrency flake that passes deterministically in isolation and does not touch the changed code |

Disk housekeeping per protocol: `dart_test.kernel.*` + `.dart_tool/test/`
removed between batches (the full-suite kernel cache had ballooned to
8.7 GB and was the only space pressure encountered).

## 5. Constraint audit

- **Fix only in `corpus_baseline_cache.dart`**: `git diff master…HEAD --
  lib/` = exactly one file (fingerprint calculation + private helpers +
  doc comments). No caller edits (`run_driver_core.dart` untouched).
- **Cache hits preserved for genuinely unchanged suites**: T007 + R5 +
  economics guard all green.
- **No new analyze warnings**: `No issues found!` on the changed files.
- **Signature/back-compat**: `dependencyFingerprint(String) →
  Future<String?>` unchanged; null contract (no pubspec+lock) unchanged;
  previously-written cache files self-heal on first miss (re-captured
  live, rewritten under the new key — no migration needed).

## 6. Known scope boundary (honesty note)

Real corpus lanes that generate new lib/test files per feature will now
correctly miss per feature (a baseline captured before feature A's
generated tests exist is not the baseline feature B's suite faces) — this
is the invalidation the issue demands and is called out in plan.md's
risk section. #1550's primary remedies (reset invalidation, compose
premise check) remain out of scope here; the fingerprint half of #1550's
suggestion (declared-state participation) is covered via SC-2.
