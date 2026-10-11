# TDD Verification — Spec 1345 (reset→rerun acceptance placeholder deadlock)

Feature: `specs/1345-reset-rerun-acceptance-placeholder-deadlock`
Test file: `test/plugins/tdd/bug_1345_placeholder_re_drive_test.dart`
Branch: `feat/1345-reset-rerun-acceptance-placeholder-deadlock`

## Test-first evidence (red phase)

The suite was written and run BEFORE the fix (red on the unfixed tree):

- **B1 (SC-1) — RED.** The tombstoned acceptance-kind placeholder re-drive
  dead-ended exactly as the issue reprocribes:

  ```
  zfa tdd make: behavior A2
     re-drive adoption withheld: the on-disk subject is a born-green
     placeholder, so the passing target test proves nothing (issue #1036) —
     the subject-drift refusal stands.
  zfa tdd make: behavior "A2" — the target test already passes, but the
     subject file at .../lib/a2_subject.dart no longer matches the shape the
     certified green evidence captured (issue #1036) ...
  make: behavior=A2 outcome=subject-drift feature=090-bug-1345-placeholder-redrive
  ```

  exit 1 (`Expected: <0> / Actual: <1>`). This is the #1331-adoption ×
  #1036-guard intersection with no path.
- **B3 (SC-2) — RED.** The run driver stopped on the new terminal token:

  ```
  [run] U-001 make -> adopted-placeholder
  zfa tdd run: step failed — behavior=U-001 step=make outcome=adopted-placeholder
  run: feature=... result=stopped pending=0 red=1 green=0 done=0 stopped_at=U-001:make
  ```

- **B4 (SC-3) — RED.** Doctor's `evidence-without-artifact` fix line named
  only the #1331 adoption (`does not contain 'adopted-placeholder'`) — an
  unexecutable prescription for the placeholder class.
- **B5/B6 (SC-4) — GREEN pre-fix** (by design: regression guards over the
  preserved refusal classes).

## Green phase (post-fix)

- **B1+B2 (SC-1) — PASS (real pipeline).** The make exited 0 with
  `outcome=adopted-placeholder`; the re-entry ran the REAL composition
  pipeline through an exec forwarder:

  ```
  re-drive compose re-entry (issue #1345): ... re-entering the acceptance
     pipeline at compose/make phase-2 (outcome=adopted-placeholder).
  composition fallback: 1 green unit subject(s) (U1)
  plan: composition fallback — 2 step(s)
  - generation:
    - step: .../fake_bin/zfa tdd compose A2 --feature ...
      exit: 0
    - step: .../fake_bin/zfa build
      exit: 0
  ```

  The subject on disk is the composed product (`GENERATED IMPLEMENTATION`,
  `zfa tdd compose A2` header, `package:tdd_fixture/u1_subject.dart`
  anchor import referencing `subject_u1`, no `UnimplementedError`), and
  the LAST green evidence entry binds the CURRENT composed subject hash
  and records the `tdd compose A2` + `build` generation steps.
- **B3 (SC-2) — PASS.** The run completed: gen → verify-red → make →
  refactor, `result=complete`, green evidence present (the fake's
  `adopt-placeholder` shape mirrors the real make's exit-0 +
  evidence-written contract).
- **B4 (SC-3) — PASS.** The fix line names both mechanics: `adopt`
  (#1331) AND `adopted-placeholder` / `issue #1345`; the verdict JSON
  keeps `prescription: resume`.
- **B5 (SC-4) — PASS.** The tombstoned UNIT-kind placeholder re-drive
  still refuses `outcome=subject-drift` (the compose re-entry is the
  acceptance lane only).
- **B6 (SC-4) — PASS.** The born-green placeholder with NO reset tombstone
  still refuses `outcome=subject-drift`; no green evidence written.

Full new suite: `02:23 +5: All tests passed!`

## Mutation evidence (test sensitivity)

- **M1 — remove the acceptance-kind gate from the re-entry branch** (the
  mutation `else if (reDrive && placeholderOnDisk && rowKind ==
  acceptance)` → `else if (reDrive && placeholderOnDisk)`): B5 FAILS —
  the unit-kind refusal flips to a compose re-entry
  (`make: behavior=U1 outcome=generation-error`), proving the suite pins
  the lane scope. Mutation reverted; the fix restored byte-identically
  and the full suite re-passed (+5).
- The red phase itself is the primary mutation evidence: every new
  behavior test failed against the pre-fix tree and passes post-fix.

## Regression suites run (targeted — only suites over the changed files)

| Suite | Result |
|---|---|
| `test/plugins/tdd/bug_1345_placeholder_re_drive_test.dart` (new) | 5/5 passed |
| `test/plugins/tdd/make_command_1036_test.dart` (the #1036 guard) | 5/5 passed (combined run +10: All tests passed) |
| `test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart` (the `adopted` re-drive + driver + doctor contract) | passed |
| `test/plugins/tdd/bug_1162_subject_shape_test.dart` (placeholder-shape predicate) | passed (combined run +21: All tests passed) |
| `test/plugins/tdd/bug_1162_bug_subject_green_path_test.dart` + `test/plugins/tdd/run_command_test.dart` (run driver) | passed (+55: All tests passed) |
| `test/plugins/tdd/bug_874_doctor_cross_feature_adoption_test.dart` | **+7 -4 — PRE-EXISTING failure** (verified identical on clean master via `git stash`: the same 4 `--adopt` tests fail without this branch's changes; unrelated to this spec) |

## Static checks

- `dart analyze` over all changed files
  (`make_command.dart`, `generation_plan.dart`, `step_runner.dart`,
  `run_driver_core.dart`, `doctor_command.dart`, the new test file,
  `tdd_fixture.dart`): **No issues found!**
- `dart format .` run; the 7 files this spec owns re-verified with
  `dart format --output=none --set-exit-if-changed` → 0 changed. (Three
  UNRELATED files that were already unformatted on master were reverted
  rather than reformatted, to keep the PR surgical.)

## Scope-fence checklist

- [x] Only the re-drive path in `make_command.dart` changed (the
      adoptable block + the outcome selection); the core engine cycle,
      the compose pipeline, the gen writers, and the verify gate are
      untouched.
- [x] The #1036 refusal stands for every non-re-drive case (B6) and for
      non-acceptance re-drives (B5); the `adopted` (#1331) outcome is
      unchanged (the #1331 suite passes).
- [x] The re-entry certifies from the pipeline's actual output (compose
      → build recorded in the evidence), never from the vacuous pass;
      zero composable anchors keeps the honest `unexpressible` stop.
- [x] One PR per issue (arrrrny/zuraffa#1345).

## Success criteria scorecard

- **SC-1** — PROVED (B1+B2: outcome token, real composed subject,
  evidence hash + generation steps).
- **SC-2** — PROVED (B3: terminal make success, run completes).
- **SC-3** — PROVED (B4: prescription names the re-entry; resume kept).
- **SC-4** — PROVED (B5/B6 refusals preserved; #1331/#1036 suites pass
  unchanged).
- **SC-5** — PROVED for every suite over the changed files; one
  pre-existing unrelated failure flagged (bug 874, fails on master too).
