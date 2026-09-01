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

import 'package:path/path.dart' as p;
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
      'U25/A6 (issue #694): already-green target test → skip transition: '
      'exit 0, outcome=skipped, green evidence appended, no generation',
      () async {
        // Seed the certified-red precondition, but with a GREEN test
        // (the behavior is already satisfied from a prior run — the
        // issue #694 re-run scenario).
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
        // The skip transition succeeds: the run loop must proceed past
        // already-green behaviors instead of stopping on drift.
        expect(exitCode, 0, reason: out);
        expect(out, contains('skipped'));
        expect(
          out,
          contains(
            'make: behavior=B-001 outcome=skipped feature=${fx.featureName}',
          ),
        );
        // Generation NEVER invoked — the skip transition happens before
        // planning.
        final log = await fx.readFakeZfaLog();
        expect(log, isEmpty);
        // The skip is certified, not silently ignored: a green evidence
        // entry exists with an explicit `(none)` generation block and a
        // real suite guard line.
        final cycleLog = await File(fx.cycleLogPath).readAsString();
        expect(cycleLog, contains('## Cycle: B-001 (green)'));
        expect(cycleLog, contains('- generation:'));
        expect(cycleLog, contains('  (none)'));
        expect(cycleLog, contains('- suite: baseline='));
      },
    );

    test('bug 696: a unit behavior whose description names no entity plans '
        '`zfa make <slug> --no-entity` and goes green — no "no entity '
        'source file was found" failure', () async {
      // Issue #696 repro shape: the behavior id is NOT an entity name
      // and the description carries no entity either. The planner's
      // CRUD branch must not hand the bare slugified id to
      // `zfa make` without --no-entity (the real CLI fail-fasts with
      // "no entity source file was found", #496).
      const description = 'service exposes the count of pending items';
      await fx.seedCertifiedRed(
        id: 'U-6',
        description: description,
        testContent: TddFixture.subjectDrivenTest('U-6', description),
      );
      // The fake pipeline's `make u_6 --no-entity` invocation
      // implements the subject, turning the target test green.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'make u_6': fx.overwriteSubjectCommands(
            'U-6',
            TddFixture.subjectReturning('U-6', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U-6', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: out);
      expect(out, contains('outcome=green'), reason: out);
      // The make invocation carried --no-entity: the slugified
      // behavior id never reached the real CLI as a bare entity name.
      final log = await fx.readFakeZfaLog();
      final makeCalls = log.where((l) => l.startsWith('make ')).toList();
      expect(makeCalls, isNotEmpty, reason: log.join('\n'));
      expect(
        makeCalls.first,
        contains('--no-entity'),
        reason:
            'the plan must pass --no-entity when no entity name is '
            'derivable from the behavior (issue #696): ${makeCalls.first}',
      );
    });

    test(
      'bug 696: a unit behavior whose description names the entity plans '
      '`zfa make <Entity>` with the derived name, not the behavior id',
      () async {
        const description = 'create User use case returns the saved entity';
        await fx.seedCertifiedRed(
          id: 'U-5',
          description: description,
          testContent: TddFixture.subjectDrivenTest('U-5', description),
        );
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: fx.fakeZfaLogPath,
          sideEffectByArgv: {
            'make User': fx.overwriteSubjectCommands(
              'U-5',
              TddFixture.subjectReturning('U-5', 42),
            ),
          },
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'U-5', zfaBin: zfaBin),
        );

        expect(exitCode, 0, reason: out);
        final log = await fx.readFakeZfaLog();
        final makeCalls = log.where((l) => l.startsWith('make ')).toList();
        expect(makeCalls, isNotEmpty, reason: log.join('\n'));
        expect(
          makeCalls.first,
          contains('make User'),
          reason:
              'the entity name must be derived from the behavior '
              'description, not the behavior id (issue #696): '
              '${makeCalls.first}',
        );
        expect(makeCalls.first, isNot(contains('--no-entity')));
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
      // any pipeline capability. Bug #657: verb phrases like "parse"
      // now map to the `tdd func` surface, so the genuinely unmappable
      // case here uses a verb with no function-generation intent.
      await fx.seedCertifiedRed(
        id: 'B-042',
        description: 'provision bespoke DSL syntax with no generator surface',
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
        description: 'provision bespoke DSL syntax with no generator surface',
      );
      final beforeChecksums = fx.checksumTestAndLib();
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(makeArgs(fx, id: 'B-042', zfaBin: zfaBin));
      expect(exitCode, isNot(0));
      // Test files and lib/ byte-identical (no pipeline ran).
      expect(fx.checksumTestAndLib(), equals(beforeChecksums));
    });

    test('bug 657: an unexpressible make names the verb and the stub path '
        'with the manual-implementation hint ("implement manually at '
        '<stub_path>, then re-run")', () async {
      await fx.seedCertifiedRed(
        id: 'B-042',
        description: 'provision bespoke DSL syntax with no generator surface',
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-042', zfaBin: zfaBin),
      );
      expect(exitCode, isNot(0), reason: out);
      // The actionable remediation line from bug #657: which verb has no
      // generator, where the manual implementation lands, and that the
      // run resumes afterwards.
      expect(out, contains("no generator for 'provision'"));
      expect(out, contains('implement manually at'));
      expect(out, contains(fx.subjectPathOf('B-042')));
      expect(out, contains('then re-run'));
      // The outcome/exit contract is unchanged (honest non-zero misfire).
      expect(
        out,
        contains(
          'make: behavior=B-042 outcome=unexpressible '
          'feature=${fx.featureName}',
        ),
      );
    });

    test('bug 657: a render-type behavior plans the `tdd func` step '
        'through the pipeline (no longer unexpressible)', () async {
      const desc =
          'render returns a non-empty string for a fully populated '
          'task';
      await fx.seedCertifiedRed(
        id: 'B-043',
        description: desc,
        // Subject-driven: turns green when the fake pipeline writes the
        // production subject — the same mechanics as US1's entity create.
        testContent: TddFixture.subjectDrivenTest('B-043', desc),
      );
      // The fake `tdd func` step writes the production subject — proving
      // the plan reaches the new surface and certifies green.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'B-043',
            TddFixture.subjectReturning('B-043', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'B-043', zfaBin: zfaBin),
      );
      expect(exitCode, 0, reason: out);
      // The plan carried the new generator surface.
      final log = await fx.readFakeZfaLog();
      expect(
        log.any((l) => l.contains('tdd func B-043')),
        isTrue,
        reason: 'fake zfa argv log: $log',
      );
      expect(out, contains('make: behavior=B-043 outcome=green'));
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
        description: 'provision bespoke DSL with no generator',
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

  // -------------------------------------------------------------------
  // Spec 052 — the composition fallback (the phase-2 acceptance flip).
  // When the planner refuses an ACCEPTANCE-kind behavior and the feature
  // holds green unit subjects, make falls back to compose → build.
  // -------------------------------------------------------------------
  group('spec 052 — composition fallback on planner refusal', () {
    Future<void> seedAcceptanceWithGreenUnit(TddFixture fx) async {
      await fx.seedTestList([
        (
          id: 'A-100',
          description: 'the signup flow completes and the account is usable',
          traces: 'FR-052',
          state: 'PENDING',
          kind: 'acceptance',
        ),
        (
          id: 'U-100',
          description: 'unit behavior backing A-100',
          traces: 'FR-052',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'A-100',
        description: 'the signup flow completes and the account is usable',
        // The target test must depend on the production subject so the
        // fallback's compose step (via the fake's side effect) can turn
        // it green — the same discipline as the entity-plan tests.
        testContent: TddFixture.subjectDrivenTest(
          'A-100',
          'the signup flow completes and the account is usable',
        ),
      );
      await fx.registerBehavior(id: 'U-100', description: 'unit one');
      await fx.seedGreenEvidence('U-100');
      await Directory(p.join(fx.root.path, 'lib')).create(recursive: true);
      await File(
        fx.subjectPathOf('U-100'),
      ).writeAsString('int subject_u_100() => 0;\n');
    }

    test('A13/U19: acceptance make falls back to compose → build, both '
        'steps captured in the green entry, exit 0', () async {
      await seedAcceptanceWithGreenUnit(fx);
      // The fake compose step turns the target test green by writing the
      // production subject (the fallback pipeline's real effect).
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd compose': fx.overwriteSubjectCommands(
            'A-100',
            TddFixture.subjectReturning('A-100', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A-100', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: out);
      expect(
        out,
        contains(
          'make: behavior=A-100 outcome=green feature=${fx.featureName}',
        ),
      );
      // The fallback plan executed compose then build, in order.
      final log = await fx.readFakeZfaLog();
      expect(log, hasLength(2), reason: log.join('\n'));
      expect(log[0], contains('tdd compose A-100'));
      expect(log[0], contains('--feature'));
      expect(log[1], 'build');
      // Both invocations are recorded in the green evidence (FR-010).
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: A-100 (green)'));
      expect(cycleLog, contains('tdd compose A-100'));
    });

    test('A10: acceptance make with zero composable anchors honest-stops '
        'unexpressible (FR-009, SC-003)', () async {
      await fx.seedTestList([
        (
          id: 'A-101',
          description: 'pure prose acceptance behavior',
          traces: 'FR-052',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'A-101',
        description: 'pure prose acceptance behavior',
      );
      // No unit behaviors, no green evidence: nothing to compose against.
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A-101', zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains(
          'make: behavior=A-101 outcome=unexpressible '
          'feature=${fx.featureName}',
        ),
      );
      // Pipeline NEVER invoked — the fallback disengaged before spawning.
      final log = await fx.readFakeZfaLog();
      expect(log, isEmpty);
      expect(
        await File(fx.cycleLogPath).readAsString(),
        isNot(contains('## Cycle: A-101 (green)')),
      );
    });

    test(
      'A11/U17: a unit-kind unexpressible make never composes (SC-004)',
      () async {
        // A feature with a green unit sibling AND a unit-kind unexpressible
        // behavior: the fallback must not engage for the unit.
        await seedAcceptanceWithGreenUnit(fx);
        await fx.seedTestList([
          (
            id: 'A-100',
            description: 'the signup flow completes and the account is usable',
            traces: 'FR-052',
            state: 'PENDING',
            kind: 'acceptance',
          ),
          (
            id: 'U-100',
            description: 'unit behavior backing A-100',
            traces: 'FR-052',
            state: 'PENDING',
            kind: 'unit',
          ),
          (
            id: 'B-200',
            description: 'parse bespoke DSL syntax with no generator surface',
            traces: 'FR-052',
            state: 'PENDING',
            kind: 'unit',
          ),
        ]);
        await fx.seedCertifiedRed(
          id: 'B-200',
          description: 'parse bespoke DSL syntax with no generator surface',
        );
        final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'B-200', zfaBin: zfaBin),
        );

        expect(exitCode, isNot(0), reason: out);
        expect(out, contains('outcome=unexpressible'));
        // No fallback attempt: compose never spawned.
        final log = await fx.readFakeZfaLog();
        expect(log, isEmpty);
      },
    );

    test('U18: a malformed test list fails the fallback closed '
        '(unexpressible, no spawn)', () async {
      await fx.seedCertifiedRed(
        id: 'A-102',
        description: 'pure prose acceptance behavior',
      );
      await File(fx.testListPath).writeAsString(
        '# Test List: broken\n\n| A-102 | missing columns | FR-052 |\n',
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A-102', zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('outcome=unexpressible'));
      expect(out, contains('test-list.md'));
      final log = await fx.readFakeZfaLog();
      expect(log, isEmpty);
    });

    test('A14/U20: a failed compose step → generation-error, no green '
        'entry, failed step named', () async {
      await seedAcceptanceWithGreenUnit(fx);
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        exitByArgv: {'tdd compose': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A-100', zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('generation-error'));
      expect(out, contains('compose'));
      expect(
        await File(fx.cycleLogPath).readAsString(),
        isNot(contains('## Cycle: A-100 (green)')),
      );
    });

    test('A15: a failed build after a successful compose → '
        'generation-error, no green entry', () async {
      await seedAcceptanceWithGreenUnit(fx);
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd compose': fx.overwriteSubjectCommands(
            'A-100',
            TddFixture.subjectReturning('A-100', 42),
          ),
        },
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A-100', zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0), reason: out);
      expect(out, contains('generation-error'));
      expect(
        await File(fx.cycleLogPath).readAsString(),
        isNot(contains('## Cycle: A-100 (green)')),
      );
    });
  });
}
