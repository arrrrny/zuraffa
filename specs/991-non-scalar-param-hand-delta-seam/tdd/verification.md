# Verification: 991-non-scalar-param-hand-delta-seam (issue #1323)

**Verdict: PASSED** — every behavior test-first (red certified before
implementation), every spec success criterion proved by an executed test,
3/3 targeted mutants killed by the new suites.

## Test-first evidence

The red phase ran BEFORE any implementation existed (see
`tdd/cycle-log.md`, cycle `991-hand-delta-seam (red)`):

| Test | Red evidence |
| --- | --- |
| `arg_placeholder_test.dart` (9) | load-error red — `arg_placeholder.dart` did not exist |
| U-1323-1 | `Expected: contains 'outcome=hand-delta-required'` / `Actual: make: behavior=U6 outcome=generation-error feature=1323-hand-delta` |
| U-1323-3 | generated test carried the `_arg0()` helper — no `Object()` at the capture site |
| U-1323-5 / U-1323-5b | cycle 1 stopped with the generic `generation-error`, blocking the re-certification flow |
| U-1323-6 | `Expected: contains 'stopped_at=U1:hand'` / `Actual: ... stopped_at=U1:make` |
| U-1323-2, U-1323-4 | backward-compat pins — green before and after the change (the generic stop and the scalar literals are UNCHANGED) |

## Green evidence (final pass, post-format)

| Suite | Result | Command |
| --- | --- | --- |
| fast tier (arg_placeholder + 1308 fast + red_classifier + writer + subject_writer) | 71 passed | `dart test test/plugins/tdd/arg_placeholder_test.dart test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart test/plugins/tdd/red_classifier_test.dart test/plugins/tdd/behavior_test_writer_test.dart test/plugins/tdd/subject_writer_test.dart` |
| slow tier (1323 seam + 1323 driver + 1308 driver + 1259) | 18 passed | `dart test --preset=all test/plugins/tdd/issue_1323_hand_delta_seam_test.dart test/plugins/tdd/issue_1323_hand_delta_driver_test.dart test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart test/plugins/tdd/bug_1259_vacuous_green_test.dart` |
| make/run adjacency (1036 + declared_071 + path_format) | 11 passed | `dart test --preset=all test/plugins/tdd/make_command_1036_test.dart test/plugins/tdd/make_command_declared_071_test.dart test/plugins/tdd/run_command_path_format_test.dart` |
| run driver (spec 049) | 49 passed | `dart test --preset=all test/plugins/tdd/run_command_test.dart` |
| `dart analyze` (all 8 changed files) | No issues found | `dart analyze <changed files>` |
| `dart format` (all 8 changed files) | 0 changed | `dart format --output=none --set-exit-if-changed <changed files>` |

Pre-existing, unrelated failures (flagged, NOT introduced by this change):
`make_command_test.dart` bug-829 group — 5 failures (U-829g/h and
siblings) reproduce IDENTICALLY on the base commit with the change
stashed (`+33 -5` both with and without the fix). Environmental: the
entity-pipeline plan's `make User` step is absent from the fake-zfa log
in this sandbox.

## Mutation evidence (targeted mutants on the changed code, 3/3 killed)

| Mutant | Change | Killed by | Result |
| --- | --- | --- | --- |
| M1 | removed `case 'Object': return 'Object();'` from `_scalarLiteral` | U-1323-3 | FAILED under mutant (killed), green after restore |
| M2 | `_argPlaceholderDiagnosis` returns null always | U-1323-1 + U-1323-5 | FAILED under mutant (killed), green after restore |
| M3 | driver arm condition `false && ...` | U-1323-6 | FAILED under mutant (killed), green after restore |

Mutation scope: the three production functions this feature adds/changes
(`_scalarLiteral`'s new case, make's `_argPlaceholderDiagnosis` arm, the
run driver's `hand-delta-required` arm). The full-package MutationAuditor
was not run: it requires the feature's gen `artifacts.json` registry and
a green-suite preflight over the whole package (the ~6.5 GB kernel-cache
full suite the cloud-agent protocol forbids); the targeted mutants above
audit exactly the changed surface.

## Success criteria

- **SC-1 PROVED** — U-1323-1: make stops `outcome=hand-delta-required`,
  names `replace _arg0()` + test path + `representative Object` +
  `then re-run zfa tdd make U6`; no green evidence; subject restored.
- **SC-2 PROVED** — U-1323-5/5b: after the hand-edit, re-running make
  re-runs the UPDATED test (drift check): a red re-cert proceeds to
  generation and lands `green` (generation ran in cycle 2); a green
  re-cert takes the `skipped` transition and generation never spawns.
- **SC-3 PROVED** — U-1323-3: `reason(Object error) -> String` generates
  `Object()` at the capture site, no `_arg` helper, no placeholder
  message.
- **SC-4 PROVED** — U-1323-4: `String/int/num/bool/double` still emit
  `'sample'`, `0`, `0`, `false`, `0.0` verbatim.
- **SC-5 PROVED** — U-1323-6: the run driver reports
  `stopped_at=<id>:hand` (never `:make` for this outcome) and the lane
  journal carries `hand-step=<id>:hand` with the exact edit.

## Backward-compatibility proof

- U-1323-2 (generic `generation-error` on an unrelated red) — green.
- U-1323-4 (scalar literals byte-identical) — green.
- The full 1308 + 1259 + run_command suites (49 + 11 + 18 behaviors)
  stay green over the changed make/driver/writer files.
