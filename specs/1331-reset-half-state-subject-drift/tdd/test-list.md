# TDD Test List — Spec 1331 reset half-state subject-drift

One behavior per line, traced to the acceptance criteria (SC-n) in
spec.md. Every behavior is written as a failing test FIRST (RED), then
made to pass (GREEN). Red for this feature is an assertion red: the
half-state survives today (reset keeps drifted-path owned files and
emits no validation), and the re-drive dead-ends at make's
`subject-drift` refusal (the tombstone is never consulted).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Reset deletes a drifted-path owned file: a registry record whose recorded path is RELATIVE (resolved against the project root, not the process CWD) and whose file exists at the recorded location relative to root — reset run from a DIFFERENT process CWD still deletes it | SC-1 | test/plugins/tdd/bug_1331_reset_half_state_test.dart |
| B2 | Reset deletes a generated-shape file at a DRIFTED path: the record's recorded paths do not exist, but the generated layouts (`test/tdd/<feature>/`) hold generated-shape files whose provenance header names the dropped behavior id — reset deletes them too (path-drift recovered) | SC-1 | test/plugins/tdd/bug_1331_reset_half_state_test.dart |
| B3 | Reset warns by name: for every dropped record whose normalized recorded paths did not exist, stdout carries a path-drift warning naming the record id and the recorded path; the verdict JSON carries `path_drift` entries and `deleted_files` | SC-2 | test/plugins/tdd/bug_1331_reset_half_state_test.dart |
| B4 | Reset validates its outcome: the reported deleted-file count equals the printed "will delete N owned files" list; post-deletion re-stat proves zero survivors; a foreign-but-owned-looking file (provenance names a dropped id, but another feature's live registry owns it) is reported BY NAME and kept (`foreign_owned_looking`) | SC-2, SC-3 | test/plugins/tdd/bug_1331_reset_half_state_test.dart |
| B5 | Reset never deletes foreign files: unmarked files and another feature's owned files survive untouched (counted, never deleted — the #840 guarantee holds under the new scan) | SC-3 | test/plugins/tdd/bug_1331_reset_half_state_test.dart |
| B6 | Make adopts the re-drive class: a behavior tombstoned by the last reset whose surviving green evidence PREDATES the tombstone and whose target test passes against the on-disk subject → `zfa tdd make` exits 0 with `outcome=adopted` and appends green evidence binding the CURRENT subject hash | SC-4 | test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart |
| B7 | Run completes the re-drive: after reset of a completed feature, `zfa tdd run <feature>` drives the dropped behaviors to `result=complete` (make step flows past `adopted`; no `subject-drift` stop) | SC-4, SC-6 | test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart |
| B7b | Driver robustness: a make whose `adopted` token disagrees with its exit code is still terminal — the driver records the green evidence the child did not write (the #986 pattern) and advances | SC-4 | test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart |
| B8 | Refusal classes preserved: (a) a green-basis subject drift whose last green evidence POSTDATES the last reset still refuses `subject-drift`; (b) an identical drift on a feature with NO reset tombstone still refuses; (c) the born-green placeholder red-basis refusal still stands | SC-5 | test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart |
| B9 | Doctor's prescription matches reality: the `evidence-without-artifact` drift's `--> fix:` line names `zfa tdd run <feature>` AND explains the mechanics the run actually performs (reconcile to pending, re-enter at gen, make adopts — no subject-drift dead-end) | SC-6 | test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart |
| B10 | End-to-end recovery loop: completed feature → reset → doctor prescribes run (exit 1, `prescription=resume`) → run reaches `result=complete` → doctor healthy (exit 0) after the re-drive | SC-6 | test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart |

## Red protocol

Run per file, never the full suite (cloud-agent disk ceiling):

```
rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
dart test test/plugins/tdd/bug_1331_reset_half_state_test.dart
dart test test/plugins/tdd/bug_1331_make_adopted_re_drive_test.dart
```

Expected RED (against the pre-fix tree):

- B1: the relative recorded path resolves against the process CWD —
  reset misses the file, `deleted_files` lacks it (assertion red).
- B2: no provenance scan exists — the drifted namespaced file survives.
- B3: no `path drift` warning is printed; the verdict carries no
  `path_drift`/`deleted_files` details.
- B4: no post-deletion validation output; `foreign_owned_looking` never
  reported.
- B6: make refuses with `outcome=subject-drift` (the tombstone is not
  consulted).
- B7: the run stops (`result=stopped`, `stopped_at=<id>:make`).
- B9: the fix line promises "run reconciles to pending and re-enters at
  gen" without the adoption mechanics the run needs.
- B10: the loop dead-ends; doctor never re-reaches healthy.

GREEN: after the implementation (T1–T9) all ten pass, plus the existing
reset/make/doctor contracts (SC-7) keep passing:

```
dart test test/plugins/tdd/bug_840_recovery_commands_test.dart
dart test test/plugins/tdd/bug_1264_reset_done_state_phantom_test.dart
dart test test/plugins/tdd/make_command_1036_test.dart
dart test test/plugins/tdd/bug_1162_bug_subject_green_path_test.dart
```

## Mutation check

For test strength, tamper one implementation detail (e.g. make the
reset scan skip the provenance match, or make the adopted probe ignore
the tombstone timestamp) and confirm the mapped behavior flips red —
recorded in tdd/verification.md.
