# Verification — Spec 1331 reset half-state subject-drift

Test-first evidence, per tdd/test-list.md. Every number below is an
ACTUAL run result on this branch
(`feat/1331-reset-half-state-subject-drift`), Dart SDK 3.13.3 (stable).

## Test-first protocol

The behaviors were written and run against the PRE-FIX tree first.
RED was an assertion red (the half-state survives / the re-drive
dead-ends), exactly as the test-list predicted:

| Run | Command | Result |
|-----|---------|--------|
| RED 1 | `dart test --preset=all test/plugins/tdd/bug_1331_reset_half_state_test.dart` | `+1 -4` — B1, B2, B3, B4 RED; B5 green (guard: the #840 foreign guarantee held pre-fix) |
| RED 2 | `dart test --preset=all test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart` | `+3 -4` — B6, B7, B9 RED; B8a/b/c, B10 green (guards: the refusal classes and the fake-zfa loop composition held pre-fix) |

RED highlights (the issue's exact dead-ends, reproduced):

- B1: the relative recorded path resolved against the PROCESS CWD —
  the file survived the reset (`Expected: false / Actual: true`).
- B2: no provenance scan — the drifted namespaced generated-shape file
  survived the reset.
- B3: no `path drift` warning anywhere in reset's stdout; the verdict
  carried no `path_drift`/`deleted_files` details.
- B6: the real `zfa tdd make` refused the tombstoned re-drive with
  `outcome=subject-drift` (exit 1) — the issue's `A2 make ->
  subject-drift => result=stopped` dead-end.
- B7: the run driver stopped on the adopted make
  (`result=stopped` pre-fix; the first RED run ended exit 1).
- B9: doctor's `--> fix:` line promised "run reconciles to pending and
  re-enters at gen" with no mention of the adoption the run needs.

## Green evidence

| Run | Command | Result |
|-----|---------|--------|
| GREEN (post T1–T9) | both 1331 files | `+13` (after B7 split into B7/B7b) — all pass |
| GREEN (post `dart format`) | both 1331 files | `+13: All tests passed!` |

The implementation that flipped them:

- `reset_command.dart`: recorded paths normalized against the project
  root (`normalizeArtifactPath`); recursive provenance scan of
  `test/tdd` + `lib/tdd` (`matchesGeneratedTestShape` /
  `matchesGeneratedSubjectShape` + `behaviorIdFromContent`) recovering
  path-drifted owned files; cross-registry guard (`foreignOwnerOf`)
  keeps another feature's files (reported by name); post-deletion
  outcome validation (survivors named, `deleted_files` = actual
  deletions); verdict details `path_drift` / `foreign_owned_looking` /
  `deleted_files`.
- `models/generation_plan.dart`: `MakeOutcome.adopted`.
- `services/journal.dart`: `JournalReader.lastResetTombstone` (last
  tombstone's behavior ids + timestamp; fail-closed on absent/corrupt
  streams); `tombstonedBehaviors` now delegates to it (identical
  semantics for the run driver).
- `commands/make_command.dart`: `_tombstonedReDrive` probe
  (tombstoned AND the last green entry either is absent entirely or its
  timestamp predates the tombstone — a green entry that is present but
  carries an empty/unparseable timestamp fails closed; the adoption path prints the re-drive note, appends green evidence
  binding the CURRENT subject hash, and reports `outcome=adopted`
  (verdict outcome `pass`, exit 0). The `_subjectDriftRefusal` logic is
  untouched and still runs for every non-re-drive class.
- `services/step_runner.dart`: make success predicate accepts `adopted`.
- `commands/run_driver_core.dart`: the terminal make arm accepts
  `skipped` OR `adopted` (the #986 driver-recorded evidence pattern;
  the disagreement print names the #1331 transition; the emitted step
  outcome is `adopted`).
- `commands/doctor_command.dart`: the evidence-without-artifact
  prescription names the adoption mechanics the run performs.
- `test/plugins/tdd/helpers/tdd_fixture.dart`: the fake zfa gained the
  additive `adopt` make outcome (green evidence + `outcome=adopted` +
  exit 0 — mirrors the real make's adopted shape; no existing outcome
  changed).

## Regression evidence (SC-7)

| Suite | Result | Note |
|-------|--------|------|
| `bug_1264_reset_done_state_phantom_test.dart` + `make_command_1036_test.dart` + `bug_1162_bug_subject_green_path_test.dart` | `+15: All tests passed!` | the reset tombstone / #1036 / #1162 contracts |
| `run_command_test.dart` + `run_command_path_format_test.dart` + `json_flag_test.dart` + `verdict_envelope_test.dart` + `two_cycle_run_commands_test.dart` | `+26: All tests passed!` | driver + verdict envelope contracts |
| `runner_test.dart` + `runner_suite_test.dart` + `bug_1258_skin_author_make_test.dart` | `+20: All tests passed!` | step runner + authoring contracts |
| `bug_840_recovery_commands_test.dart` | `+4 -5` | UNCHANGED from the pre-change baseline on this branch: the same 5 tests fail on master HEAD (the suite expects the pre-#969 legacy raw-JSON verdict line; reset/doctor/gen now emit the text verdict in non-JSON mode). PRE-EXISTING, unrelated to this fix — not repaired here (out of scope), not worsened (same +4 -5 before and after). |

## Mutation check (test strength)

| Mutation | Expected | Actual |
|----------|----------|--------|
| `_tombstonedReDrive` ignores the tombstone timestamp (adopt whenever tombstoned) | B8a flips RED (the post-reset authoritative green evidence must still refuse) | `+0 -1: Some tests failed.` — killed |
| reset's provenance scan returns empty (drifted files never recovered) | B2 flips RED (the drifted generated-shape file survives) | `+0 -1: Some tests failed.` — killed |

Both mutations were reverted; the final green run above is the
unmutated tree.

## Static analysis and formatting

- `dart analyze` over every touched lib file and both new test files:
  `No issues found!`
- `dart format .` run over the changed files: `Formatted 10 files (5
  changed)`; a follow-up `git diff --stat` check shows zero remaining
  formatting diffs (see the PR's format gate).

## Success criteria: PROVED vs NOT PROVED

- **SC-1 (reset deletes all owned files): PROVED** — B1, B2.
- **SC-2 (reset validates its outcome): PROVED** — B3, B4 (warnings by
  name, count = actual deletions, zero survivors, verdict details).
- **SC-3 (foreign files never deleted): PROVED** — B4 (foreign-owned
  reported by name, kept), B5 (unmarked strays + another feature's
  files survive).
- **SC-4 (make adopts the re-drive class): PROVED** — B6 (real make,
  real `dart test`: `outcome=adopted`, exit 0, current subject hash
  bound), B7/B7b (the run loop advances past adopted to complete).
- **SC-5 (refusal classes preserved): PROVED** — B8a (post-reset
  authoritative evidence still refuses), B8b (no tombstone still
  refuses), B8c (born-green placeholder still refuses with the
  `--re-certify` remedy), plus the untouched #1036/#1162 suites (+15).
- **SC-6 (run completes; doctor truthful): PROVED with one scope
  note** — B7/B7b prove the run reaches `result=complete` past
  `adopted`; B9 proves the prescription names the adoption; B10 proves
  the reset → doctor → run → doctor-healthy loop composes. The B10
  loop drives steps through the scripted fake zfa (the fixture
  convention for driver-level composition, same as the #1264 suite);
  the per-step semantics of the REAL adopted make are proven by B6.
- **SC-7 (no regressions): PROVED** for every touched-contract suite
  listed above; the only failing file (`bug_840_recovery_commands_test.dart`)
  fails identically on the unmodified branch (pre-existing, flagged).

## Disk housekeeping

Kernel cache (`rm -rf .dart_tool/test/`) cleaned after every test
invocation in this verification (the house cloud-agent rule); only the
touched contracts' test files were ever run — the full suite was never
compiled.
