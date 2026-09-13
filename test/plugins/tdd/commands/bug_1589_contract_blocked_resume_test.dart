// Issue #1589 — blocked contracts dead-end the documented resume path and
// poison the phase-2 refactor pass.
//
// `make` demands certified red, `verify-red` can never produce it for a
// contract (the BLOCKED verdict, issue #1007, writes a receipt and NO red
// evidence) — the documented resume loop is unbreakable as written, and the
// blocked stop never names the hand surface (the seam file + `zfa tdd wire`).
// Worse, a parked contract's failing seam test is NEW relative to the run's
// baseline (captured before the first gen), so every phase-2 refactor
// preflight refuses and the whole refactor pass is skipped.
//
// The fix under test (messaging + make precondition + refactor-gate
// tolerance ONLY — the BLOCKED verdict itself, the contract lane and the
// state machine are untouched):
//
//   1. The park note and the terminal `result=blocked` block name the hand
//      surface: the seam file path + `zfa tdd wire contract:<n>` (the
//      entity derived from the dotted contract trace).
//   2. `zfa tdd make <contract>` on a parked contract (blocked receipt
//      present, unchanged world per the #1544 watch set) refuses with the
//      plain `implement-seam-first` outcome naming the hand surface —
//      never the misleading "has no certified-red evidence … run
//      verify-red first" dead-end. Any change signal (or a missing
//      receipt) fails open to the existing refusal.
//   3. The driver hands the parked seams it knows about to every refactor
//      spawn (`--parked-seam <path>`); the refactor gate tolerates suite
//      failures inside those files (tested in
//      bug_1589_refactor_parked_seam_test.dart).
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

const feature = '004-login-ui';

void main() {
  group('run: the blocked stop names the hand surface (issue #1589)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: feature, writeProfile: false);
      await fx.writeFakeZfa();
      // Two contract behaviors: A1 blocks (parked), A2 drives to DONE —
      // the parked run of bug_1544_run_continue_after_blocked_test.dart.
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
      ]);
      await fx.setStepOutcome('verify-red', 'contract:A1', 'blocked');
      // The seam file the verdict ran against (the real verify-red writes
      // the receipt beside it; the fixture seeds the seam so the stop can
      // name the file that exists).
      seedSeamFile(fx, 'contract:A1');
      seedSeamFile(fx, 'contract:A2');
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('the park note names the seam + the wire command with the traced '
        'entity', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // THE fix: the blocked stop names the hand surface — where the
      // declared contract is implemented (the seam file) and the command
      // that implements it on the subject.
      expect(out, contains('hand surface:'), reason: out);
      expect(
        out,
        contains('seam test/tdd/$feature/contract_a1_test.dart'),
        reason: out,
      );
      expect(
        out,
        contains('zfa tdd wire contract:A1 --entity User'),
        reason: out,
      );
    });

    test('the terminal result=blocked block names the hand surface too and '
        'the state machine is untouched', () async {
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'run',
        feature,
        '--project',
        fx.root.path,
        '--zfa-bin',
        fx.fakeZfaBin,
      ]);

      // The terminal resume instructions are followable as written.
      expect(
        out,
        contains('seam test/tdd/$feature/contract_a1_test.dart'),
        reason: out,
      );
      expect(out, contains('zfa tdd wire contract:A1'), reason: out);

      // The BLOCKED verdict, the contract lane and the state machine are
      // UNTOUCHED (the #1007/#1544 pins still hold).
      expect(out, contains('contract:A1 verify-red -> blocked'));
      expect(out, contains('the cycle is BLOCKED'));
      expect(out, contains('result=blocked'));
      expect(out, contains('blocked=1'));
      expect(out, contains('done=1'));
      expect(out, contains('stopped_at=contract:A1:verify-red'));
      expect(takeExitCode(), 1, reason: out);
      expect(readState(fx.runStatePath)['contract:A1'], 'blocked');
      expect(readState(fx.runStatePath)['contract:A2'], 'done');
    });
  });

  group(
    'run: phase-2 refactor spawns carry the parked seams (issue #1589)',
    () {
      late TddFixture fx;

      setUp(() async {
        fx = await TddFixture.create(featureName: feature, writeProfile: false);
        await fx.writeFakeZfa();
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
            id: 'U1',
            description: 'a unit behavior that drives green',
            traces: 'FR-001',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);
        await fx.setStepOutcome('verify-red', 'contract:A1', 'blocked');
        seedSeamFile(fx, 'contract:A1');
      });

      tearDown(() {
        fx.dispose();
        exitCode = 0;
      });

      test(
        'a contract parked THIS run hands its seam to the refactor spawn',
        () async {
          final runner = CliRunner(exitOnCompletion: false);
          await runner.runCapturing([
            'tdd',
            'run',
            feature,
            '--project',
            fx.root.path,
            '--zfa-bin',
            fx.fakeZfaBin,
          ]);
          takeExitCode();

          // A refactor step spawned beside a parked contract…
          expect(
            fx.stepInvocations().any((s) => s.startsWith('refactor ')),
            isTrue,
            reason: 'expected a refactor spawn in: ${fx.stepInvocations()}',
          );
          // …and EVERY refactor spawn carries the parked seam so the gate can
          // tolerate the parked contract's failing seam test (pre-existing-
          // failure economics, issue #1589).
          final refactorArgv = fx
              .stepArgvLog()
              .where((line) => line.contains(' refactor '))
              .toList();
          expect(refactorArgv, isNotEmpty, reason: fx.stepArgvLog().join('\n'));
          for (final line in refactorArgv) {
            expect(line, contains('--parked-seam'), reason: line);
            expect(
              line,
              contains('test/tdd/$feature/contract_a1_test.dart'),
              reason: line,
            );
          }
        },
      );

      test('a still-blocked SKIP on resume hands the seam to the refactor '
          'spawn too (the persisted parking, not just this run\'s)', () async {
        // Run 1 parks A1 and persists the blocked verdict's receipt (as the
        // real verify-red child writes it).
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'run',
          feature,
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);
        takeExitCode();
        final verdictAt = DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        );
        await seedBlockedReceipt(fx, 'contract:A1', verdictAt);
        final seamPath = seedSeamFile(fx, 'contract:A1');
        final before = verdictAt.subtract(const Duration(hours: 1));
        File(seamPath).setLastModified(before);
        File(fx.testListPath).setLastModified(before);

        fx.clearStepInvocations();

        // Run 2 (resume): A1 is skipped (still blocked since …), U1 still
        // drives — and its refactor spawn must still carry A1's seam.
        final out2 = await runner.runCapturing([
          'tdd',
          'run',
          feature,
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);
        takeExitCode();

        // The skip fired (the persisted parking is in the world run 2 sees).
        expect(
          out2,
          contains('contract:A1 verify-red -> skipped (still blocked since'),
          reason: out2,
        );

        final refactorArgv = fx
            .stepArgvLog()
            .where((line) => line.contains(' refactor '))
            .toList();
        expect(refactorArgv, isNotEmpty, reason: fx.stepArgvLog().join('\n'));
        for (final line in refactorArgv) {
          expect(
            line,
            contains('test/tdd/$feature/contract_a1_test.dart'),
            reason: line,
          );
        }
      });

      test('a PERSISTED parked verdict (a cold resume) attests its recorded '
          'failure to the refactor spawn', () async {
        // The resume shape seeded directly: the run starts with A1 already
        // BLOCKED and its verdict receipt on disk, so the skip arm is the
        // only thing that parks the seam — a pristine argv log then proves
        // the attestation came from the persisted receipt, not from a
        // parking this run observed itself.
        final verdictAt = DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        );
        await seedBlockedReceipt(fx, 'contract:A1', verdictAt);
        final before = verdictAt.subtract(const Duration(hours: 1));
        File(seedSeamFile(fx, 'contract:A1')).setLastModifiedSync(before);
        File(fx.testListPath).setLastModifiedSync(before);
        await fx.seedRunState(
          states: {'contract:A1': 'blocked', 'U1': 'pending'},
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing([
          'tdd',
          'run',
          feature,
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);
        takeExitCode();

        expect(
          out,
          contains('contract:A1 verify-red -> skipped (still blocked since'),
          reason: out,
        );

        final refactorArgv = fx
            .stepArgvLog()
            .where((line) => line.contains(' refactor '))
            .toList();
        expect(refactorArgv, isNotEmpty, reason: fx.stepArgvLog().join('\n'));
        for (final line in refactorArgv) {
          expect(line, contains('--parked-seam'), reason: line);
          expect(
            line,
            contains('test/tdd/$feature/contract_a1_test.dart'),
            reason: line,
          );
          // Review fix: the persisted verdict's own recorded failure rides
          // along, so the gate's tolerance is pinned to the known red
          // rather than to the whole seam file.
          expect(line, contains('--parked-failure'), reason: line);
          expect(
            line,
            contains('User.validateEmail blocked contract'),
            reason: line,
          );
        }
      });

      test('a parked contract with NO seam file on disk hands no '
          '--parked-seam — the flag never names an unattested file', () async {
        // Review fix: `seamPathFor` can synthesise a plausible path when no
        // candidate exists, and the pre-fix driver seeded that guess
        // unconditionally — a genuine failure in whatever file it named
        // would then be tolerated by the phase-2 gate. The handoff is now
        // existence-gated, so an unattested seam contributes nothing.
        final verdictAt = DateTime.now().toUtc().subtract(
          const Duration(hours: 1),
        );
        await seedBlockedReceipt(fx, 'contract:A1', verdictAt);
        File(
          fx.testListPath,
        ).setLastModifiedSync(verdictAt.subtract(const Duration(hours: 1)));
        File(seedSeamFile(fx, 'contract:A1')).deleteSync();
        await fx.seedRunState(
          states: {'contract:A1': 'blocked', 'U1': 'pending'},
        );

        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing([
          'tdd',
          'run',
          feature,
          '--project',
          fx.root.path,
          '--zfa-bin',
          fx.fakeZfaBin,
        ]);
        takeExitCode();

        final refactorArgv = fx
            .stepArgvLog()
            .where((line) => line.contains(' refactor '))
            .toList();
        expect(refactorArgv, isNotEmpty, reason: fx.stepArgvLog().join('\n'));
        for (final line in refactorArgv) {
          expect(line, isNot(contains('--parked-seam')), reason: line);
        }
      });
    },
  );

  group('make: blocked verdict accepted as precondition (issue #1589)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create(featureName: feature);
      // The parked contract's gen artifacts: the registry record + the
      // seam test (the same shape a real parked run leaves on disk).
      final seamPath = seedSeamFile(fx, 'contract:A1');
      await fx.registerBehavior(
        id: 'contract:A1',
        description:
            'User.validateEmail(String email) -> bool (entity method '
            'contract)',
        sourceCriterion: 'User.validateEmail',
        testPath: seamPath,
        writeTestFile: false,
      );
      await fx.seedTestList([
        (
          id: 'contract:A1',
          description:
              'User.validateEmail(String email) -> bool (entity method '
              'contract)',
          traces: 'User.validateEmail',
          state: 'BLOCKED',
          kind: 'contract',
        ),
      ]);
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    /// Backdate every watched input (the #1544 watch set: the seam file,
    /// the contract row, the implementation) behind [verdictAt] so the
    /// unchanged-world predicate agrees.
    void backdateWorld(DateTime verdictAt) {
      final before = verdictAt.subtract(const Duration(hours: 1));
      File(
        p.join(fx.featureDir, 'tdd', 'test-list.md'),
      ).setLastModified(before);
      for (final dir in [
        Directory(p.join(fx.root.path, 'lib')),
        Directory(p.join(fx.root.path, 'test')),
      ]) {
        if (!dir.existsSync()) continue;
        for (final entity in dir.listSync(recursive: true)) {
          if (entity is File) entity.setLastModified(before);
        }
      }
    }

    test('a parked contract (receipt + unchanged world) refuses with the '
        'plain "implement seam first" stop naming the hand surface', () async {
      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await seedBlockedReceipt(fx, 'contract:A1', verdictAt);
      backdateWorld(verdictAt);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'contract:A1',
        '--feature',
        feature,
        '--project',
        fx.root.path,
      ]);

      // THE fix: no more dead-end loop — the plain, actionable refusal.
      expect(out, contains('implement seam first'), reason: out);
      expect(out, contains('outcome=implement-seam-first'), reason: out);
      expect(
        out,
        contains('seam test/tdd/$feature/contract_a1_test.dart'),
        reason: out,
      );
      expect(
        out,
        contains('zfa tdd wire contract:A1 --entity User'),
        reason: out,
      );
      // The misleading dead-end remedy is GONE for this shape.
      expect(
        out,
        isNot(contains('has no certified-red evidence')),
        reason: out,
      );
      expect(takeExitCode(), isNot(0), reason: out);
      // No green evidence was appended (the contract lane is untouched —
      // the cycle never rides a blocked contract into green).
      final log = File(fx.cycleLogPath);
      if (log.existsSync()) {
        expect(log.readAsStringSync(), isNot(contains('kind: green')));
      }
    });

    test('a changed world (lib/ newer than the verdict) fails OPEN to the '
        'existing not-certified-red refusal', () async {
      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await seedBlockedReceipt(fx, 'contract:A1', verdictAt);
      backdateWorld(verdictAt);
      // The implementation changed AFTER the verdict — the unblock signal:
      // the plain refusal must NOT fire (a stale receipt must not misdirect
      // an in-progress recovery).
      final impl = File(p.join(fx.root.path, 'lib', 'user.dart'));
      impl.createSync(recursive: true);
      impl.setLastModifiedSync(verdictAt.add(const Duration(minutes: 1)));

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'contract:A1',
        '--feature',
        feature,
        '--project',
        fx.root.path,
      ]);

      expect(out, contains('has no certified-red evidence'), reason: out);
      expect(out, isNot(contains('implement seam first')), reason: out);
      expect(takeExitCode(), isNot(0), reason: out);
    });

    test('a missing receipt fails OPEN to the existing refusal', () async {
      // No receipt seeded: the plain refusal must not fire on a guess.
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'contract:A1',
        '--feature',
        feature,
        '--project',
        fx.root.path,
      ]);

      expect(out, contains('has no certified-red evidence'), reason: out);
      expect(out, isNot(contains('implement seam first')), reason: out);
      expect(takeExitCode(), isNot(0), reason: out);
    });

    test('a MISSING seam file fails OPEN to the existing refusal — absence '
        'is a change, never a silence', () async {
      final verdictAt = DateTime.now().toUtc().subtract(
        const Duration(hours: 1),
      );
      await seedBlockedReceipt(fx, 'contract:A1', verdictAt);
      backdateWorld(verdictAt);
      // The seam is GONE (deleted, reset, or never written). Review fix:
      // the pre-fix probe read absence as "unchanged" and prescribed
      // implementing a hand surface that is not on disk, where the driver's
      // equivalent probe re-drives instead.
      File(
        p.join(fx.root.path, 'test', 'tdd', feature, 'contract_a1_test.dart'),
      ).deleteSync();

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'contract:A1',
        '--feature',
        feature,
        '--project',
        fx.root.path,
      ]);

      // The refusal that fires is `make`'s earlier missing-artifact guard
      // (the registry record names a file that is gone) — the point of the
      // fix is only that the implement-seam-first arm did NOT: it must
      // never prescribe a hand surface that is not on disk.
      expect(out, isNot(contains('implement seam first')), reason: out);
      expect(out, isNot(contains('outcome=implement-seam-first')), reason: out);
      expect(takeExitCode(), isNot(0), reason: out);
    });

    test('a NON-contract behavior without red evidence keeps the existing '
        'refusal (the arm is contract-lane scoped)', () async {
      await fx.registerBehavior(
        id: 'U1',
        description: 'a plain unit behavior',
        sourceCriterion: 'FR-001',
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        'U1',
        '--feature',
        feature,
        '--project',
        fx.root.path,
      ]);

      expect(out, contains('has no certified-red evidence'), reason: out);
      expect(out, isNot(contains('implement seam first')), reason: out);
      expect(takeExitCode(), isNot(0), reason: out);
    });
  });
}

Map<String, String> readState(String path) {
  final json =
      const JsonDecoder().convert(File(path).readAsStringSync())
          as Map<String, dynamic>;
  return (json['behavior_states'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, v as String),
  );
}

/// Seed the blocked verdict's receipt exactly the way the real
/// `zfa tdd verify-red` writes it (`contract-blocked.<id>.json` under
/// `<project>/.zfa/receipts/`, schema `contract-blocked.v1`).
Future<void> seedBlockedReceipt(
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
      command: 'dart test test/tdd/$feature/contract_a1_test.dart',
      exitCode: 1,
      // The transcript shape the real verify-red records (the first
      // non-empty lines of the contract test's run) — what the driver
      // parses for `--parked-failure`.
      outputExcerpt:
          '00:00 +0 -1: test/tdd/$feature/contract_a1_test.dart: '
          'User.validateEmail blocked contract [E]\n'
          '00:00 +0 -1: Some tests failed.',
      blockedAt: blockedAt.toIso8601String(),
    ),
  );
}

/// Create the behavior's generated contract test (the seam file), mirroring
/// the #827 namespaced layout. Returns the file's absolute path.
String seedSeamFile(TddFixture fx, String behaviorId) {
  final snakeId = behaviorId.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  final file = File(
    p.join(fx.root.path, 'test', 'tdd', fx.featureName, '${snakeId}_test.dart'),
  );
  file.createSync(recursive: true);
  file.writeAsStringSync('// kind: contract\nvoid main() {}\n');
  return file.path;
}
