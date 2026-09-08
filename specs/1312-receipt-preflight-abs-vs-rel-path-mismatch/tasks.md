# Tasks 1312 — receipt preflight absolute-vs-relative mismatch (MVP-first, dependency-ordered)

Every behavior task below is driven by a failing test FIRST
(tdd/test-list.md). Non-behavioral tasks are handled by
speckit.implement after the green loop.

## Phase 0 — RED (test-first evidence)

- [x] T0.1 Add unit tests to
      `test/plugins/tdd/services/receipt_preflight_test.dart`:
      (a) absolute audited path inside projectRoot, covered by a
      receipt's relative path → pass; (b) absolute audited path
      OUTSIDE projectRoot → skipped, no missing_receipt; (c) mixed
      list (absolute-in-root covered + relative covered +
      absolute-out-of-root) → zero findings. [SC-2, SC-3, SC-4]
- [x] T0.2 Add CLI-tier test: fixture `artifacts.json` whose
      `subject_path` is ABSOLUTE (as `zfa tdd gen` writes it) + a
      receipt covering the same file → `zfa tdd verify` prints
      `receipt preflight: ok` and proceeds past the gate. [SC-1]
- [x] T0.3 Run the new tests, record RED evidence
      (missing_receipt fired on covered subjects) into
      `tdd/verification.md`. Kernel-cache cleanup before/after.

## Phase 1 — GREEN (the fix)

- [x] T1.1 `receipt_preflight.dart`: widen `_normalize` to the
      relativizing normalizer (returns `null` for out-of-root paths;
      idempotent on relative paths; backslash canonicalization
      preserved). [SC-2, SC-3, SC-4, SC-5]
- [x] T1.2 `ReceiptPreflight.check`: skip `null` normalized subjects
      before the membership test; findings keep naming the
      project-relative path. [SC-6]
- [x] T1.3 Update the `check()`/`_normalize` doc comments to the real
      contract (audited paths may be absolute or project-relative;
      out-of-root skipped). [SC-7]
- [x] T1.4 Re-run the unit + CLI suites for the file; all green;
      record GREEN evidence in `tdd/verification.md`.

## Phase 2 — implement (non-behavioral)

- [x] T2.1 `speckit.analyze` cross-artifact drift pass: spec ↔ plan ↔
      tasks ↔ test-list consistency; fix drift, no scope growth.
- [x] T2.2 `dart analyze` on changed files; `dart format .`; zero
      remaining diffs. [SC-7]
- [x] T2.3 Disk housekeeping: remove kernel caches
      (`.dart_tool/test/`, `$TMPDIR/dart_test.kernel.*`); confirm
      `df -h .` healthy.
- [x] T2.4 Commit spec artifacts + fix + tests together
      (`fix(1312):` Conventional Commits), push, open PR closing
      #1312 with the preflight-pass demo.

## Dependency order

T0.1 → T0.2 → T0.3 (RED) → T1.1 → T1.2 → T1.3 → T1.4 (GREEN) →
T2.1 → T2.2 → T2.3 → T2.4. No parallelizable tracks (single-file fix).
