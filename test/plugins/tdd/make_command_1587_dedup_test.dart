// Tests for `zfa tdd make`'s drift-check dedup (issue #1587, criterion
// 4): the make precondition (target-test re-run before generation) is
// satisfied from the verify-red certification when the certified red is
// the behavior's LAST cycle-log entry, carries a subject hash, and the
// CURRENT subject hash matches — the common no-drift path. Every other
// shape fails open to the live re-run.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

List<String> makeArgs(TddFixture fx, {required String id, String? zfaBin}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
  args.add(id);
  return args;
}

const _description = 'returns 42 when invoked with no args';

Future<String> subjectHashOf(TddFixture fx, String id) => File(
  fx.subjectPathOf(id),
).readAsBytes().then(sha256.convert).then((h) => h.toString());

/// Append a red entry carrying a subject hash — the shape the real
/// verify-red appends (issue #1036). Appended AFTER the hashless
/// seedCertifiedRed entry, so it is the behavior's LAST entry.
Future<void> seedHashedRedEvidence(
  TddFixture fx,
  String behaviorId,
  String subjectHash,
) async {
  await File(
    fx.cycleLogPath,
  ).writeAsString('''
## Cycle: $behaviorId (red)

- behavior: $behaviorId
- kind: red
- classification: assertionFailure
- criterion: FR-007
- test: ${fx.testPathOf(behaviorId)}
- command: `dart test ${fx.testPathOf(behaviorId)} --plain-name "$behaviorId"`
- exit: 1
- subject-hash: $subjectHash
- at: 2026-08-30T01:00:00.000Z
- output:
```
Expected: <42>
  Actual: <0>
```

''', mode: FileMode.append);
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('A3 — matching subject hash satisfies the precondition', () {
    test('SC-004: dedup note printed, generation proceeds, green evidence '
        'is live, outcome green exit 0', () async {
      await fx.seedCertifiedRed(
        id: 'U-1587-4',
        description: _description,
        testContent: TddFixture.subjectDrivenTest('U-1587-4', _description),
      );
      await seedHashedRedEvidence(
        fx,
        'U-1587-4',
        await subjectHashOf(fx, 'U-1587-4'),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U-1587-4',
            TddFixture.subjectReturning('U-1587-4', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U-1587-4', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      // The dedup decision is printed...
      expect(
        out,
        contains('drift check satisfied from the certified red evidence'),
      );
      expect(out, contains('issue #1587'));
      // ...generation still ran (the dedup is NOT the skip transition)...
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('tdd func')),
        isNotEmpty,
        reason: 'generation must still run: ${log.join('\n')}',
      );
      // ...and the green evidence is a LIVE post-generation run.
      expect(out, contains('target test exit: 0'));
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U-1587-4 (green)'));
    });
  });

  group('A4 — hashless or drifted reds fail open to the live re-run', () {
    test('SC-005: a hashless certified red runs the live drift check '
        '(no dedup note)', () async {
      await fx.seedCertifiedRed(
        id: 'U-1587-5',
        description: _description,
        testContent: TddFixture.subjectDrivenTest('U-1587-5', _description),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U-1587-5',
            TddFixture.subjectReturning('U-1587-5', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U-1587-5', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      expect(out, isNot(contains('drift check satisfied')));
      expect(out, contains('target test exit: 0'));
    });

    test('a drifted subject (hash mismatch) runs the live drift check',
        () async {
      await fx.seedCertifiedRed(
        id: 'U-1587-6',
        description: _description,
        testContent: TddFixture.subjectDrivenTest('U-1587-6', _description),
      );
      // Certify a hash that does NOT match the on-disk subject — the
      // hand-edited/drifted shape: the dedup must refuse.
      await seedHashedRedEvidence(
        fx,
        'U-1587-6',
        'a' * 64,
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U-1587-6',
            TddFixture.subjectReturning('U-1587-6', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U-1587-6', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      expect(out, isNot(contains('drift check satisfied')));
    });
  });

  group('A5 — a green entry after the last red keeps the live drift', () {
    test('the #694 skip transition stays outcome=skipped (no dedup)',
        () async {
      // Already-made behavior: implemented subject + passing test, red
      // evidence followed by a GREEN entry.
      await fx.seedCertifiedRed(
        id: 'U-1587-7',
        description: _description,
        testContent: TddFixture.greenTest(_description),
        subjectContent: TddFixture.subjectReturning('U-1587-7', 42),
      );
      await fx.seedGreenEvidence('U-1587-7');
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U-1587-7', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      expect(out, contains('outcome=skipped'));
      expect(out, isNot(contains('drift check satisfied')));
      // No generation ran at all (the #694 skip transition).
      expect(await fx.readFakeZfaLog(), isEmpty);
    });
  });
}
