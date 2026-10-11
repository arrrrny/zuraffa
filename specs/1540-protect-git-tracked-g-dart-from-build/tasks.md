# Tasks: Protect git-tracked hand-authored `.g.dart` placeholders (restore-or-refuse)

**Spec**: `spec.md` · **Plan**: `plan.md` · **Tests**: `tdd/test-list.md`

MVP-first: US1 (build restores-or-refuses) is the minimum viable fix — the
dead-end scenario. US2/US3 harden the gate and the loop; US4 documents the
pattern. TDD behaviors carry a failing test before implementation (tdd/test-list.md).

## 1. MVP — guard service + `zfa build` restore-or-refuse (US1)

- [x] T001 Create `lib/src/core/generation/tracked_generated_output_guard.dart`
  with no-op-capable API surface (stub): `TrackedGeneratedSnapshot`,
  `TrackedGeneratedRestoreResult`, `TrackedGeneratedOutputGuard`
  (`gitTrackedFiles`, `capture`, `detectDeleted`, `restore`,
  `restoreRemedyLines`) — behavior completed in T003 (red first).
- [x] T002 Write `test/core/generation/tracked_generated_output_guard_test.dart`
  (fast tier, real `git init` sandboxes, skip when git absent): tracking
  parse; membership = tracked ∧ existing; deletion detection; byte-exact
  restore incl. unstaged edits; restore-failure reporting; disabled
  outside git; remedy lines. **[RED]**
- [x] T003 Implement guard behavior: `git -C <root> ls-files -z` parse
  (NUL-separated, project-relative), suffix filter (`.g.dart`,
  `.zorphy.dart`), byte capture, restore, failure buckets. **[GREEN]**
- [x] T004 Wire `BuildCommand.run()`: capture snapshot pre-build (non-dry-run
  only), restore-or-refuse after EACH `_runBuild()` (initial + clean-cache
  retry) before the gates; print FR-3 message (path, owning library,
  both exclusion lines, doc ref); refuse non-zero with `git checkout --`
  remedy when unrestorable.
- [x] T005 Write `test/commands/build_command_tracked_outputs_test.dart`
  (fast): recovery restores + prints; refusal returns failure with remedy;
  non-git sandbox silent. **[RED → GREEN with T004]**

## 2. Completeness gate restore path (US2)

- [x] T006 Extend `verifyDeclaredPartsOrFail` (signature unchanged): on
  missing parts, one `Process.runSync('git', ['-C', root, 'ls-files',
  '-z'])`; per tracked missing path print the spec-1540 restore block
  (`git checkout -- <path>`, placeholder explanation, doc ref). Untracked
  paths: message unchanged.
- [x] T007 Gate tests in `test/commands/build_command_tracked_outputs_test.dart`:
  tracked missing part → message contains `git checkout -- <path>`; untracked
  missing part → no spec-1540 remedy lines; no git → unchanged message.
  **[RED → GREEN]**

## 3. Refactor build pass restore-or-refuse (US3)

- [x] T008 Extend `RefactorPassesResult` with `refusalReason` (nullable) +
  doc; in `RefactorPasses.run()` snapshot tracked generated-name files
  around the `build` pass only; restore before the pass after-snapshot;
  append restoration note to the action output; refuse (stopped,
  `failedPass: 'build'`, refusalReason with remedy) on restore failure.
- [x] T009 Print `refusalReason` in `refactor_command.dart` misfire-stop
  block (distinct from the timeout branch).
- [x] T010 Write `test/plugins/tdd/bug_1540_refactor_tracked_restore_test.dart`
  (slow, TddFixture + fake zfa side effects; `git init` fixture):
  (a) fake zfa deletes tracked placeholder, exit 0 → file restored
  byte-identical, action output records restoration, exit 0 run;
  (b) restore made impossible → run stops on `build`, refusal + remedy
  printed, exit ≠ 0. **[RED → GREEN]**

## 4. Documentation (US4)

- [x] T011 Write `docs/hand-authored-g-dart-placeholders.md`: pattern
  definition; why build_runner deletes placeholders (output reservation +
  stale-output cleanup); the two-builder `build.yaml` exclusion YAML
  (`json_serializable` + `source_gen:combining_builder`) with the issue's
  engine_event example; how zfa protects (snapshot/restore/refuse, gate
  remedy); how to legitimize a placeholder.

## 5. Polish & verification (non-behavioural)

- [x] T012 Cross-artifact consistency pass: spec criteria ↔ test-list rows ↔
  tasks; fix drift (`/speckit.analyze` equivalent, recorded in
  `tdd/verification.md`).
- [x] T013 `dart analyze` clean on changed files; `dart format lib test`;
  full fast-tier suite green; slow-tier refactor suites green.
- [x] T014 Record evidence in `tdd/verification.md` (red run, green run,
  scenario matrix SC-1..SC-9) and update cycle-log conventions if needed.
