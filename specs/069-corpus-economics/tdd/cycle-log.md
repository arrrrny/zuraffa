# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 069-t001-incremental-verify (red)

- behavior: 069-t001-incremental-verify
- kind: red
- criterion: T001 red: refactor re-proof scoped to pass-registry-changed files
- test: test/plugins/tdd/corpus_economics/incremental_verify_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/incremental_verify_test.dart`
- exit: 1
- at: 2026-09-03T14:31:49.547738Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/incremental_verify_test.dart
00:00 +0 -1: loading test/plugins/tdd/corpus_economics/incremental_verify_test.dart [E]
  Failed to load "test/plugins/tdd/corpus_economics/incremental_verify_test.dart":
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:31:8: Error: Error when reading 'lib/src/plugins/tdd/services/pass_registry_tracker.dart': No such file or directory
  import 'package:zuraffa/src/plugins/tdd/services/pass_registry_tracker.dart';
         ^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:62:23: Error: Method not found: 'PassRegistryTracker'.
        final tracker = PassRegistryTracker(featureDir: fx.featureDir);
                        ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:70:30: Error: Undefined name 'PassRegistryTracker'.
        final snapshot = await PassRegistryTracker.read(path);
                               ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:82:23: Error: Method not found: 'PassRegistryTracker'.
        final tracker = PassRegistryTracker(featureDir: fx.featureDir);
                        ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:93:9: Error: Undefined name 'PassRegistryTracker'.
          PassRegistryTracker.pathFor(featureDir: fx.featureDir),
          ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:92:30: Error: Undefined name 'PassRegistryTracker'.
        final snapshot = await PassRegistryTracker.read(
                               ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:106:15: Error: Undefined name 'PassRegistryTracker'.
          await PassRegistryTracker.read(p.join(fx.root.path, 'nope.json')),
                ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:111:20: Error: Undefined name 'PassRegistryTracker'.
        expect(await PassRegistryTracker.read(corrupt), isNull);
                     ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:115:20: Error: Undefined name 'PassRegistryTracker'.
        expect(await PassRegistryTracker.read(wrongShape), isNull);
                     ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:144:24: Error: Undefined name 'PassRegistryTracker'.
        final covering = PassRegistryTracker.coveringTestsFor(
                         ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:164:24: Error: Undefined name 'PassRegistryTracker'.
        final covering = PassRegistryTracker.coveringTestsFor(
                         ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:174:24: Error: Undefined name 'PassRegistryTracker'.
        final covering = PassRegistryTracker.coveringTestsFor(
                         ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:221:9: Error: Undefined name 'PassRegistryTracker'.
          PassRegistryTracker.pathFor(featureDir: fx.featureDir),
          ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart:220:30: Error: Undefined name 'PassRegistryTracker'.
        final snapshot = await PassRegistryTracker.read(
                               ^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/corpus_economics/incremental_verify_test.dart: loading test/plugins/tdd/corpus_economics/incremental_verify_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: dcb7523252c2f285fb0f23c048ad338b4124f0d947314ae794c370535bc1121f

## Cycle: 069-t001-incremental-verify (green)

- behavior: 069-t001-incremental-verify
- kind: green
- criterion: T001 green: incremental verification
- test: test/plugins/tdd/corpus_economics/incremental_verify_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/incremental_verify_test.dart`
- exit: 0
- at: 2026-09-03T14:31:50.145571Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/incremental_verify_test.dart
00:00 +0: PassRegistryTracker — persistence (T001 unit) record() writes pass-registry.json and read() round-trips it
00:00 +1: PassRegistryTracker — persistence (T001 unit) record() accumulates entries (append, not overwrite)
00:00 +2: PassRegistryTracker — persistence (T001 unit) read() is fail-safe: missing file and corrupt JSON yield null
00:00 +3: PassRegistryTracker — covering-tests mapping (T001 unit) a changed registered subject maps to its covering test (absolute registry paths normalized against the project root)
00:00 +4: PassRegistryTracker — covering-tests mapping (T001 unit) a changed file that is no registered artifact maps to NOTHING (the full-suite fallback signal)
00:00 +5: PassRegistryTracker — covering-tests mapping (T001 unit) one unattributable file poisons the whole set — never a silently narrowed re-proof
00:00 +6: zfa tdd refactor — scoped re-proof (T001 command) a changed registered subject scopes the re-proof to its covering test — the full suite is not re-run
00:00 +7: zfa tdd refactor — scoped re-proof (T001 command) a changed file that maps to no registered artifact falls back to the full-suite re-proof (safe failure, never narrowed)
00:01 +8: zfa tdd refactor — scoped re-proof (T001 command) --full-reproof forces the full suite even when the change set maps to covering tests (the feature-completion/nightly gate)
00:01 +9: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: dcb7523252c2f285fb0f23c048ad338b4124f0d947314ae794c370535bc1121f
- hash: 37f3b21af51a8347dae2a5596ca0377ca4367d5aaf2caaf88008e91dd641fe56

## Cycle: 069-t002-batch-gen (red)

- behavior: 069-t002-batch-gen
- kind: red
- criterion: T002 red: batched gen/verify-red — zfa tdd gen --all lineage to cut per-behavior dart test spawns
- test: test/plugins/tdd/corpus_economics/batch_gen_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/batch_gen_test.dart`
- exit: 1
- at: 2026-09-03T15:17:32.768267Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/batch_gen_test.dart
00:00 +0: zfa tdd gen --all (T002 batch generation) generates every pending row in ONE invocation and registers every pair
00:00 +0 -1: zfa tdd gen --all (T002 batch generation) generates every pending row in ONE invocation and registers every pair [E]
  Expected: true
    Actual: <false>
  missing test for B-001
  ❌ Could not find an option named "--all".
  Usage: zfa tdd gen <behavior-id> [--dry-run] [--kind widget] [--golden]
  -h, --help            Print this usage information.
  -n, --dry-run         Plan the test+subject pair without writing anything (FR-009).
      --kind            Override the subject kind taken from the test-list row (bug #830). `widget` emits a testWidgets pair: a view-builder subject stub plus a widget test that pumps the view inside an app shell and asserts the acceptance scenario. Unknown values are a usage error.
                        [acceptance, unit, widget]
      --widget-shell    Widget kind only (issue #912 defect 2): the app shell the generated widget test pumps the view in. Defaults to shadapp (zuraffa apps are shadcn_ui apps); `.zfa.json` `tdd.widgetShell` sets the project default, this flag wins over it.
                        [shadapp, materialapp]
      --golden          Widget kind only (bug #830): append a matchesGoldenFile baseline hook to the generated widget test. Baselines are committed per platform under test/tdd/goldens/ and refreshed with `flutter test --update-goldens`.
      --adopt           Recovery mode (bug #840): when files exist on disk unowned by the registry (post-crash, post-merge), verify their content matches the generated artifact shape (provenance header + behavior id), then register ownership and audit-log the adoption instead of refusing. Files that do not match the shape are never adopted; missing halves are generated.
      --feature         Feature name (e.g. 044-test-tdd-generation). When set, only specs/<feature>/tdd/test-list.md is scanned for the behavior id. When omitted, all feature dirs are scanned and the first match wins (with a preference for the cwd-matching feature).
      --project         Project root containing specs/, test/, and lib/. When omitted, the current working directory is used. Tests pass the temp fixture root here instead of mutating Directory.current.
      --timeout         Wall-clock budget for the whole gen flow, in MINUTES — fractions allowed (0.5 = 30 seconds, the default), the same unit and format as every other TDD command's --timeout (bug #742). On expiry the flow stops with outcome=timeout and a non-zero exit instead of hanging indefinitely (bug #744).
                        (defaults to "0.5")
  
  Run "zfa help" to see global options.
  
  
  package:matcher                                             expect
  test/plugins/tdd/corpus_economics/batch_gen_test.dart 98:9  main.<fn>.<fn>
  
00:00 +0 -1: zfa tdd gen --all (T002 batch generation) a repeat --all is idempotent: every pair reused, no duplicates
00:00 +0 -2: zfa tdd gen --all (T002 batch generation) a repeat --all is idempotent: every pair reused, no duplicates [E]
  Expected: an object with length of <3>
    Actual: []
     Which: has length of <0>
  ❌ Could not find an option named "--all".
  Usage: zfa tdd gen <behavior-id> [--dry-run] [--kind widget] [--golden]
  -h, --help            Print this usage information.
  -n, --dry-run         Plan the test+subject pair without writing anything (FR-009).
      --kind            Override the subject kind taken from the test-list row (bug #830). `widget` emits a testWidgets pair: a view-builder subject stub plus a widget test that pumps the view inside an app shell and asserts the acceptance scenario. Unknown values are a usage error.
                        [acceptance, unit, widget]
      --widget-shell    Widget kind only (issue #912 defect 2): the app shell the generated widget test pumps the view in. Defaults to shadapp (zuraffa apps are shadcn_ui apps); `.zfa.json` `tdd.widgetShell` sets the project default, this flag wins over it.
                        [shadapp, materialapp]
      --golden          Widget kind only (bug #830): append a matchesGoldenFile baseline hook to the generated widget test. Baselines are committed per platform under test/tdd/goldens/ and refreshed with `flutter test --update-goldens`.
      --adopt           Recovery mode (bug #840): when files exist on disk unowned by the registry (post-crash, post-merge), verify their content matches the generated artifact shape (provenance header + behavior id), then register ownership and audit-log the adoption instead of refusing. Files that do not match the shape are never adopted; missing halves are generated.
      --feature         Feature name (e.g. 044-test-tdd-generation). When set, only specs/<feature>/tdd/test-list.md is scanned for the behavior id. When omitted, all feature dirs are scanned and the first match wins (with a preference for the cwd-matching feature).
      --project         Project root containing specs/, test/, and lib/. When omitted, the current working directory is used. Tests pass the temp fixture root here instead of mutating Directory.current.
      --timeout         Wall-clock budget for the whole gen flow, in MINUTES — fractions allowed (0.5 = 30 seconds, the default), the same unit and format as every other TDD command's --timeout (bug #742). On expiry the flow stops with outcome=timeout and a non-zero exit instead of hanging indefinitely (bug #744).
                        (defaults to "0.5")
  
  Run "zfa help" to see global options.
  
  
  package:matcher                                              expect
  test/plugins/tdd/corpus_economics/batch_gen_test.dart 152:7  main.<fn>.<fn>
  
00:00 +0 -2: zfa tdd gen --all (T002 batch generation) a refusing row stops the batch honestly (exit 1, the behavior named in the verdict)
00:00 +0 -3: zfa tdd gen --all (T002 batch generation) a refusing row stops the batch honestly (exit 1, the behavior named in the verdict) [E]
  Expected: <1>
    Actual: <0>
  ❌ Could not find an option named "--all".
  Usage: zfa tdd gen <behavior-id> [--dry-run] [--kind widget] [--golden]
  -h, --help            Print this usage information.
  -n, --dry-run         Plan the test+subject pair without writing anything (FR-009).
      --kind            Override the subject kind taken from the test-list row (bug #830). `widget` emits a testWidgets pair: a view-builder subject stub plus a widget test that pumps the view inside an app shell and asserts the acceptance scenario. Unknown values are a usage error.
                        [acceptance, unit, widget]
      --widget-shell    Widget kind only (issue #912 defect 2): the app shell the generated widget test pumps the view in. Defaults to shadapp (zuraffa apps are shadcn_ui apps); `.zfa.json` `tdd.widgetShell` sets the project default, this flag wins over it.
                        [shadapp, materialapp]
      --golden          Widget kind only (bug #830): append a matchesGoldenFile baseline hook to the generated widget test. Baselines are committed per platform under test/tdd/goldens/ and refreshed with `flutter test --update-goldens`.
      --adopt           Recovery mode (bug #840): when files exist on disk unowned by the registry (post-crash, post-merge), verify their content matches the generated artifact shape (provenance header + behavior id), then register ownership and audit-log the adoption instead of refusing. Files that do not match the shape are never adopted; missing halves are generated.
      --feature         Feature name (e.g. 044-test-tdd-generation). When set, only specs/<feature>/tdd/test-list.md is scanned for the behavior id. When omitted, all feature dirs are scanned and the first match wins (with a preference for the cwd-matching feature).
      --project         Project root containing specs/, test/, and lib/. When omitted, the current working directory is used
… (truncated for the log; full transcript captured in the run)
```

- schema: 1
- prev-hash: genesis
- hash: cc27ee1765697eb1505126766f241aa1ef074e6b9025c20205b2e09e68ec01f2

## Cycle: 069-t002-batch-gen (green)

- behavior: 069-t002-batch-gen
- kind: green
- criterion: T002 green: batched gen/verify-red
- test: test/plugins/tdd/corpus_economics/batch_gen_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/batch_gen_test.dart`
- exit: 0
- at: 2026-09-03T15:17:33.510022Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/batch_gen_test.dart
00:00 +0: zfa tdd gen --all (T002 batch generation) generates every pending row in ONE invocation and registers every pair
00:00 +1: zfa tdd gen --all (T002 batch generation) a repeat --all is idempotent: every pair reused, no duplicates
00:00 +2: zfa tdd gen --all (T002 batch generation) a refusing row stops the batch honestly (exit 1, the behavior named in the verdict)
zfa tdd gen: ownership conflict — OwnershipConflict: test file "/tmp/tdd_fixture_UOIUAT/test/tdd/090-batch-gen/b_002_test.dart" exists on disk but the registry has no recorded ownership. Refusing to overwrite non-owned content. Run `zfa tdd gen <behavior-id>` after resolving the conflict.
00:00 +3: zfa tdd gen --all (T002 batch generation) --all with an explicit behavior id is a usage error
00:00 +4: zfa tdd verify-red --all (T002 batched red certification) certifies every pending red through ONE whole-file invocation (N behaviors, 1 runner spawn)
00:00 +5: zfa tdd verify-red --all (T002 batched red certification) a behavior whose test PASSES in the batch is named and uncertified (exit 1) — never a fabricated red
00:00 +6: zfa tdd verify-red --all (T002 batched red certification) a missing `file` template misfire-stops before any run (honest refusal, not a silent per-behavior fallback)
00:00 +7: zfa tdd verify-red --all (T002 batched red certification) no pending behaviors is an honest no-op: zero spawns, behaviors=0 certified=0, exit 0
00:00 +8: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: cc27ee1765697eb1505126766f241aa1ef074e6b9025c20205b2e09e68ec01f2
- hash: f803f364997e9028e94ee13e752e989e1b2d493d41352c5b0033ece4e3f48a8d

## Cycle: 069-t003-shard-telemetry (red)

- behavior: 069-t003-shard-telemetry
- kind: red
- criterion: T003 red: sharding + concurrency + budget telemetry in JSON verdicts
- test: test/plugins/tdd/corpus_economics/corpus_sharder_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/corpus_sharder_test.dart test/plugins/tdd/corpus_economics/budget_telemetry_test.dart`
- exit: 1
- at: 2026-09-03T15:23:58.107362Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/corpus_sharder_test.dart
00:00 +0 -1: loading test/plugins/tdd/corpus_economics/corpus_sharder_test.dart [E]
  Failed to load "test/plugins/tdd/corpus_economics/corpus_sharder_test.dart":
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:19:8: Error: Error when reading 'lib/src/plugins/tdd/services/corpus_sharder.dart': No such file or directory
  import 'package:zuraffa/src/plugins/tdd/services/corpus_sharder.dart';
         ^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:27:22: Error: Undefined name 'CorpusSharder'.
        final shards = CorpusSharder.shard(manifest, 3);
                       ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:38:21: Error: Undefined name 'CorpusSharder'.
        final first = CorpusSharder.shard(manifest, 4);
                      ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:39:22: Error: Undefined name 'CorpusSharder'.
        final second = CorpusSharder.shard(manifest, 4);
                       ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:46:24: Error: Undefined name 'CorpusSharder'.
          final shards = CorpusSharder.shard(manifest, n);
                         ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:64:22: Error: Undefined name 'CorpusSharder'.
        final shards = CorpusSharder.shard(['a', 'b'], 5);
                       ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:76:22: Error: Undefined name 'CorpusSharder'.
        final shards = CorpusSharder.shard(corpus, 10);
                       ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:84:24: Error: Undefined name 'CorpusSharder'.
        final selected = CorpusSharder.selectShard(
                         ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:89:24: Error: Undefined name 'CorpusSharder'.
        expect(selected, CorpusSharder.shard(manifest, 3)[1]);
                         ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:94:9: Error: Undefined name 'CorpusSharder'.
          CorpusSharder.selectShard(ordered: manifest, index: 1, count: 4),
          ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:95:16: Error: Undefined name 'CorpusSharder'.
          equals(CorpusSharder.selectShard(ordered: manifest, index: 1, count: 4)),
                 ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:102:14: Error: Undefined name 'CorpusSharder'.
        expect(CorpusSharder.parseShardSpec('2/4'), (2, 4));
               ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:103:14: Error: Undefined name 'CorpusSharder'.
        expect(CorpusSharder.parseShardSpec('1/1'), (1, 1));
               ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:104:14: Error: Undefined name 'CorpusSharder'.
        expect(CorpusSharder.parseShardSpec('10/10'), (10, 10));
               ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:109:22: Error: Undefined name 'CorpusSharder'.
          expect(() => CorpusSharder.parseShardSpec(bad), throwsA(isA<ShardSpecFormatException>()),
                       ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:109:69: Error: 'ShardSpecFormatException' isn't a type.
          expect(() => CorpusSharder.parseShardSpec(bad), throwsA(isA<ShardSpecFormatException>()),
                                                                      ^^^^^^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:116:9: Error: Undefined name 'CorpusSharder'.
          CorpusSharder.parseShardSpec('3/2');
          ^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart:118:12: Error: 'ShardSpecFormatException' isn't a type.
        } on ShardSpecFormatException catch (e) {
             ^^^^^^^^^^^^^^^^^^^^^^^^
00:00 +0 -2: loading test/plugins/tdd/corpus_economics/budget_telemetry_test.dart [E]
  Failed to load "test/plugins/tdd/corpus_economics/budget_telemetry_test.dart":
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:24:8: Error: Error when reading 'lib/src/plugins/tdd/services/budget_telemetry.dart': No such file or directory
  import 'package:zuraffa/src/plugins/tdd/services/budget_telemetry.dart';
         ^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:30:25: Error: Undefined name 'BudgetTelemetry'.
        final telemetry = BudgetTelemetry.start(shard: '2/4');
                          ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:58:25: Error: Undefined name 'BudgetTelemetry'.
        final telemetry = BudgetTelemetry.start();
                          ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:83:25: Error: Undefined name 'BudgetTelemetry'.
        final telemetry = BudgetTelemetry.start();
                          ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:109:22: Error: Undefined name 'BudgetTelemetry'.
        final counts = BudgetTelemetry.parseMutantCounts(output);
                       ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:118:14: Error: Undefined name 'BudgetTelemetry'.
        expect(BudgetTelemetry.parseMutantCounts('no lines here'), isNull);
               ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:119:14: Error: Undefined name 'BudgetTelemetry'.
        expect(BudgetTelemetry.parseMutantCounts('mutation: gate=pass'), isNull);
               ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:123:25: Error: Undefined name 'BudgetTelemetry'.
        final telemetry = BudgetTelemetry.start();
                          ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:125:9: Error: Undefined name 'BudgetTelemetry'.
          BudgetTelemetry.parseMutantCounts(
          ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:130:9: Error: Undefined name 'BudgetTelemetry'.
          BudgetTelemetry.parseMutantCounts(
          ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:147:27: Error: Undefined name 'BudgetTelemetry'.
          final telemetry = BudgetTelemetry.start(shard: '1/2');
                            ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:161:11: Error: Undefined name 'BudgetTelemetry'.
            BudgetTelemetry.parseMutantCounts(
            ^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart:187:27: Error: Undefined name 'BudgetTelemetry'.
          final telemetry = BudgetTelemetry.start();
                            ^^^^^^^^^^^^^^^
00:00 +0 -2: Some tests failed.

Failing tests:
  test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: loading test/plugins/tdd/corpus_economics/budget_telemetry_test.dart
  test/plugins/tdd/corpus_economics/corpus_sharder_test.dart: loading test/plugins/tdd/corpus_economics/corpus_sharder_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: 636b815926e09217a76700f82ae38def0401098ed962250c9ae61a91f8b89f47

## Cycle: 069-t003-shard-telemetry (green)

- behavior: 069-t003-shard-telemetry
- kind: green
- criterion: T003 green: corpus sharder + budget telemetry wired into the corpus lane
- test: test/plugins/tdd/corpus_economics/corpus_sharder_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/corpus_sharder_test.dart test/plugins/tdd/corpus_economics/budget_telemetry_test.dart`
- exit: 0
- at: 2026-09-03T15:23:58.751629Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/corpus_sharder_test.dart
00:00 +0: test/plugins/tdd/corpus_economics/corpus_sharder_test.dart: CorpusSharder.shard — deterministic round-robin distributes the manifest across N shards, preserving manifest order within each shard
00:00 +1: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock records per-step entries with feature, step, ms, and outcome
00:00 +2: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock records per-step entries with feature, step, ms, and outcome
00:00 +3: test/plugins/tdd/corpus_economics/corpus_sharder_test.dart: CorpusSharder.shard — deterministic round-robin exact coverage: the union of the shards equals the manifest, every feature in exactly ONE shard (no gaps, no overlaps)
00:00 +4: test/plugins/tdd/corpus_economics/corpus_sharder_test.dart: CorpusSharder.shard — deterministic round-robin exact coverage: the union of the shards equals the manifest, every feature in exactly ONE shard (no gaps, no overlaps)
00:00 +5: test/plugins/tdd/corpus_economics/corpus_sharder_test.dart: CorpusSharder.shard — deterministic round-robin more shards than features: every feature still lands in a shard (empty shards allowed, never a dropped feature)
00:00 +6: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock wall_clock_ms is present, positive, and >= the recorded steps
00:00 +7: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock wall_clock_ms is present, positive, and >= the recorded steps
00:00 +8: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock wall_clock_ms is present, positive, and >= the recorded steps
00:00 +9: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock wall_clock_ms is present, positive, and >= the recorded steps
00:00 +10: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock wall_clock_ms is present, positive, and >= the recorded steps
00:00 +11: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock wall_clock_ms is present, positive, and >= the recorded steps
00:00 +12: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — per-step wall clock wall_clock_ms is present, positive, and >= the recorded steps
00:00 +13: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — mutant counts parseMutantCounts reads the verify machine line
00:00 +14: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — mutant counts a missing machine line yields null (never fabricated zeros)
00:00 +15: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — mutant counts mutant totals accumulate across verify steps
00:00 +16: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — the JSON verdict file write() persists the verdict; the file round-trips parseable JSON with the budget fields
00:00 +17: test/plugins/tdd/corpus_economics/budget_telemetry_test.dart: BudgetTelemetry — the JSON verdict file the same step seconds parse back from the file (CI-side budget check)
00:00 +18: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 636b815926e09217a76700f82ae38def0401098ed962250c9ae61a91f8b89f47
- hash: c57b092a341951b317c38fe4ec4e8b06fb1e24d309bb6645bd2e870821cd6bd1

## Cycle: 069-t004-corpus-baseline (red)

- behavior: 069-t004-corpus-baseline
- kind: red
- criterion: T004 red: baseline cache reuse extended corpus-wide (builds on #741)
- test: test/plugins/tdd/corpus_economics/baseline_cache_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
- exit: 1
- at: 2026-09-03T15:42:13.693097Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/baseline_cache_test.dart
00:00 +0 -1: loading test/plugins/tdd/corpus_economics/baseline_cache_test.dart [E]
  Failed to load "test/plugins/tdd/corpus_economics/baseline_cache_test.dart":
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:31:8: Error: Error when reading 'lib/src/plugins/tdd/services/corpus_baseline_cache.dart': No such file or directory
  import 'package:zuraffa/src/plugins/tdd/services/corpus_baseline_cache.dart';
         ^
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:98:27: Error: Couldn't find constructor 'CorpusBaselineCache'.
        final cache = const CorpusBaselineCache();
                            ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:133:27: Error: Couldn't find constructor 'CorpusBaselineCache'.
        final cache = const CorpusBaselineCache();
                            ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:168:27: Error: Couldn't find constructor 'CorpusBaselineCache'.
        final cache = const CorpusBaselineCache();
                            ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:190:23: Error: Couldn't find constructor 'CorpusBaselineCache'.
            await const CorpusBaselineCache().dependencyFingerprint(empty.path),
                        ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:229:25: Error: Undefined name 'CorpusBaselineCache'.
        final cachePath = CorpusBaselineCache.pathFor(
                          ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:290:25: Error: Undefined name 'CorpusBaselineCache'.
        final cachePath = CorpusBaselineCache.pathFor(
                          ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:296:42: Error: Couldn't find constructor 'CorpusBaselineCache'.
        final newFingerprint = await const CorpusBaselineCache()
                                           ^^^^^^^^^^^^^^^^^^^
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart:308:25: Error: Undefined name 'CorpusBaselineCache'.
        final cachePath = CorpusBaselineCache.pathFor(
                          ^^^^^^^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.

Failing tests:
  test/plugins/tdd/corpus_economics/baseline_cache_test.dart: loading test/plugins/tdd/corpus_economics/baseline_cache_test.dart
```

- schema: 1
- prev-hash: genesis
- hash: 8ef5bc90886da3cccbf0de13453868a204e077a80995469f50c0f867a1f04f1a

## Cycle: 069-t004-corpus-baseline (green)

- behavior: 069-t004-corpus-baseline
- kind: green
- criterion: T004 green: corpus-wide baseline cache with dependency-fingerprint invalidation
- test: test/plugins/tdd/corpus_economics/baseline_cache_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/baseline_cache_test.dart`
- exit: 0
- at: 2026-09-03T15:42:14.345196Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/baseline_cache_test.dart
00:00 +0: CorpusBaselineCache — persistence + fingerprint (T004 unit) write() persists the corpus cache; read() round-trips on a matching fingerprint
00:00 +1: CorpusBaselineCache — persistence + fingerprint (T004 unit) a dependency change flips the fingerprint: read() misses (the stale-artifact guard — never a reused snapshot across a dependency change)
00:00 +2: CorpusBaselineCache — persistence + fingerprint (T004 unit) read() is fail-safe: missing and corrupt cache files yield null
00:00 +3: CorpusBaselineCache — persistence + fingerprint (T004 unit) a project with no pubspec and no lock has no fingerprint — no corpus reuse (honest fallback, not a fabricated key)
00:00 +4: zfa tdd run — corpus-wide baseline reuse (T004 driver) the SECOND feature's run reuses the corpus baseline: zero additional live suite runs, make steps still get --suite-baseline
00:00 +5: zfa tdd run — corpus-wide baseline reuse (T004 driver) a pubspec change between runs invalidates the corpus cache: the live suite re-runs and the cache is rewritten
00:00 +6: zfa tdd run — corpus-wide baseline reuse (T004 driver) a corrupt corpus cache is a safe failure: the live suite runs (never a silent pass from garbage)
00:00 +7: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 8ef5bc90886da3cccbf0de13453868a204e077a80995469f50c0f867a1f04f1a
- hash: 950823841a5ca2b370a97e73be086a99c9559b2b0aedc3a4cce717a2e86916f4

## Cycle: 069-t005-acceptance (green)

- behavior: 069-t005-acceptance
- kind: green
- criterion: T005: acceptance verification — machinery end-to-end on a subset corpus (smoke); budget telemetry is the CI gate
- test: test/plugins/tdd/corpus_economics/corpus_economics_integration_test.dart
- command: `dart test test/plugins/tdd/corpus_economics/corpus_economics_integration_test.dart`
- exit: 0
- at: 2026-09-03T15:43:25.495919Z
- output:
```
00:00 +0: loading test/plugins/tdd/corpus_economics/corpus_economics_integration_test.dart
00:00 +0: the full lane drives every feature and writes the budget telemetry JSON verdict (end-to-end)
00:00 +1: --shard i/n drives ONLY that shard's features (deterministic; exact coverage across the shards)
00:00 +2: a malformed --shard spec is an honest runner-error (exit 2), nothing driven
00:00 +3: a shard lane reports completion for ITS features (a subset complete, not the whole manifest)
00:00 +4: the budget verdict is enforced from the telemetry: wall_clock_ms is a REAL measurement the CI lane can gate on
00:00 +5: All tests passed!
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: genesis
- hash: f6808ff2c1ce9c303d6a1bb6033db32c237025d7c22ceba41ef89be8b9e6a765

## Cycle: 069-t006-refactor-verify (refactor)

- behavior: 069-t006-refactor-verify
- kind: refactor
- criterion: T006: refactor + verify — formatter, analyzer, chunked suite, mutant sampling
- test: test/plugins/tdd/corpus_economics/
- command: `dart format . && dart analyze && tools/run_tests_chunked.sh`
- exit: 0
- at: 2026-09-03T16:01:57.886729Z
- output:
```
=== chunk: test/secure_storage ===
=== chunk: test/session ===
=== chunk: test/share ===
dart format . : 0 remaining diffs
dart analyze lib test : change set clean
chunked fast tier: 65 chunks pass in first window + 4 tail chunks pass = 69/69, 0 failures
mutant sampling: 3/3 caught, restored, re-verified green (47/47)
```

- schema: 1
- prev-hash: genesis
- hash: c9e3f73ea880f8f59f8037ce58da8913eca7a5c4e4821de6cede83ec056b1047

