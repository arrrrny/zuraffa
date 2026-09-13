@Tags(['slow'])
// Bug #1588 — phase-2 refactor pass economics + parked-behavior coupling.
//
// Two root causes, two fixes, one driver contract:
//
//   1. ECONOMICS — every phase-2b refactor spawn re-runs the full pipeline
//      (full-suite preflight + whole-project pass registry + re-proof) even
//      though the previous spawn just proved the identical tree state. The
//      `--pass-batch` flag (driver-only) opts the command into the feature's
//      pass-batch ledger: on a context+tree match the gate is inherited —
//      zero suite runs, zero pass spawns, clean no-op, honest evidence.
//
//   2. COUPLING — a parked BLOCKED behavior's red contract test poisons the
//      refactor gate: the baseline (#741) was captured before gen created
//      the test, so its failure counts as NEW for #922 and every preflight
//      refuses. The `--exempt-behaviors <ids>` flag excludes the parked
//      behaviors' registered tests from the preflight/re-proof failing
//      sets — never tolerating a non-exempt failure (safe fallback kept).
//
// Command-level tests run the REAL `zfa tdd refactor` against fixture
// projects with real `dart test` subprocesses (the refactor_command_test
// harness shape); the suite template points at a logging wrapper so the
// tests count actual suite spawns. Driver-level tests use the scripted
// fake zfa binary (the run_command_test harness shape, fast tier) and
// assert the phase-2b refactor spawn argv carries the driver-only flags.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_blocked_receipt.dart';

import '../helpers/tdd_fixture.dart';

void main() {
  group('command level — parked-behavior exemption (--exempt-behaviors)', () {
    late TddFixture fx;
    late String fakeZfa;

    Future<String> runRefactor({List<String> extraArgs = const []}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
        '--feature',
        fx.featureName,
        '--zfa-bin',
        fakeZfa,
        ...extraArgs,
      ]);
    }

    setUp(() async {
      fx = await TddFixture.create();
      fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
      // Green baseline suite + lib (format/fix no-ops).
      await fx.seedAlreadyCleanLib();
      // The parked contract: registered artifact + red test on disk.
      await fx.registerBehavior(
        id: 'C1',
        description: 'parked contract behavior',
      );
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('bug 1588: a parked behavior\'s red test does not poison the gate — '
        '--exempt-behaviors C1 lets the refactor proceed (exit 0)', () async {
      final before = fx.checksumTestAndLib();
      final out = await runRefactor(extraArgs: ['--exempt-behaviors', 'C1']);

      expect(exitCode, 0, reason: out);
      expect(out, contains(RegExp(r'outcome=(clean|refactored)')), reason: out);
      // The exclusion is named honestly (issue #1588), never a silent
      // absolute-green claim.
      expect(out, contains('1588'));
      expect(out, contains('C1'));
      // Zero files modified by a clean pass.
      expect(fx.checksumTestAndLib(), equals(before));
    });

    test('bug 1588: without the flag the refusal stands — the absolute-green '
        'contract is preserved for a flag-less standalone refactor', () async {
      final before = fx.checksumTestAndLib();
      final out = await runRefactor();

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=not-green'));
      expect(fx.checksumTestAndLib(), equals(before));
    });

    test('bug 1588: the exemption never masks a NON-exempt failure — a second '
        'red test outside the exempt set still refuses', () async {
      await fx.registerBehavior(
        id: 'U2',
        description: 'unrelated red behavior',
      );
      final out = await runRefactor(extraArgs: ['--exempt-behaviors', 'C1']);

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=not-green'));
      // The non-exempt failure is named.
      expect(out.toLowerCase(), contains('unrelated red behavior'));
    });

    test('bug 1588: an exempt id with no registered artifact is ignored '
        '(fail-open) and does not weaken the gate', () async {
      final out = await runRefactor(
        extraArgs: ['--exempt-behaviors', 'GHOST-ID'],
      );

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=not-green'));
    });
  });

  group('command level — pass-batch ledger (--pass-batch)', () {
    late TddFixture fx;
    late String fakeZfa;
    late String suiteLogPath;

    Future<String> runRefactor({List<String> extraArgs = const []}) async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'refactor',
        '--project',
        fx.root.path,
        '--feature',
        fx.featureName,
        '--zfa-bin',
        fakeZfa,
        ...extraArgs,
      ]);
    }

    Future<int> suiteSpawnCount() async {
      final file = File(suiteLogPath);
      if (!await file.exists()) return 0;
      final raw = await file.readAsString();
      return raw.split('\n').where((l) => l.trim().isNotEmpty).length;
    }

    setUp(() async {
      fx = await TddFixture.create();
      fakeZfa = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
      await fx.seedAlreadyCleanLib();
      // A suite template that logs each spawn and delegates to the real
      // `dart test` — the economics assertions count preflights + re-proofs.
      final binDir = Directory(p.join(fx.root.path, 'suite_bin'));
      await binDir.create(recursive: true);
      final script = p.join(binDir.path, 'suite.sh');
      suiteLogPath = p.join(fx.root.path, 'suite_spawns.log');
      await File(script).writeAsString('''
#!/usr/bin/env bash
echo "suite spawn: \$*" >> "$suiteLogPath"
exec dart test "\$@"
''');
      await Process.run('chmod', ['+x', script]);
      // Point the profile's full-suite key at the logging wrapper.
      final memoryDir = Directory(p.join(fx.root.path, '.specify', 'memory'));
      await memoryDir.create(recursive: true);
      await File(p.join(memoryDir.path, 'tdd-profile.md')).writeAsString('''
# TDD Profile — fixture

## Commands

- Single test: `dart test --plain-name x`
- Full suite: `$script`

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test --plain-name x'
suite: '$script'
file: 'dart test {file}'
coverage: 'dart test --coverage'
```
''');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('bug 1588: the second --pass-batch invocation of an unchanged tree '
        'inherits the gate — zero suite runs, exit 0', () async {
      final first = await runRefactor(extraArgs: ['--pass-batch']);
      expect(exitCode, 0, reason: first);
      final spawnsAfterFirst = await suiteSpawnCount();
      // The first invocation pays the pipeline: preflight + re-proof.
      expect(spawnsAfterFirst, 2, reason: first);

      final second = await runRefactor(extraArgs: ['--pass-batch']);
      expect(exitCode, 0, reason: second);
      expect(
        second,
        contains(RegExp(r'outcome=(clean|refactored)')),
        reason: second,
      );
      // The ledger hit is named honestly.
      expect(second, contains('1588'));
      expect(second, contains('pass-batch'));
      // THE economics assertion: no suite spawn on the inherited gate.
      expect(await suiteSpawnCount(), spawnsAfterFirst, reason: second);
      // The ledger exists beside the pass registry.
      expect(
        File(p.join(fx.featureDir, 'tdd', 'pass-batch.json')).existsSync(),
        isTrue,
      );
    });

    test('bug 1588: tree drift invalidates the ledger — the next --pass-batch '
        'invocation re-runs the full pipeline', () async {
      final first = await runRefactor(extraArgs: ['--pass-batch']);
      expect(exitCode, 0, reason: first);
      final spawnsAfterFirst = await suiteSpawnCount();

      // Drift the lib/ tree (still formatted, still green).
      await File(
        p.join(fx.root.path, 'lib', 'baseline.dart'),
      ).writeAsString('int answer() {\n  return 42;\n}\n// drift\n');

      final second = await runRefactor(extraArgs: ['--pass-batch']);
      expect(exitCode, 0, reason: second);
      expect(await suiteSpawnCount(), greaterThan(spawnsAfterFirst));
    });

    test('bug 1588: a flag-less invocation never reads the ledger — the '
        'standalone contract keeps the full pipeline', () async {
      final first = await runRefactor(extraArgs: ['--pass-batch']);
      expect(exitCode, 0, reason: first);
      final spawnsAfterFirst = await suiteSpawnCount();

      final second = await runRefactor();
      expect(exitCode, 0, reason: second);
      // No ledger inheritance: the preflight + re-proof both ran again.
      expect(await suiteSpawnCount(), spawnsAfterFirst + 2, reason: second);
    });
  });

  group('driver level — phase-2b refactor spawn argv', () {
    const feature = '004-login-ui';
    late TddFixture dfx;

    Future<String> drive() async {
      final runner = CliRunner(exitOnCompletion: false);
      return runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        dfx.root.path,
        '--zfa-bin',
        dfx.fakeZfaBin,
      ]);
    }

    Future<List<String>> argvLog() async {
      final file = File(dfx.fakeZfaArgvLogPath);
      if (!await file.exists()) return const [];
      final raw = await file.readAsString();
      return raw
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    }

    /// Seed the blocked verdict's receipt exactly the way the real
    /// `zfa tdd verify-red` writes it (the #1544 resume pattern).
    Future<void> seedBlockedReceipt(
      String behaviorId,
      DateTime blockedAt,
    ) async {
      final store = ContractBlockedReceiptStore(projectRoot: dfx.root.path);
      await store.write(
        ContractBlockedReceipt(
          behavior: behaviorId,
          feature: feature,
          contract: 'User.validateEmail',
          command: 'dart test test/tdd/$feature/contract_c1_test.dart',
          exitCode: 1,
          outputExcerpt: 'Expected: true\n  Actual: false',
          blockedAt: blockedAt.toIso8601String(),
        ),
      );
    }

    /// Create the behavior's generated contract test (the seam file the
    /// change-signal probe watches), mirroring the #827 namespaced layout.
    String seedSeamFile(String behaviorId) {
      final snakeId = behaviorId.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        '_',
      );
      final file = File(
        p.join(dfx.root.path, 'test', 'tdd', feature, '${snakeId}_test.dart'),
      );
      file.createSync(recursive: true);
      file.writeAsStringSync('// seam\nvoid main() {}\n');
      return file.path;
    }

    setUp(() async {
      // Fast tier: no profile, so the #741 baseline never spawns a real
      // suite (the fake zfa scripts every step).
      dfx = await TddFixture.create(featureName: feature, writeProfile: false);
      await dfx.writeFakeZfa();
    });

    tearDown(() {
      dfx.dispose();
      exitCode = 0;
    });

    test('bug 1588: the phase-2b refactor spawn carries --pass-batch and the '
        'parked behavior ids as --exempt-behaviors', () async {
      await dfx.seedTestList([
        (
          id: 'A1',
          description: 'green unit behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'U2',
          description: 'pending stub behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'contract:C1',
          description:
              'User.validateEmail(String email) -> bool (entity method '
              'contract)',
          traces: 'User.validateEmail',
          state: 'PENDING',
          kind: 'contract',
        ),
      ]);
      await dfx.registerBehavior(
        id: 'A1',
        description: 'green unit behavior',
        writeTestFile: false,
      );
      // U2 sits pending WITH a registry record so A1's phase-1 refactor
      // defers pre-spawn (#734) and actually reaches the phase-2b pass.
      await dfx.registerBehavior(
        id: 'U2',
        description: 'pending stub behavior',
      );
      await dfx.registerBehavior(
        id: 'contract:C1',
        description:
            'User.validateEmail(String email) -> bool (entity method '
            'contract)',
        writeTestFile: false,
      );
      await dfx.seedRedEvidence('A1');
      await dfx.seedGreenEvidence('A1');
      await dfx.seedRunState(
        states: {'A1': 'green', 'U2': 'pending', 'contract:C1': 'blocked'},
      );
      // The parked contract's unchanged-blocked receipt (#1544 resume).
      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await seedBlockedReceipt('contract:C1', verdictAt);
      final seamPath = seedSeamFile('contract:C1');
      final before = verdictAt.subtract(const Duration(hours: 1));
      File(seamPath).setLastModifiedSync(before);
      File(dfx.testListPath).setLastModifiedSync(before);

      final out = await drive();

      // The blocked behavior parks the run honestly (#1544 semantics):
      // exit 1, result=blocked — while A1 still reaches done.
      expect(exitCode, 1, reason: out);
      final argv = await argvLog();
      final refactorSpawns = argv
          .where(
            (l) => l.startsWith('tdd refactor A1 ') || l == 'tdd refactor A1',
          )
          .toList();
      expect(refactorSpawns, isNotEmpty, reason: out);
      final lastRefactor = refactorSpawns.last;
      expect(lastRefactor, contains('--pass-batch'), reason: lastRefactor);
      expect(
        lastRefactor,
        contains('--exempt-behaviors contract:C1'),
        reason: lastRefactor,
      );
      // A1 completed its refactor and is done; C1 stays blocked.
      final state =
          (jsonDecode(await File(dfx.runStatePath).readAsString())
                  as Map<String, dynamic>)['behavior_states']
              as Map<String, dynamic>;
      expect(state['A1'], 'done');
      expect(state['contract:C1'], 'blocked');
    });

    test('bug 1588: with no parked behaviors the spawn carries --pass-batch '
        'and NO --exempt-behaviors', () async {
      await dfx.seedTestList([
        (
          id: 'A1',
          description: 'green unit behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'U1',
          description: 'green unit behavior two',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'U2',
          description: 'pending stub behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await dfx.registerBehavior(
        id: 'A1',
        description: 'green unit behavior',
        writeTestFile: false,
      );
      await dfx.registerBehavior(
        id: 'U1',
        description: 'green unit behavior two',
        writeTestFile: false,
      );
      await dfx.registerBehavior(
        id: 'U2',
        description: 'pending stub behavior',
      );
      await dfx.seedRedEvidence('A1');
      await dfx.seedGreenEvidence('A1');
      await dfx.seedRedEvidence('U1');
      await dfx.seedGreenEvidence('U1');
      await dfx.seedRunState(states: {'A1': 'green', 'U1': 'green'});

      final out = await drive();

      expect(exitCode, 0, reason: out);
      final argv = await argvLog();
      final refactorSpawns = argv
          .where(
            (l) =>
                l.startsWith('tdd refactor A1') ||
                l.startsWith('tdd refactor U1'),
          )
          .toList();
      // Per-behavior phase-2b spawns, one per green behavior.
      expect(refactorSpawns.length, 2, reason: out);
      for (final line in refactorSpawns) {
        expect(line, contains('--pass-batch'), reason: line);
        expect(line, isNot(contains('--exempt-behaviors')), reason: line);
      }
      final state =
          (jsonDecode(await File(dfx.runStatePath).readAsString())
                  as Map<String, dynamic>)['behavior_states']
              as Map<String, dynamic>;
      expect(state['A1'], 'done');
      expect(state['U1'], 'done');
    });
  });
}
