# TDD test list — Bug #1660 a skipped refactor pass is indistinguishable from an executed one on stdout — print the skip note

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1660-1 | test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart | integration | a build pass skipped by the #1624 gate prints `pass: build — SKIPPED (build-relevance gate)` + the gate's full note as a `note:` line on stdout, with the synthetic action's honest facts (exit 0, changed none); executed format/fix passes keep the plain header | spec SC-1/SC-2 | RED → GREEN |
| U-1660-2 | test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart | integration | an executed build pass prints the legacy shape — plain `   pass: build` header, command/exit lines, NO SKIPPED marker, NO gate note; the fake-zfa invocation log proves a real spawn | spec SC-3 (no regression) | GREEN (guard) |
| U-1660-3 | test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart | integration | the refactor cycle-log entry mirrors one `note:` line carrying the gate's note inside its output block | spec SC-4 | RED → GREEN |

Fixture design notes:

- The #1624 skip is produced by the REAL gate, never injected: the fixture's
  completed-build marker (`.dart_tool/build/asset_graph.json`) is stamped
  strictly newer than every source/config file the gate walks, so the
  gate's `newer` set is empty and it returns the exact
  `refactorBuildSkippedNote` the issue describes.
- The executed-pass guard (U-1660-2) backdates the marker one hour: the
  config files are newer and the missing #1637 baseline fails the gate
  toward RUN — its documented fail-safe direction — deterministically, with
  no mtime-granularity race deciding the test.
- Gate semantics are untouched (hard constraint): `build_relevance.dart`
  and `refactor_passes.dart` are not modified; the fix lives entirely in
  `refactor_command.dart`'s print loop + cycle-log `capturedOutput`.

Guard pins (pre-existing, unchanged and green against the fix):

| id | suite | description |
| -- | ----- | ----------- |
| U13–U22, A1–A12 | test/plugins/tdd/refactor_command_test.dart | the refactor command's summary-line, preflight, regression, misfire contracts (A12's fake-zfa assertion is a PRE-EXISTING slow-lane failure on master — the #1634 static skip means the build pass never spawns on a fresh fixture; proven identical via `git stash` A/B, unrelated to this fix) |
| #1624 binding + recording | test/plugins/tdd/services/refactor_passes_test.dart | the gate is bound to the build spec only; a note records a synthetic skipped action and never spawns — untouched |
| #1624/#1634/#1637 gate decisions | test/plugins/tdd/services/build_relevance_test.dart | every skip/run decision, config digest tier, and baseline rule — untouched |
| U-1412-1..4 | test/plugins/tdd/bug_1412_refactor_excerpt_tail_test.dart | the run driver's console-excerpt tail over the refactor transcript (whose pass block now carries the marker) — byte-identical recorded evidence |
| #1653 | test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart | the per-phase/per-pass duration lines — unchanged |
| #1540 | test/plugins/tdd/bug_1540_refactor_tracked_restore_test.dart | the tracked-placeholder restore-or-refuse contract and its `[1540]` stdout evidence lines (A6/A7 are PRE-EXISTING slow-lane failures on master for the same #1634 reason as A12; proven identical via `git stash` A/B) |
| #922, #1311, #1520, #1652, #1588 | bug suites driving refactor | baseline tolerance, receipt refresh, scratch tmpdir, make post-state, pass-batch ledger — all green |

## Red evidence (pre-fix, this session)

Real run, unmodified master at `a9329746` + the new suite:

```
dart test test/plugins/tdd/bug_1660_refactor_skip_note_stdout_test.dart --preset=all
→ U-1660-1 [E]:
    Expected: contains 'pass: build — SKIPPED (build-relevance gate)'
      Actual: 'zfa tdd refactor: preflight suite\n'
                '   command: dart test\n'
                '   preflight exit: 0\n'
                'zfa tdd refactor: applying passes\n'
                '   pass: build\n'            ← identical to an executed pass
                ...
→ U-1660-2: passed (the executed shape must not change — correct for a guard)
→ U-1660-3 [E]:
    Expected: contains 'note: refactor build pass skipped:'
      Actual: 'Cycle: 090-tdd-fixture-refactor (refactor)\n...' (no note line)
→ 00:21 +0 -3: Some tests failed.
```

The failing shape IS the issue: the skipped build pass printed
`pass/command/exit/changed` exactly like an executed no-op pass, and the
cycle-log entry carried no note.
