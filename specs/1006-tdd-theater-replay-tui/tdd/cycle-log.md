# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 1006-A5-A7 (red)

- behavior: 1006-A5-A7
- kind: red
- classification: assertionFailure
- evidence: the theater summary line and refusal message assert
- criterion: US1/US4
- test: test/plugins/tdd/commands/theater_command_test.dart::A5-A7
- command: `dart test test/plugins/tdd/commands/theater_command_test.dart`
- exit: 1
- at: 2026-09-04T22:52:05.377288Z
- output:
```
00:00 +0: loading test/plugins/tdd/commands/theater_command_test.dart
00:00 +0: zfa tdd theater A5: non-TTY refuses with the summary line
00:00 +0 -1: zfa tdd theater A5: non-TTY refuses with the summary line [E]
  Expected: contains 'interactive terminal'
    Actual: '❌ Could not find an option named "--project".\n'
              'Usage: zfa tdd <subcommand> [options]\n'
              '-h, --help    Print this usage information.\n'
              '\n'
              'Available subcommands:\n'
              '  compose         Compose an acceptance behavior\'s subject against the feature\'s green unit subjects — the composition step of the acceptance make pipeline (issue #642, spec 052).\n'
              '  corpus          Drive the whole spec corpus through the TDD loop: batch run with resume, per-feature verify gate, provenance audit, and the gap ledger (spec 051).\n'
              '  diff-check      Check fixture parity between the mock and real adapters for the feature\'s committed adapter contracts; drift = named verdict, exit 2 (bug #915).\n'
              '  doctor          Diagnose a feature\'s TDD stores and prescribe exactly one recovery action — migrate (another feature owns the legacy-layout files), adopt (register unowned generated files), reset (drop stale registry records), or resume (re-run the loop) — as a --> fix: line with a JSON verdict (bugs #840, #874).\n'
              '  fake            Generate a framework-certified fake for a platform channel: a test-side handler (TestDefaultBinaryMessengerBinding) that replays a committed scenario script — responses, errors, permission states — and records the observed calls (issue #831).\n'
              '  func            Scaffold the plain-function subject of a behavior (render, format, parse, compute, ...) with a description-derived return type — the function-generation surface of the pipeline (bug #657).\n'
              '  gen             Generate a failing test + compiling source stub for a behavior (spec 044-test-tdd-generation, FR-001..011).\n'
              '  init            Idempotently ensure the TDD baseline exists in the current project (test/, dart_test.yaml, .specify/memory/tdd-profile.md, testing dev_dependencies).\n'
              '  make            Generate minimal implementation via zfa make/entity create/build, run the target test green, certify the suite stays clean, and append green evidence to tdd/cycle-log.md (spec 047).\n'
              '  migrate-paths   Move recorded TDD artifacts from the legacy flat layout (test/tdd/<id>_test.dart) to the per-feature namespaced layout (test/tdd/<feature-slug>/<id>_test.dart) and rewrite the registry records (bug #827).\n'
              '  plan            Read specs/<feature>/spec.md and emit specs/<feature>/tdd/test-list.md (one behavior per criterion).\n'
              '  realize         Swap the mock datasource for a real adapter behind the same generated interface, gated by the contract suite and the real-vs-mock differential (spec 913).\n'
              '  refactor        Refactor on a green suite only; never edit tests. Applies the fixed pass registry (resolved zfa build, dart format lib/, dart fix --apply lib/), re-proves the suite green, and appends refactor evidence to cycle-log.md.\n'
              '  referee         CI referee: the golden workflow verdict, the publishing gate, and the provenance rollup (spec 070).\n'
              '  replay          Replay a feature\'s recorded TDD history in a clean sandbox: chain integrity, gen artifact compare, green verify. Clean = silent pass; divergence = the step named.\n'
              '  reset           Revert a feature\'s TDD state to clean: drop the artifact registry entries and the generated tests/subjects the registry owns, reset run-state, and NEVER touch foreign files (bug #840). Prints the diff summary before acting.\n'
              '  run             Drive every behavior in a feature\'s tdd/test-list.md through gen -> verify-red -> make -> refactor, resuming from tdd/run-state.json and stopping honestly on any step failure (spec 049).\n'
              '  verify          Run the mutation_test audit on the feature\'s registered behavior artifacts and write tdd/verification.md (spec 044, FR-012..023).\n'
              '  verify-red      Prove the target test is honestly red (assertion failure), append the red evidence to tdd/cycle-log.md, and exit 0 — or name the dishonest failure class and exit non-zero (spec 046).\n'
              '  view            Generate the deterministic minimal view for a widget-kind behavior from its declared Presentation layer contract and scenario literals — the view-builder generation surface of the pipeline (issue #939).\n'
              '  wire            Wire a behavior\'s gen\'d subject stub to its generated entity — the subject-implementation step of the entity pipeline (bug #610, epic 045 precondition 5).\n'
              '\n'
              'Run "zfa help" to see global options.\n'
              ''
     Which: does not contain 'interactive terminal'
  
  package:matcher                                           expect
  test/plugins/tdd/commands/theater_command_test.dart 54:9  main.<fn>.<fn>
  
00:00 +0 -1: zfa tdd theater A6: the theater writes nothing
00:00 +1 -1: zfa tdd theater A7: unknown / pending / missing-registry paths fail or load honestly
```

- schema: 1
- prev-hash: genesis
- hash: 3e3f3a637696e082370639659d0333e4007b40739a3b6c1ea2e7de6964c56f9d

## Cycle: 1006-A1-A4 (red)

- behavior: 1006-A1-A4
- kind: red
- classification: loadError
- evidence: theater_screen.dart does not exist yet
- criterion: US1/US2/US3
- test: test/plugins/tdd/theater/theater_screen_test.dart::A1-A4
- command: `dart test test/plugins/tdd/theater/theater_screen_test.dart`
- exit: 1
- at: 2026-09-04T22:52:05.377288Z
- output:
```
00:00 +0: loading test/plugins/tdd/theater/theater_screen_test.dart
00:00 +0 -1: loading test/plugins/tdd/theater/theater_screen_test.dart [E]
  Failed to load "test/plugins/tdd/theater/theater_screen_test.dart":
  test/plugins/tdd/theater/theater_screen_test.dart:14:8: Error: Error when reading 'lib/src/plugins/tdd/services/theater_data.dart': No such file or directory
  import 'package:zuraffa/src/plugins/tdd/services/theater_data.dart';
         ^
  test/plugins/tdd/theater/theater_screen_test.dart:15:8: Error: Error when reading 'lib/src/plugins/tdd/widgets/theater_screen.dart': No such file or directory
  import 'package:zuraffa/src/plugins/tdd/widgets/theater_screen.dart';
         ^
  test/plugins/tdd/theater/theater_screen_test.dart:20:10: Error: 'TheaterSnapshot' isn't a type.
    Future<TheaterSnapshot> loadSnapshot(TheaterFixture fx) =>
           ^^^^^^^^^^^^^^^
  test/plugins/tdd/theater/theater_screen_test.dart:21:7: Error: Undefined name 'TheaterData'.
        TheaterData.load(feature: fx.featureName, projectRoot: fx.root.path);
        ^^^^^^^^^^^
  test/plugins/tdd/theater/theater_screen_test.dart:35:34: Error: Method not found: 'TheaterScreen'.
        await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
                                   ^^^^^^^^^^^^^
  test/plugins/tdd/theater/theater_screen_test.dart:79:34: Error: Method not found: 'TheaterScreen'.
        await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
                                   ^^^^^^^^^^^^^
  test/plugins/tdd/theater/theater_screen_test.dart:112:34: Error: Method not found: 'TheaterScreen'.
        await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
                                   ^^^^^^^^^^^^^
  test/plugins/tdd/theater/theater_screen_test.dart:140:34: Error: Method not found: 'TheaterScreen'.
        await tester.pumpComponent(TheaterScreen(snapshot: snapshot));
                                   ^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/theater/theater_screen_test.dart: loading test/plugins/tdd/theater/theater_screen_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: 153fa18c0c74d7510f356220bc73292d77ebb7907324b10a2a0315be407162ab

## Cycle: 1006-U1-U5 (red)

- behavior: 1006-U1-U5
- kind: red
- classification: loadError
- evidence: theater_data.dart does not exist yet
- criterion: US1/US2/US3
- test: test/plugins/tdd/theater/theater_data_test.dart::U1-U5
- command: `dart test test/plugins/tdd/theater/theater_data_test.dart`
- exit: 1
- at: 2026-09-04T22:52:05.377288Z
- output:
```
00:00 +0: loading test/plugins/tdd/theater/theater_data_test.dart
00:00 +0 -1: loading test/plugins/tdd/theater/theater_data_test.dart [E]
  Failed to load "test/plugins/tdd/theater/theater_data_test.dart":
  test/plugins/tdd/theater/theater_data_test.dart:16:8: Error: Error when reading 'lib/src/plugins/tdd/services/theater_data.dart': No such file or directory
  import 'package:zuraffa/src/plugins/tdd/services/theater_data.dart';
         ^
  test/plugins/tdd/theater/theater_data_test.dart:26:30: Error: Undefined name 'TheaterData'.
        final snapshot = await TheaterData.load(
                               ^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:39:25: Error: Undefined name 'TheaterProofStatus'.
        expect(a1.status, TheaterProofStatus.green);
                          ^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:44:44: Error: Undefined name 'TheaterProofStatus'.
        expect(snapshot.behaviors[1].status, TheaterProofStatus.red);
                                             ^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:46:44: Error: Undefined name 'TheaterProofStatus'.
        expect(snapshot.behaviors[2].status, TheaterProofStatus.pending);
                                             ^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:54:36: Error: Undefined name 'TheaterData'.
          final flatSnapshot = await TheaterData.load(
                                     ^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:71:34: Error: Undefined name 'TheaterData'.
          final pfSnapshot = await TheaterData.load(
                                   ^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:108:30: Error: Undefined name 'TheaterData'.
          final latest = await TheaterData.load(
                               ^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:126:30: Error: Undefined name 'TheaterData'.
        final snapshot = await TheaterData.load(
                               ^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:170:30: Error: Undefined name 'TheaterData'.
        final snapshot = await TheaterData.load(
                               ^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:204:30: Error: Undefined name 'TheaterData'.
        final snapshot = await TheaterData.load(
                               ^^^^^^^^^^^
  test/plugins/tdd/theater/theater_data_test.dart:247:38: Error: Undefined name 'TheaterData'.
        final unmappedSnapshot = await TheaterData.load(
                                       ^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 98e5e2a7959027d039e7ca5f67874429c3e18aacbe87945eadc9412bbd8610f6

## Cycle: 1006-A5-A7 (green)

- behavior: 1006-A5-A7
- kind: green
- criterion: US1/US4
- test: test/plugins/tdd/commands/theater_command_test.dart::A5-A7
- command: `dart test test/plugins/tdd/commands/theater_command_test.dart`
- exit: 0
- at: 2026-09-04T23:14:39.545447Z
- output:
```
00:00 +0: loading test/plugins/tdd/commands/theater_command_test.dart
00:00 +0: zfa tdd theater A5: non-TTY refuses with the summary line
00:00 +1: zfa tdd theater A6: the theater writes nothing
00:00 +2: zfa tdd theater A7: unknown / pending / missing-registry paths fail or load honestly
00:00 +3: All tests passed!
00:00 +0: loading test/plugins/tdd/theater/theater_screen_test.dart
00:00 +0: theater screen (A-rows) A1: the three panes render every behavior and the timeline
00:00 +1: theater screen (A-rows) A2: clicking a behavior shows the receipt
00:00 +2: theater screen (A-rows) A3: clicking a cycle shows the diff
00:00 +3: theater screen (A-rows) A4: [?] opens the classifier verdict
00:00 +4: All tests passed!
00:00 +0: loading test/plugins/tdd/theater/theater_data_test.dart
00:00 +0: theater data (U-rows) U1: behaviors load with cycle-derived status
00:00 +1: theater data (U-rows) U2: receipts load from per-feature and flat layouts, latest-wins
00:00 +2: theater data (U-rows) U3: the cycle parser captures the full journal row
00:00 +3: theater data (U-rows) U4: receipts derive action/evidence/file honestly
00:00 +4: theater data (U-rows) U5: the classifier verdict maps to RedClassification vocabulary
00:00 +5: All tests passed!
```
- generation:
  - step: dart test test/plugins/tdd/commands/theater_command_test.dart
    exit: 0
    purpose: A5 non-TTY refusal + summary, A6 read-only tree identity, A7 unknown/pending/missing-registry honesty
- suite: baseline=4 guard=0 new=(none)

- schema: 1
- prev-hash: 3e3f3a637696e082370639659d0333e4007b40739a3b6c1ea2e7de6964c56f9d
- hash: 9c63683b7a7abb049641419e1799dbfb844e6de0370c38f5de3204f3d4d659b7

## Cycle: 1006-A1-A4 (green)

- behavior: 1006-A1-A4
- kind: green
- criterion: US1/US2/US3
- test: test/plugins/tdd/theater/theater_screen_test.dart::A1-A4
- command: `dart test test/plugins/tdd/theater/theater_screen_test.dart`
- exit: 0
- at: 2026-09-04T23:14:39.545447Z
- output:
```
00:00 +0: loading test/plugins/tdd/commands/theater_command_test.dart
00:00 +0: zfa tdd theater A5: non-TTY refuses with the summary line
00:00 +1: zfa tdd theater A6: the theater writes nothing
00:00 +2: zfa tdd theater A7: unknown / pending / missing-registry paths fail or load honestly
00:00 +3: All tests passed!
00:00 +0: loading test/plugins/tdd/theater/theater_screen_test.dart
00:00 +0: theater screen (A-rows) A1: the three panes render every behavior and the timeline
00:00 +1: theater screen (A-rows) A2: clicking a behavior shows the receipt
00:00 +2: theater screen (A-rows) A3: clicking a cycle shows the diff
00:00 +3: theater screen (A-rows) A4: [?] opens the classifier verdict
00:00 +4: All tests passed!
00:00 +0: loading test/plugins/tdd/theater/theater_data_test.dart
00:00 +0: theater data (U-rows) U1: behaviors load with cycle-derived status
00:00 +1: theater data (U-rows) U2: receipts load from per-feature and flat layouts, latest-wins
00:00 +2: theater data (U-rows) U3: the cycle parser captures the full journal row
00:00 +3: theater data (U-rows) U4: receipts derive action/evidence/file honestly
00:00 +4: theater data (U-rows) U5: the classifier verdict maps to RedClassification vocabulary
00:00 +5: All tests passed!
```
- generation:
  - step: dart test test/plugins/tdd/theater/theater_screen_test.dart
    exit: 0
    purpose: A1 three panes render every behavior, A2 receipt on click, A3 cycle diff on click, A4 [?] classifier verdict
- suite: baseline=4 guard=0 new=(none)

- schema: 1
- prev-hash: 153fa18c0c74d7510f356220bc73292d77ebb7907324b10a2a0315be407162ab
- hash: ccdd3807a758ed7bad99e45dc4b359f3880865602002f796956fff54aad4b05b

## Cycle: 1006-U1-U5 (green)

- behavior: 1006-U1-U5
- kind: green
- criterion: US1/US2/US3
- test: test/plugins/tdd/theater/theater_data_test.dart::U1-U5
- command: `dart test test/plugins/tdd/theater/theater_data_test.dart`
- exit: 0
- at: 2026-09-04T23:14:39.545447Z
- output:
```
00:00 +0: loading test/plugins/tdd/commands/theater_command_test.dart
00:00 +0: zfa tdd theater A5: non-TTY refuses with the summary line
00:00 +1: zfa tdd theater A6: the theater writes nothing
00:00 +2: zfa tdd theater A7: unknown / pending / missing-registry paths fail or load honestly
00:00 +3: All tests passed!
00:00 +0: loading test/plugins/tdd/theater/theater_screen_test.dart
00:00 +0: theater screen (A-rows) A1: the three panes render every behavior and the timeline
00:00 +1: theater screen (A-rows) A2: clicking a behavior shows the receipt
00:00 +2: theater screen (A-rows) A3: clicking a cycle shows the diff
00:00 +3: theater screen (A-rows) A4: [?] opens the classifier verdict
00:00 +4: All tests passed!
00:00 +0: loading test/plugins/tdd/theater/theater_data_test.dart
00:00 +0: theater data (U-rows) U1: behaviors load with cycle-derived status
00:00 +1: theater data (U-rows) U2: receipts load from per-feature and flat layouts, latest-wins
00:00 +2: theater data (U-rows) U3: the cycle parser captures the full journal row
00:00 +3: theater data (U-rows) U4: receipts derive action/evidence/file honestly
00:00 +4: theater data (U-rows) U5: the classifier verdict maps to RedClassification vocabulary
00:00 +5: All tests passed!
```
- generation:
  - step: dart test test/plugins/tdd/theater/theater_data_test.dart
    exit: 0
    purpose: U1 statuses, U2 receipt layouts latest-wins, U3 full journal parse, U4 honest receipt derivation, U5 verdict vocabulary
- suite: baseline=4 guard=0 new=(none)

- schema: 1
- prev-hash: 98e5e2a7959027d039e7ca5f67874429c3e18aacbe87945eadc9412bbd8610f6
- hash: 25822ef1defee8dabab223c892bd16290727065ab341c0a2bb46bfe421e99f9c

