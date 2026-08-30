@Tags(['slow'])
// Tests for `MakeCommand` (spec 047-tdd-make, T010/T014/T018/T022/T025).
// Drives the public CLI surface (`zfa tdd make`) against a real temp
// fixture project whose registry records gen-style artifacts; the
// runner executes a REAL `dart test` subprocess inside the fixture.
//
// The fixture root is passed explicitly via `--project`, so this suite
// never mutates the process-global Directory.current (which concurrent
// test files share and can corrupt).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// Build the CLI args for `zfa tdd make`, pinning the project root.
List<String> makeArgs(
  TddFixture fx, {
  String? id,
  String? zfaBin,
  String? feature,
}) {
  final args = <String>['tdd', 'make', '--project', fx.root.path];
  if (feature != null) args.addAll(['--feature', feature]);
  if (zfaBin != null) args.addAll(['--zfa-bin', zfaBin]);
  if (id != null) args.add(id);
  return args;
}

/// A target test that turns green when the fake `zfa` script generates its
/// production subject on `entity create`.
const _targetDescription = 'create entity User with email';

const _greenTest =
    '''
import 'package:test/test.dart';

void main() {
  test('$_targetDescription', () {
    expect(1, equals(1));
  });
}
''';

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('US1 — happy path (certified red → green via pipeline)', () {
    test('U26/A1/A3: certified-red behavior generates via pipeline, target '
        'test passes without changing the test tree, exit 0, summary line, '
        'complete green entry', () async {
      // Seed the certified-red precondition.
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: _targetDescription,
        testContent: TddFixture.subjectDrivenTest('B-001', _targetDescription),
      );
      final testTreeBefore = fx.checksumTestTree();

      // The fake pipeline turns the test green by writing production source.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': fx.overwriteSubjectCommands(
            'B-001',
            TddFixture.subjectReturning('B-001', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
      );

      // Summary line + exit 0.
      expect(
        out,
        contains(
          'make: behavior=B-001 outcome=green feature=${fx.featureName}',
        ),
      );
      expect(exitCode, 0, reason: 'green certified must exit 0');
      expect(fx.checksumTestTree(), equals(testTreeBefore));

      // Green entry contains all contract fields including the
      // recorded generation commands.
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('## Cycle: B-001 (green)'));
      expect(log, contains('- behavior: B-001'));
      expect(log, contains('- kind: green'));
      expect(log, contains('- criterion:'));
      expect(log, contains('- generation:'));
      expect(log, contains('zfa entity create'));
      expect(log, contains('purpose: create entity'));
      expect(log, contains('- suite: baseline='));
      expect(log, contains('guard='));
    });

    test('A2: a certified run records the generation commands', () async {
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: _targetDescription,
        testContent: TddFixture.subjectDrivenTest('B-001', _targetDescription),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': fx.overwriteSubjectCommands(
            'B-001',
            TddFixture.subjectReturning('B-001', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(makeArgs(fx, id: 'B-001', zfaBin: zfaBin));
      expect(exitCode, 0);

      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('- generation:'));
    });
  });

  group('US2 — refuse without certified red', () {
    test('U23/A4: no red evidence refuses with not-certified-red BEFORE any '
        'pipeline invocation', () async {
      // Register behavior but DO NOT seed red evidence.
      await fx.registerBehavior(id: 'B-001', description: _targetDescription);

      // The fake zfa script will be set up; if the command runs ANY
      // pipeline invocation, the log file will exist.
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
      );
      expect(out, contains('certified-red'));
      expect(out, contains('verify-red'));
      expect(
        out,
        contains(
          'make: behavior=B-001 outcome=not-certified-red '
          'feature=${fx.featureName}',
        ),
      );
      expect(exitCode, isNot(0));
      // Pipeline NEVER invoked.
      final log = await fx.readFakeZfaLog();
      expect(
        log,
        isEmpty,
        reason: 'pipeline must not run before preconditions',
      );
      // No cycle-log entry appended.
      final cycleLog = await File(fx.cycleLogPath).exists()
          ? await File(fx.cycleLogPath).readAsString()
          : '';
      expect(cycleLog, isNot(contains('## Cycle: B-001 (green)')));
    });

    test(
      'U24/A5: unknown behavior id refuses before any pipeline invocation',
      () async {
        final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'B-999', zfaBin: zfaBin),
        );
        expect(out, contains('B-999'));
        expect(out, contains('unknown behavior id'));
        // Without --feature, an unknown id has no resolvable feature
        // context (mirrors verify-red_command.dart's behavior).
        expect(
          out,
          contains(
            'make: behavior=B-999 outcome=runner-error '
            'feature=unknown',
          ),
        );
        expect(exitCode, isNot(0));
        final log = await fx.readFakeZfaLog();
        expect(log, isEmpty);
      },
    );

    test('a valid registry record with a missing test file is a hard '
        'runner-error before any pipeline invocation', () async {
      await fx.registerBehavior(
        id: 'B-002',
        description: _targetDescription,
        writeTestFile: false,
      );
      await fx.seedRedEvidence('B-002');
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-002', zfaBin: zfaBin),
      );

      expect(out, contains('missing test file'));
      expect(out, contains('zfa tdd gen B-002'));
      expect(out, contains('outcome=runner-error'));
      expect(exitCode, isNot(0));
      expect(await fx.readFakeZfaLog(), isEmpty);
    });

    test(
      'U25/A6: already-green target test → drift reported, exit non-zero',
      () async {
        // Seed the certified-red precondition, but with a GREEN test
        // (simulating someone having hand-implemented the behavior).
        await fx.seedCertifiedRed(
          id: 'B-001',
          description: _targetDescription,
          testContent: TddFixture.greenTest(_targetDescription),
        );
        final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
        );
        expect(out, contains('drift'));
        expect(
          out,
          contains(
            'make: behavior=B-001 outcome=drift feature=${fx.featureName}',
          ),
        );
        expect(exitCode, isNot(0));
        // Pipeline NEVER invoked — drift detected before generation.
        final log = await fx.readFakeZfaLog();
        expect(log, isEmpty);
      },
    );
  });

  group('US3 — regression guard via the full suite', () {
    test('U15/U17/A7: clean guard → green entry records both target-test '
        'pass and full-suite pass', () async {
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: _targetDescription,
        testContent: TddFixture.subjectDrivenTest('B-001', _targetDescription),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': fx.overwriteSubjectCommands(
            'B-001',
            TddFixture.subjectReturning('B-001', 42),
          ),
        },
      );
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
      );
      expect(exitCode, 0);
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('- suite: baseline='));
      expect(log, contains('guard='));
      expect(log, contains('new=(none)'));
      expect(out, contains('outcome=green'));
    });

    test('A8: sibling regression → exit non-zero naming the regressed test, '
        'no green entry, source left in place', () async {
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: _targetDescription,
        testContent: TddFixture.subjectDrivenTest('B-001', _targetDescription),
      );
      // Pre-existing sibling GREEN test that the fake pipeline
      // will BREAK on entity create (regression scenario).
      await fx.seedSiblingGreenTest(
        id: 'B-SIB',
        description: 'sibling green test passes',
      );

      // The fake pipeline turns the target green but changes production
      // source so the sibling test becomes a NEW failure.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': [
            ...fx.overwriteSubjectCommands(
              'B-001',
              TddFixture.subjectReturning('B-001', 42),
            ),
            ...fx.overwriteSubjectCommands(
              'B-SIB',
              TddFixture.subjectReturning('B-SIB', 2),
            ),
          ],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
      );
      expect(exitCode, isNot(0));
      expect(out, contains('regression'));
      expect(out, contains('sibling green test passes'));
      expect(
        out,
        contains(
          'make: behavior=B-001 outcome=regression '
          'feature=${fx.featureName}',
        ),
      );
      // No green entry.
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, isNot(contains('## Cycle: B-001 (green)')));
      expect(
        await File(fx.subjectPathOf('B-SIB')).readAsString(),
        contains('=> 2'),
      );
    });

    test('A9: pre-existing suite failures tolerated; only NEW failures fail '
        'the guard', () async {
      // Seed a pre-existing broken sibling — the baseline must
      // record it as failing, and the post-run guard sees the
      // same failure → tolerated.
      await fx.seedCertifiedRed(id: 'B-001', description: _targetDescription);
      // Pre-existing BROKEN sibling (will fail in both baseline
      // and guard — tolerated per US3.AC3).
      final brokenSibling = '''
import 'package:test/test.dart';

void main() {
  test('pre-existing broken sibling', () {
    expect(1, equals(2));
  });
}
''';
      await fx.registerBehavior(
        id: 'B-SIB',
        description: 'pre-existing broken sibling',
        testContent: brokenSibling,
      );

      // Pipeline turns B-001 green and leaves B-SIB alone.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': [
            'cat > "${fx.testPathOf('B-001')}" <<\'ZFA_EOF\'',
            _greenTest,
            'ZFA_EOF',
          ],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
      );
      expect(exitCode, 0, reason: 'pre-existing failure tolerated; out: $out');
      expect(out, contains('outcome=green'));
      final log = await File(fx.cycleLogPath).readAsString();
      // Suite line records the pre-existing failure.
      expect(log, contains('- suite: baseline='));
      expect(log, contains('guard='));
    });
  });

  group('US4 — misfire-stop on unexpressible behaviors', () {
    test('A10/U7: pipeline-inexpressible behavior → exit non-zero naming '
        'the unmet capability, no evidence', () async {
      // Seed a behavior whose description cannot be mapped to
      // any pipeline capability.
      await fx.seedCertifiedRed(
        id: 'B-042',
        description: 'parse bespoke DSL syntax with no generator surface',
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-042', zfaBin: zfaBin),
      );
      expect(exitCode, isNot(0));
      expect(out, contains('unexpressible'));
      expect(
        out,
        contains(
          'make: behavior=B-042 outcome=unexpressible '
          'feature=${fx.featureName}',
        ),
      );
      // Pipeline NEVER invoked — misfire before any generation.
      final log = await fx.readFakeZfaLog();
      expect(log, isEmpty);
      // No green evidence written.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: B-042 (green)')));
    });

    test('A11/U10: failing generation step → exit non-zero naming the step, '
        'no test-suite run against broken code', () async {
      await fx.seedCertifiedRed(id: 'B-001', description: _targetDescription);
      // Fake zfa exits 1 on `entity create` (generation-error).
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        exitByArgv: {'entity create': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
      );
      expect(exitCode, isNot(0));
      expect(out, contains('generation-error'));
      expect(out, contains('entity create'));
      expect(
        out,
        contains(
          'make: behavior=B-001 outcome=generation-error '
          'feature=${fx.featureName}',
        ),
      );
      // No green evidence.
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: B-001 (green)')));
    });

    test('A12/U27: any misfire leaves the behavior\'s test file and the '
        'cycle log unchanged', () async {
      await fx.seedCertifiedRed(
        id: 'B-042',
        description: 'parse bespoke DSL syntax with no generator surface',
      );
      final beforeChecksums = fx.checksumTestAndLib();
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(makeArgs(fx, id: 'B-042', zfaBin: zfaBin));
      expect(exitCode, isNot(0));
      // Test files and lib/ byte-identical (no pipeline ran).
      expect(fx.checksumTestAndLib(), equals(beforeChecksums));
    });
  });

  group('US5 — summary-line contract (FR-010, SC-006)', () {
    final shape = RegExp(r'^make: behavior=(\S+) outcome=(\S+) feature=(\S+)$');

    test('U29/A13: every invocation ends with the summary line in the '
        'pinned format', () async {
      await fx.seedCertifiedRed(id: 'B-001', description: _targetDescription);
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': [
            'cat > "${fx.testPathOf('B-001')}" <<\'ZFA_EOF\'',
            _greenTest,
            'ZFA_EOF',
          ],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final green = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
      );
      final greenLine = green.trim().split('\n').last;
      final m1 = shape.firstMatch(greenLine);
      expect(m1, isNotNull, reason: 'line: "$greenLine"');
      expect(m1!.group(2), 'green');

      // Rejected run: unknown id (no subprocess cost).
      final rejected = await runner.runCapturing(
        makeArgs(fx, id: 'B-999', zfaBin: zfaBin),
      );
      final rejectedLine = rejected.trim().split('\n').last;
      final m2 = shape.firstMatch(rejectedLine);
      expect(m2, isNotNull, reason: 'line: "$rejectedLine"');
      expect(m2!.group(2), 'runner-error');

      final invalidFeature = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin, feature: '../invalid'),
      );
      final invalidFeatureLine = invalidFeature.trim().split('\n').last;
      final m3 = shape.firstMatch(invalidFeatureLine);
      expect(m3, isNotNull, reason: 'line: "$invalidFeatureLine"');
      expect(m3!.group(1), 'B-001');
      expect(m3.group(2), 'runner-error');
      expect(m3.group(3), 'unknown');
    });

    test('A14: exit code 0 occurs EXACTLY on green; every rejection/misfire '
        'is non-zero', () async {
      await fx.seedCertifiedRed(id: 'B-001', description: _targetDescription);
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'entity create': [
            'cat > "${fx.testPathOf('B-001')}" <<\'ZFA_EOF\'',
            _greenTest,
            'ZFA_EOF',
          ],
        },
      );

      final runner = CliRunner(exitOnCompletion: false);

      // Green → exit 0.
      await runner.runCapturing(makeArgs(fx, id: 'B-001', zfaBin: zfaBin));
      expect(exitCode, 0);
      exitCode = 0;

      // Each rejection → non-zero.
      // 1. unknown id
      await runner.runCapturing(makeArgs(fx, id: 'B-999', zfaBin: zfaBin));
      expect(exitCode, isNot(0));
      exitCode = 0;

      // 2. unexpressible
      await fx.seedCertifiedRed(
        id: 'B-042',
        description: 'parse bespoke DSL with no generator',
      );
      await runner.runCapturing(makeArgs(fx, id: 'B-042', zfaBin: zfaBin));
      expect(exitCode, isNot(0));
      exitCode = 0;
    });
  });

  group('U30 — misfire-stop policy (FR-011)', () {
    test('a missing/unreadable tdd-profile stops with runner-error before '
        'any step', () async {
      await fx.seedCertifiedRed(id: 'B-001', description: _targetDescription);
      // Delete the profile.
      final profile = File('${fx.root.path}/.specify/memory/tdd-profile.md');
      profile.deleteSync();
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-001', zfaBin: zfaBin),
      );
      expect(exitCode, isNot(0));
      expect(out, contains('runner-error'));
      // Pipeline NEVER invoked.
      final log = await fx.readFakeZfaLog();
      expect(log, isEmpty);
    });
  });
}
