// Issue #1544 — `tdd run` parks forever on the first BLOCKED contract.
//
// `blocked` is a legitimate PER-BEHAVIOR verdict (issue #1007: the
// declared contract is unsatisfied), but the run driver treated it as a
// TERMINAL stop of the whole lane: the first blocked contract stopped the
// run, and every resume re-entered at the SAME behavior's verify-red —
// the remaining contract behaviors were unreachable, each attempt
// costing a full refactor pass for zero progress.
//
// The fix (run driver only — the blocked verdict itself, the contract
// lane and the state machine are untouched):
//
//   1. Continue past blocked in the same run: the behavior is PARKED at
//      BLOCKED, the remaining behaviors are driven to their own verdicts,
//      and the run stops at the end with `result=blocked blocked=N`.
//   2. Resume skips an UNCHANGED blocked behavior with a receipt
//      (`skipped: still blocked since <ts>`): the skip fires only when
//      the blocked verdict's receipt exists AND nothing watched changed
//      since it (the seam file, the contract row, the implementation) —
//      any change signal re-drives the behavior honestly (fail open).
//
// Fast tier throughout: the fake zfa scripts every step, no `dart test`
// spawn (kernel-cache-safe fixture rule).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_blocked_receipt.dart';

import '../helpers/tdd_fixture.dart';

/// Reads the process-global `dart:io exitCode` and immediately resets it
/// (the same suite-wide flake guard contract_kind_1007_test.dart uses).
int takeExitCode() {
  final code = exitCode;
  exitCode = 0;
  return code;
}

void main() {
  group('run: blocked contracts are parked, not run-fatal (issue #1544)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(
        featureName: '004-login-ui',
        writeProfile: false,
      );
      await fx.writeFakeZfa();
      // Three contract behaviors: A1 blocks, A2/A3 drive to DONE. The
      // pre-#1544 driver stopped AT A1 — A2/A3 were unreachable.
      await fx.seedTestList([
        (
          id: 'contract:A1',
          description:
              'User.validateEmail(String email) -> bool (entity method '
              'contract)',
          traces: 'User.validateEmail',
          state: 'PENDING',
          kind: 'contract',
        ),
        (
          id: 'contract:A2',
          description:
              'LoginController.login(String email, String password) -> '
              'Result<bool, String> (controller contract)',
          traces: 'LoginController.login',
          state: 'PENDING',
          kind: 'contract',
        ),
        (
          id: 'contract:A3',
          description:
              'LoginUseCase.execute(LoginParams) -> '
              'Future<Result<bool, String>> (usecase contract)',
          traces: 'LoginUseCase.execute',
          state: 'PENDING',
          kind: 'contract',
        ),
      ]);
      await fx.setStepOutcome('verify-red', 'contract:A1', 'blocked');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('a blocked contract parks and the run drives the remaining '
        'contracts to their own verdicts, then stops result=blocked', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // A1 parked BLOCKED — the verdict line and the honest park note.
      expect(out, contains('contract:A1 verify-red -> blocked'));
      expect(out, contains('the cycle is BLOCKED'));

      // A2 and A3 were REACHED and driven to DONE (the bug: they could
      // never be reached — every run stopped at A1's verify-red).
      expect(
        fx.stepInvocations(),
        containsAllInOrder([
          'verify-red contract:A1',
          'gen contract:A2',
          'verify-red contract:A2',
          'make contract:A2',
          'gen contract:A3',
        ]),
      );

      // make NEVER spawned for the blocked contract (issue #1007).
      expect(fx.stepInvocations(), isNot(contains('make contract:A1')));

      // The run stops blocked — with A2/A3 done, not pending.
      expect(out, contains('result=blocked'));
      expect(out, contains('blocked=1'));
      expect(out, contains('done=2'));
      expect(out, contains('stopped_at=contract:A1:verify-red'));
      expect(takeExitCode(), 1, reason: out);

      // The persisted state: A1 blocked, A2/A3 done (bounded, resumable
      // progress — never a fake DONE for the blocked behavior, FR-008).
      final state = _readState(fx.runStatePath);
      expect(state['contract:A1'], 'blocked');
      expect(state['contract:A2'], 'done');
      expect(state['contract:A3'], 'done');
    });

    test('resume skips an unchanged blocked behavior with receipt and '
        'still drives the rest', () async {
      // Run 1: A1 blocks, A2/A3 drive to done (the parked run above).
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
      takeExitCode();

      // The world the resume evaluates: the blocked verdict's receipt
      // (as the real `zfa tdd verify-red` writes it), the seam file and
      // the contract row — all OLDER than the verdict, i.e. unchanged.
      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await _seedBlockedReceipt(fx, 'contract:A1', verdictAt);
      final seamPath = _seedSeamFile(fx, 'contract:A1');
      final before = verdictAt.subtract(const Duration(hours: 1));
      File(seamPath).setLastModified(before);
      File(fx.testListPath).setLastModified(before);

      fx.clearStepInvocations();

      // Run 2 (resume): A1 must be SKIPPED with receipt — not re-driven.
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(
        out,
        contains('contract:A1 verify-red -> skipped (still blocked since'),
      );
      // No step spawned for the unchanged blocked behavior.
      expect(fx.stepInvocations(), isNot(contains('verify-red contract:A1')));
      expect(fx.stepInvocations(), isNot(contains('gen contract:A1')));
      // The run still stops blocked on the parked behavior.
      expect(out, contains('result=blocked'));
      expect(out, contains('blocked=1'));
      expect(takeExitCode(), 1, reason: out);
      // The state is untouched: A1 stays honestly blocked.
      expect(_readState(fx.runStatePath)['contract:A1'], 'blocked');
    });

    test('resume re-drives a blocked behavior when the seam file changed '
        'since the verdict (fail open)', () async {
      // Run 1 parks A1 (same as above).
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
      takeExitCode();

      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await _seedBlockedReceipt(fx, 'contract:A1', verdictAt);
      // The seam file changed AFTER the verdict — the driver must NOT
      // skip: verify-red re-classifies honestly.
      final seamPath = _seedSeamFile(fx, 'contract:A1');
      File(
        seamPath,
      ).setLastModified(verdictAt.add(const Duration(minutes: 30)));

      fx.clearStepInvocations();

      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // The behavior was re-driven (and re-blocked by the scripted fake).
      expect(fx.stepInvocations(), contains('verify-red contract:A1'));
      expect(out, contains('contract:A1 verify-red -> blocked'));
      expect(out, contains('result=blocked'));
      expect(takeExitCode(), 1, reason: out);
    });

    test('resume re-drives a blocked behavior when the implementation '
        'changed since the verdict (lib/ newer than blocked_at)', () async {
      // Run 1 parks A1.
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
      takeExitCode();

      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await _seedBlockedReceipt(fx, 'contract:A1', verdictAt);
      final seamPath = _seedSeamFile(fx, 'contract:A1');
      File(
        seamPath,
      ).setLastModified(verdictAt.subtract(const Duration(hours: 1)));
      File(
        fx.testListPath,
      ).setLastModified(verdictAt.subtract(const Duration(hours: 1)));
      // The implementation changed AFTER the verdict: a lib/ source file
      // newer than blocked_at is a change signal — the unblock path.
      final impl = File(p.join(fx.root.path, 'lib', 'user.dart'));
      impl.createSync(recursive: true);
      impl.setLastModified(verdictAt.add(const Duration(minutes: 1)));

      fx.clearStepInvocations();

      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      expect(fx.stepInvocations(), contains('verify-red contract:A1'));
      expect(out, contains('contract:A1 verify-red -> blocked'));
      expect(out, contains('result=blocked'));
      expect(takeExitCode(), 1, reason: out);
    });

    test('a missing blocked receipt fails open — resume re-drives the '
        'blocked behavior honestly', () async {
      // Run 1 parks A1; NO receipt is seeded (the fixture's fake zfa
      // does not write one either).
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);
      takeExitCode();
      fx.clearStepInvocations();

      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // Fail open: without the receipt there is no `blocked since` to
      // stand on — the behavior re-enters at verify-red (the pre-#1544
      // resume semantics for a blocked state).
      expect(fx.stepInvocations(), contains('verify-red contract:A1'));
      expect(out, contains('result=blocked'));
      expect(takeExitCode(), 1, reason: out);
    });
  });

  group('run: non-blocked resume is untouched (issue #1544 guard)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(
        featureName: '004-login-ui',
        writeProfile: false,
      );
      await fx.writeFakeZfa();
      await fx.seedTestList([
        (
          id: 'U1',
          description: 'a unit behavior',
          traces: 'FR-001',
          state: 'PENDING',
          kind: 'unit',
        ),
        (
          id: 'contract:A1',
          description:
              'User.validateEmail(String email) -> bool (entity method '
              'contract)',
          traces: 'User.validateEmail',
          state: 'PENDING',
          kind: 'contract',
        ),
      ]);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('a red behavior still resumes at make beside a skipped blocked '
        'contract', () async {
      await fx.setStepOutcome('verify-red', 'contract:A1', 'blocked');
      // Seed the resume world directly: U1 certified red (its make is
      // the outstanding step), A1 parked blocked with an unchanged
      // verdict.
      await fx.seedRunState(states: {'U1': 'red', 'contract:A1': 'blocked'});
      await fx.seedRedEvidence('U1');
      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await _seedBlockedReceipt(fx, 'contract:A1', verdictAt);
      final seamPath = _seedSeamFile(fx, 'contract:A1');
      final before = verdictAt.subtract(const Duration(hours: 1));
      File(seamPath).setLastModified(before);
      File(fx.testListPath).setLastModified(before);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        '004-login-ui',
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // The blocked contract is skipped with receipt...
      expect(
        out,
        contains('contract:A1 verify-red -> skipped (still blocked since'),
      );
      expect(fx.stepInvocations(), isNot(contains('verify-red contract:A1')));
      // ...while the red behavior resumes at make exactly as before.
      expect(fx.stepInvocations(), contains('make U1'));
      expect(out, contains('result=blocked'));
      expect(out, contains('done=1'));
      expect(takeExitCode(), 1, reason: out);
    });
  });
}

Map<String, String> _readState(String path) {
  final raw =
      const JsonDecoder().convert(File(path).readAsStringSync())
          as Map<String, dynamic>;
  return (raw['behavior_states'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, v as String),
  );
}

/// Seed the blocked verdict's receipt exactly the way the real
/// `zfa tdd verify-red` writes it (`contract-blocked.<id>.json` under
/// `<project>/.zfa/receipts/`, schema `contract-blocked.v1`).
Future<void> _seedBlockedReceipt(
  TddFixture fx,
  String behaviorId,
  DateTime blockedAt,
) async {
  final store = ContractBlockedReceiptStore(projectRoot: fx.root.path);
  await store.write(
    ContractBlockedReceipt(
      behavior: behaviorId,
      feature: fx.featureName,
      contract: 'User.validateEmail',
      command: 'dart test test/tdd/004-login-ui/contract_a1_test.dart',
      exitCode: 1,
      outputExcerpt: 'Expected: true\n  Actual: false',
      blockedAt: blockedAt.toIso8601String(),
    ),
  );
}

/// Create the behavior's generated contract test (the seam file the
/// change-signal probe watches), mirroring the #827 namespaced layout.
String _seedSeamFile(TddFixture fx, String behaviorId) {
  final snakeId = behaviorId.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  final file = File(
    p.join(fx.root.path, 'test', 'tdd', fx.featureName, '${snakeId}_test.dart'),
  );
  file.createSync(recursive: true);
  file.writeAsStringSync('// seam\nvoid main() {}\n');
  return file.path;
}
