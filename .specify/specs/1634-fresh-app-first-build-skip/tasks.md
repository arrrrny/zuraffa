# Tasks: 1634-fresh-app-first-build-skip

- **Branch**: feat/1634-fresh-app-first-build-skip
- **Spec**: .specify/specs/1634-fresh-app-first-build-skip/spec.md
- **Plan**: plan.md (decisions D1–D6)

Dependency-ordered, MVP-first. T = test-first (driven through the TDD
extension's red-green-refactor loop, tdd/test-list.md); N = non-behavioral.

## Phase A — MVP: the static first-build decision (P1)

- [x] **T001 (T, red→green)** Rewrite the #1624 "missing marker runs the
  build" test into the fresh-app static matrix and ADD the static
  decision tests before any implementation change:
  `test/plugins/tdd/services/build_relevance_test.dart`, group
  `refactorBuildSkipNote (issue #1624)` — new group
  `refactorBuildSkipNote — static first build (issue #1634)`:
  - S1 no `.dart_tool/build/` + plain un-annotated Dart only + no
    `build.yaml` → `staticFirstBuildSkippedNote` (US1/SC-1)
  - S2 no graph + annotated `.dart` → null (US2/SC-2)
  - S3 no graph + non-Dart file in a walked root → null (US2/SC-2)
  - S4 no graph + `build.yaml` at root → null (US2/SC-2)
  - S5 no graph + `.dart_tool/build/` present without marker → null
    (US3/SC-3)
  - S6 no graph + unreadable (non-UTF-8) file → null (US3/SC-3)
  Red is recorded in tdd/cycle-log.md BEFORE implementing.
- [x] **T002 (T, green)** Implement the static branch in
  `lib/src/plugins/tdd/services/build_relevance.dart`:
  `refactorBuildSkipNote` — when the marker is missing AND
  `.dart_tool/build/` does not exist, run the static scan (FR-1..FR-3);
  marker missing but directory present → null (FR-4); errors → null
  (FR-6). Add `staticFirstBuildSkippedNote` (D4). The incremental path
  below the marker check is byte-identical (FR-5).
- [x] **T003 (T, green)** Update the binding test's first assertion in
  `test/plugins/tdd/services/refactor_passes_test.dart` (line ~357):
  the scratch project now proves the static skip through the bound
  gate (`staticFirstBuildSkippedNote`), keeping the second half (the
  incremental skip via marker mtime) unchanged.

## Phase B — incremental-path integrity (P2)

- [x] **T004 (T, pin)** Verify the pre-existing #1624 incremental group
  passes UNMODIFIED (byte-identical test source; SC-4/FR-5):
  `dart test test/plugins/tdd/services/build_relevance_test.dart` —
  recorded as a pin (NOT a fabricated red) in tdd/cycle-log.md.

## Phase C — non-behavioral (implement phase)

- [x] **T005 (N)** Class doc for `BuildRelevance`: extend the #1624
  section with the first-build static decision (the marker fail-open's
  cost, the static scan's trigger set and its `build.yaml` rationale,
  the pubspec-not-a-trigger rationale, the copied-tree coverage
  boundary) — the honesty conventions the file already carries.
- [x] **T006 (N)** `dart format` on changed files; `dart analyze` on
  every changed file reports no issues; changed-file tests green
  (SC-5); post-test kernel-cache cleanup.

## Phase D — verification + landing

- [ ] **T007 (T, verify)** Run `/speckit.tdd.verify`: REAL test runs on
  this branch (changed files), full SC audit with actual pass/fail
  counts, unrelated pre-existing failures flagged; produce
  `tdd/verification.md` from the recorded runs (never copied or
  back-dated).
- [ ] **T008 (N)** Push branch; open the PR against `master`
  (`perf(1634): build-relevance gate — skip first build for fresh apps
  with no builder-facing files`, Closes #1634).
