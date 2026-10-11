**Template Version**: `zuraffa-1.0`

# Tasks: 1518-gen-guard-warning-pre-1483-remedy

Dependency-ordered, MVP-first. T1-T4 are the behavioral MVP (the red-green
loop drives them); T5-T7 are the migration + non-behavioral wiring
(spec-kit artifacts, docs) covered by `/speckit.implement`.

## 1. Messaging vocabulary (mvp)

- [x] **T1** (P1) `vacuous_guard.dart`: retire the pre-#1483 constant
  `vacuousGuardFallbackRemedy` (fold its #1308/#1320 history into the
  branched builder's doc) and add the pure forwarding scanner
  `guardOnlyWarningLinesToForward` (token line + the `--> fix:` line that
  immediately follows it, nothing else). Traces: FR-002, FR-003. Depends: —.

## 2. Gen-time branched warning (mvp)

- [x] **T2** (P1) `behavior_test_writer.dart`: add the nullable seam context
  (`projectRoot`, `featureDir`) to the constructor; the guard-only warning's
  remedy line resolves the seam from disk (engine → skin → test list,
  relativized) through `vacuousGuardFallbackRemedyFor`; the no-context case
  prescribes the conservative feature-derived test-list branch. The
  generated test shape and the warning's fire conditions are unchanged.
  Traces: FR-001, FR-005. Depends: T1.
- [x] **T3** (P1) `run_driver_core.dart`: `_forwardGuardOnlyWarning` forwards
  via `guardOnlyWarningLinesToForward` (the call site, the stop arm, and
  `_vacuousFallbackRemedy` untouched). Traces: FR-002, FR-005. Depends: T1.
- [x] **T4** (P2) `gen_command.dart`: thread `projectRoot`/`featureDir`
  through `_writersFor` and `_regenerateStaleStub` so the real write AND the
  staleness-mirror render print the same branched wording. Traces: FR-004.
  Depends: T2.

## 3. Pin migration (mvp — same change as the constant retirement)

- [x] **T5** (P1) Migrate the pin suites: `bug_1320_declared_assertion_reachable_test.dart`
  U8 → the branched builder (both branches carry the wording family);
  `bug_1483_vacuous_green_remedy_shape_test.dart` U-1483-1c → byte-exact
  pins of the two branched outputs; `issue_1308_vacuous_guard_remedy_test.dart`
  U-1308-1 → branched byte-exact pins (token/marker/violation asserts stay);
  U-1308-2 → the branched printed wording. Traces: FR-003. Depends: T1.

## 4. Verification

- [x] **T6** (P1) `tdd/verification.md`: record the red evidence, the green
  evidence, and the targeted test runs (analyze + changed-file tests only;
  no full suite on cloud agents). Depends: T2-T5.

## 5. Wiring / non-behavioral

- [x] **T7** (P2) Spec-kit artifacts (spec.md, plan.md, tasks.md,
  tdd/test-list.md, tdd/verification.md) committed with the code; PR body
  links issue #1518 and includes the transcript-agreement demo. Depends: T6.

## 6. Review round (PR #1525 comments)

- [x] **T8** (P2) Review fixes: extract the ONE `lanePlanSeamPath`
  seam-resolution rule into `vacuous_guard.dart` (the writer and the run
  driver both call it — the wording was single-sourced in #1483, the PATH
  probe was not); enforce the scanner's adjacency contract (the `--> fix:`
  line only on the line directly after the token line) and extend U-1518-5
  with the interleaved case; add the gen-level
  `test/plugins/tdd/commands/bug_1518_gen_command_seam_test.dart`
  (G-1518-1/G-1518-2, real GenCommand, mutation-verified) and correct the
  FR-004 mutation note in `tdd/verification.md`; normalize the `^- [x]`
  checkboxes above. Traces: FR-001, FR-002, FR-004. Depends: T1-T4.
