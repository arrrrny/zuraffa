// Tests for `zfa tdd make`'s build-skip scheduling (issue #1587):
// the make plan's terminal `zfa build` step is skipped when the
// behavior's generation wrote nothing a builder consumes (plain-Dart
// subjects + tests — the reported calculator case), and runs unchanged
// when something builder-consumable DID change.
//
// Drives the public CLI surface against a real temp fixture whose fake
// zfa argv log makes build-step spawning observable.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// Build the CLI args for `zfa tdd make`, pinning the project root.
List<String> makeArgs(TddFixture fx, {required String id, String? zfaBin}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
  args.add(id);
  return args;
}

const _description = 'returns 42 when invoked with no args';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('A1 — plain-Dart generation skips the terminal build step', () {
    test('SC-001: subject rewrite (no annotations) → no `zfa build` '
        'spawn, skip note printed, synthetic audit step in the green '
        'evidence, outcome green exit 0', () async {
      await fx.seedCertifiedRed(
        id: 'U-1587-1',
        description: _description,
        testContent: TddFixture.subjectDrivenTest('U-1587-1', _description),
      );
      // The fake func step writes the plain subject implementation —
      // the reported calculator shape (no annotations, no entities).
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U-1587-1',
            TddFixture.subjectReturning('U-1587-1', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U-1587-1', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains(
          'make: behavior=U-1587-1 outcome=green '
          'feature=${fx.featureName}',
        ),
      );
      // The generation step ran...
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('tdd func')),
        isNotEmpty,
        reason: 'the func step must have run: ${log.join('\n')}',
      );
      // ...and the terminal build step NEVER spawned.
      expect(
        log.where((l) => l.contains('build')),
        isEmpty,
        reason:
            'issue #1587: no builder-consumable input changed — the '
            'whole-project build is pure overhead. Log: ${log.join('\n')}',
      );
      // The decision is printed and auditable.
      expect(out, contains('terminal build step skipped'));
      expect(out, contains('issue #1587'));
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U-1587-1 (green)'));
      expect(cycleLog, contains('note: skipped'));
      // The green evidence stays a LIVE run (the post-generation test
      // ran — the dedup of the precondition is a separate behavior).
      expect(out, contains('target test exit: 0'));
    });
  });

  group('A2 — builder-consumable changes keep the build step', () {
    test('SC-002: an @Zorphy-annotated dart write → build runs '
        '(annotated content never skips)', () async {
      await fx.seedCertifiedRed(
        id: 'U-1587-2',
        description: _description,
        testContent: TddFixture.subjectDrivenTest('U-1587-2', _description),
      );
      // The fake func step rewrites the subject with a doc comment
      // naming @Zorphy. The gate matches RAW content (the DDA route
      // stage's own content-filter precedent): a comment mentioning a
      // builder annotation refuses the skip — the safe direction.
      final annotated = '${TddFixture.subjectReturning('U-1587-2', 42)}'
          '// @Zorphy annotated surface — builders consume this file.\n';
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands('U-1587-2', annotated),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U-1587-2', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('build')),
        isNotEmpty,
        reason: 'annotated writes must keep the build: ${log.join('\n')}',
      );
      expect(out, isNot(contains('terminal build step skipped')));
    });

    test('SC-003: a build config change (pubspec.yaml) → build runs '
        '(config churn never skips)', () async {
      await fx.seedCertifiedRed(
        id: 'U-1587-3',
        description: _description,
        testContent: TddFixture.subjectDrivenTest('U-1587-3', _description),
      );
      final pubspecPath = p.join(fx.root.path, 'pubspec.yaml');
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': [
            ...fx.overwriteSubjectCommands(
              'U-1587-3',
              TddFixture.subjectReturning('U-1587-3', 42),
            ),
            // A comment append keeps the pubspec valid for the live
            // `dart test` runs while changing the config fingerprint.
            "printf '\\n# issue 1587 probe\\n' >> '$pubspecPath'",
          ],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U-1587-3', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('build')),
        isNotEmpty,
        reason: 'config churn must keep the build: ${log.join('\n')}',
      );
      expect(out, isNot(contains('terminal build step skipped')));
    });
  });
}
