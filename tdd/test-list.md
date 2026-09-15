# TDD test list — Bug #1626 acceptance vacuous-green refusal names the hand step

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1626-w1 | test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart | unit | the shared builder renders the hand-step vocabulary: outcome assertion OUTSIDE the capture, test path, scenario runner subject path, attestation header, `--born-green`, the #1512 why | issue #1626 criterion 2+4 | GREEN |
| U-1626-a1 | test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart | unit | `zfa tdd make` refuses an acceptance guard-only test naming the hand step with BOTH paths (test + subject, project-relative posix) | issue #1626 criteria 1+2+4 | GREEN |
| U-1626-a2 | test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart | unit | the acceptance refusal no longer prescribes the traces/re-plan/re-gen remedy (the provable-loop wording is gone) | issue #1626 criteria 1+3 | GREEN |
| U-1626-a3 | test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart | unit | the unit-lane refusal is unchanged: outcome-assertion wording, `marker if present`, no hand-step vocabulary | issue #1626 criterion 3 (contract preservation) | GREEN |
| U-1626-d1 | test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart | unit | the run driver's make-vacuous-green stop for an ACCEPTANCE row prints the hand-step remedy with both paths; `stopped_at=<id>:make` preserved | issue #1626 criteria 1+2+4, #1308 machine contract | GREEN |
| U-1626-d2 | test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart | unit | the run driver's make-vacuous-green stop for a UNIT/fallback row keeps the traces remedy (the #1483 wording, kind-cell rows) | issue #1626 criterion 3 (contract preservation) | GREEN |
| U-1626-p1 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | unit | A1 pin re-pointed: the acceptance refusal names the hand step (was: pinned the looping traces remedy) | issue #1626 criteria 1+2 | GREEN |
| U-1626-p2 | test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart | unit | A4 pin re-pointed: the refusal of the gen-emitted fallback names the hand step (was: pinned `re-run zfa tdd gen`) | issue #1626 criteria 1+2 | GREEN |

## Red evidence (pre-fix, this session)

Verbatim runs preserved in
`.specify/bugs/1626-acceptance-vacuous-remedy/red-evidence.md`:

- Suite 1 (new, pre-fix): compile red — `Method not found:
  'acceptanceVacuousHandStepRemedyFor'` (the vocabulary had no source).
- Suite 2 (#1488 pins, pre-fix): `+3 -2` — A1/A4 failed on the refusal the
  make side actually printed (the looping `add traces: ... re-run zfa tdd
  plan ...` remedy, no hand-step vocabulary, no paths); A2/A3/U1 green
  (contracts that must not change).
- Suite 3 (new, pre-fix): `+1 -1` — U-1626-d1 failed on the REAL driver stop
  transcript (the fallback traces remedy verbatim); U-1626-d2 green.

## Green evidence (post-fix, this session)

- `dart test test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart`
  → `00:01 +4: All tests passed!`
- `dart test --preset=all
  test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart`
  → `00:13 +2: All tests passed!`
- `dart test --preset=all
  test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart`
  → `00:21 +5: All tests passed!`
- Neighbor wording pins unchanged and green: #1259, #1308, #1320 (U8), #1483
  (shape + driver), #1518 (seam + forward-driver), tdd smoke, run-engine.

## Suite placement note

The make-surface suite lives in `test/plugins/tdd/` beside its neighbor
`bug_1488_acceptance_vacuous_green_test.dart` (fast tier, TddFixture +
CliRunner, no dart-test spawns on the refusal path). The driver suite lives
beside `bug_1483_vacuous_green_remedy_driver_test.dart` (fake-zfa scripted,
`slow` tag per the driver-suite convention). Both run in the chunked sweep;
the slow file via `--preset=all`.
