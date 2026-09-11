# Verification: 1518-gen-guard-warning-pre-1483-remedy

## Test-first evidence (red → green)

| behavior | red evidence | green evidence |
| -------- | ------------ | -------------- |
| U-1518-1 (FR-001 legacy single-file gen warning) | RED 1: compile errors — `No named parameter with the name 'projectRoot'` (writer constructor), `Method not found: 'guardOnlyWarningLinesToForward'` (fast suite loading failed) | GREEN: the warning names `hand-edit the test list (specs/1518-warning-seam/tdd/test-list.md) traces cell` and the output contains NO `04-ENGINE`; the guard-only pair is still emitted unchanged |
| U-1518-2 (FR-001 lane-split gen warning) | RED 1 (same loading failure) | GREEN: the warning names `hand-edit the lane plan (specs/1518-warning-seam/tdd/04-ENGINE.md) traces cell`, never `test-list.md` |
| U-1518-3 (FR-001 orphan-skin gen warning) | RED 1 (same loading failure) | GREEN: the warning names `hand-edit the lane plan (specs/1518-warning-seam/tdd/04-SKIN.md) traces cell`, never `04-ENGINE`, never `test-list.md` |
| U-1518-4 (FR-001 no-context branch) | RED 1 (same loading failure) | GREEN: `const BehaviorTestWriter()` (direct library use) prescribes the conservative branch `hand-edit the test list (specs/1518-no-context-seam/tdd/test-list.md) traces cell` |
| U-1518-5 (FR-002 scanner round trip) | RED 1 (same loading failure) | GREEN: over the writer's REAL printed output the scanner forwards exactly 2 lines (token + branched fix); a two-behavior double warning forwards both pairs (4 lines); a stray `--> fix:` line with no preceding token line forwards nothing |
| U-1518-7 (SC-1 transcript agreement, driver) | RED 2: driver suite loading failure (compile) | GREEN: `--preset=all` driver run — the transcript carries exactly two `--> fix:` lines (the forwarded gen warning's and the vacuous-green stop's), BOTH naming `hand-edit the test list (specs/1518-agreeing-remedies/tdd/test-list.md) traces cell`, NEITHER naming `04-ENGINE`; `stopped_at=U1:make` preserved, `stopped_at=U1:hand` absent |
| U-1518-6 (FR-003 pin migration) | n/a by construction — the retirement and the pin migration are ONE atomic change (the issue's stated protocol: "DO NOT edit the constant until that pin is migrated in the same change"); the pre-migration suites could not compile against the retired constant | GREEN: bug_1320 U8 pins BOTH branched branches (wording family), bug_1483 U-1483-1c pins both branched outputs byte-exactly, issue_1308 U-1308-1 pins both branched outputs byte-exactly + U-1308-2 asserts the branched printed remedy — all pass |
| U-1518-REG1 (FR-005 regression guard) | — | GREEN: the run side is untouched — #1483 driver suites (the branched STOP over all three shapes) 3/3, #1308 driver suites (forwarding + stop + hand seam + fail-open) 4/4, #1259 refusal suite green, fuzz auditor (the `const BehaviorTestWriter()` consumer) 13/13 |

## Test runs (cloud-agent scope: changed files only — no full suite)

```text
dart analyze <4 changed lib files + 2 new test files>   → No issues found!
dart analyze (full repo)                                → 112 infos / 0 warnings /
                                                          0 errors — IDENTICAL to the
                                                          pristine-HEAD baseline
dart format --set-exit-if-changed --output=none lib test → 0 changed (exit 0 — the
                                                          CI format gate)

# the feature's suites
dart test test/plugins/tdd/bug_1518_gen_guard_warning_seam_test.dart
          test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart
          test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart
          test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart
                                                          → 21/21 pass
dart test --preset=all test/plugins/tdd/bug_1518_gen_guard_warning_forward_driver_test.dart
          test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart
          test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart
                                                          → 8/8 pass

# adjacent suites over the changed surfaces
dart test <behavior_test_writer, bug_1259, bug_840, bug_874, bug_912,
           bug_964>                                      → 42/42 pass
dart test <bug_1260, bug_912 widget+finders, bug_965 ×2, gen_namespacing_827,
           spec_1256, view_command, bug_1258>            → 60/60 pass
dart test <run_command_path_format, make_command_test, bug_890, bug_1272> → pass
dart test <tdd_command_smoke, tdd_generation_receipt_snapshot>            → pass
dart test test/plugins/tdd/services/spec_fuzz_auditor_test.dart           → 13/13 pass
```

Not re-run on this agent (slow-tier general suites of the UNTOUCHED run side,
whose coverage the passing driver suites already carry:
`run_command_test.dart` / `two_cycle_run_commands_test.dart` /
`run_engine_command_test.dart` / `run_skin_command_test.dart` — the #1518
diff touches no run-side stop/detection/loop code; the forwarding scan they
exercise is covered by U-1308-4 and U-1518-7).

## Transcript demo (the issue's scenario, post-fix)

A legacy single-file feature's ONE transcript now carries TWO AGREEING
`--> fix:` lines (driver-level proof, U-1518-7):

```text
[run] U1 gen -> ok
zfa tdd gen: WARNING [zfa:tdd: guard-only] behavior "U1" — the generated unit
   test's only assertion is the bare UnimplementedError guard: ... (issue #1259)
   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run
   zfa tdd gen, re-run zfa tdd run — or hand-edit the test list
   (specs/1518-agreeing-remedies/tdd/test-list.md) traces cell to FR-00N,
   Row.method and re-run zfa tdd gen (the designed hand-delta seam)
                        ↑ the seam that EXISTS for this shape (was: bare
                          04-ENGINE.md — the #1518 bug)

[run] U1 make -> stopped_at=U1:make
   --> fix: add traces: <ContractRow> to the FR, ... hand-edit the test list
   (specs/1518-agreeing-remedies/tdd/test-list.md) traces cell to FR-00N,
   Row.method and re-run zfa tdd gen (the designed hand-delta seam)
                        ↑ the SAME seam — no contradiction
```

## Mutation evidence (test strength)

- writer branch DELETED (revert to the no-context branch unconditionally) →
  U-1518-2/3 fail (the lane plan / skin plan seam names vanish).
- writer context threading DELETED (gen passes no context) → U-1518-1/2/3
  fail (every shape collapses to the guessed path; U-1518-2's
  `isNot(contains('test-list.md'))` trips).
- scanner widened to forward EVERY line → U-1518-5's `hasLength(2)` /
  `hasLength(4)` trip.
- scanner narrowed to the token line only (drop the fix line) →
  U-1518-5's remedy assertion and U-1518-7's two-agreeing-lines count trip.
- scanner stray-fix guard DELETED (forward any `--> fix:` line) → U-1518-5's
  stray-output case (`isEmpty`) trips.
- constant REINTRODUCED with the old wording → the migration pins
  (U-1308-1/U-1483-1c byte-exact) still hold on the branched builder, and
  the writer/forwarder never read it — the retirement is enforced by the
  analyzer (undefined symbol), not by a runtime assertion.

## Hard-constraint audit

- Messaging only: `git diff` covers `vacuous_guard.dart`,
  `behavior_test_writer.dart`, `run_driver_core.dart` (scan body + comments),
  `gen_command.dart` (context threading), the migrated/new test files, and
  the spec artifacts — no detection, stop, loop, or routing change.
- The run-side stop remedy `_vacuousFallbackRemedy` is byte-unchanged
  (#1502 code); the #1483 driver suites pass unchanged.
- The generated test shape is unchanged (U-1518-1 asserts the emitted guard;
  behavior_test_writer_test.dart 42-file batch green).
- `stopped_at=<id>:make` preserved (U-1518-7); `make`'s refusal unchanged
  (bug_1259_vacuous_green_test.dart green).
- `vacuousGuardFallbackRemedy` retirement + pin migration: one atomic change
  (same commit); `dart analyze` reports no undefined-symbol debris.
