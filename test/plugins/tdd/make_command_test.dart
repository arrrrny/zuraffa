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

  group('bug 718 — unit behaviors route to the plain-function generator', () {
    test('a unit behavior (U5) with CRUD-keyword prose goes green through '
        '`tdd func` — the make step never dispatches `zfa make u5` '
        '(issue #718 repro)', () async {
      // Issue #718 repro shape: the run loop stops at U5:make with
      // outcome=generation-error because the make step dispatches
      // `zfa make u5` (the slugified behavior id as an entity name).
      // A unit behavior's artifacts are a plain no-arg subject function
      // and its test (spec 044), so the only generator that can flip it
      // green is `tdd func` (the #657/#660 plain-function surface).
      const description = 'service exposes the count of pending items';
      await fx.seedCertifiedRed(
        id: 'U5',
        description: description,
        testContent: TddFixture.subjectDrivenTest('U5', description),
      );
      // The fake pipeline turns the test green ONLY through the func
      // step — a `make u5` dispatch leaves the stub returning 0 and the
      // target test red (the pre-fix generation-error).
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U5',
            TddFixture.subjectReturning('U5', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U5', zfaBin: zfaBin),
      );

      // Pre-fix this was exit 1 with outcome=generation-error ("target
      // test still fails after generation").
      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U5 outcome=green feature=${fx.featureName}'),
        reason: 'out:\n$out',
      );
      // Dispatch evidence: the func step ran, and no `make <slug>`
      // invocation ever happened.
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('tdd func')),
        isNotEmpty,
        reason:
            'the unit behavior must route to the plain-function '
            'generator: ${log.join('\n')}',
      );
      expect(
        log.where((l) => l.startsWith('make ')),
        isEmpty,
        reason:
            'the behavior id must never reach `zfa make` as an '
            'entity name (issue #718): ${log.join('\n')}',
      );
    });
  });

  group('bug 737 — the make plan\'s terminal build step is guarded '
      'per-behavior', () {
    test('a unit behavior reports green-with-failed-build (not '
        'generation-error) when the plan\'s terminal build step fails against '
        'a pre-existing red suite while the behavior\'s own test passes after '
        'the func scaffold', () async {
      // Issue #737 state: U3 fresh stub (certified red), a sibling U4
      // also still red (pending stub). The make plan for U3 is
      // [tdd func U3, build]; the func scaffold flips U3's test green,
      // but the terminal `build` step exits non-zero — the project's
      // build/suite state, not this behavior's generation. Pre-fix, the
      // pipeline treats the non-zero build exit as a plan failure and
      // the make reports outcome=generation-error, stopping
      // `zfa tdd run` on a healthy behavior (the false negative).
      // Issue #942 amends the accounting: a tolerated build failure is
      // NO LONGER conflated with the #694 skip transition — the summary
      // records the honest `green-with-failed-build` label so the loop's
      // green accounting distinguishes real green from failed-build
      // green (the failure output here carries no analyzer errors, so
      // the #942 gate does not refuse the tolerance).
      const description = 'returns 42 when invoked with no args';
      await fx.seedCertifiedRed(
        id: 'U3',
        description: description,
        testContent: TddFixture.subjectDrivenTest('U3', description),
      );
      // The pre-existing red sibling: still red at baseline AND at guard
      // time (its own pending stub) — never this make's responsibility.
      await fx.seedCertifiedRed(
        id: 'U4',
        description: 'returns 43 when invoked with no args',
        testContent: TddFixture.subjectDrivenTest(
          'U4',
          'returns 43 when invoked with no args',
        ),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        // The func step scaffolds the subject — U3's own test passes
        // afterwards.
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U3',
            TddFixture.subjectReturning('U3', 42),
          ),
        },
        // The terminal build step fails (exit 1) the way a real
        // project's build/suite guard fails on pre-existing red state.
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      // Pre-fix: exit 1 with outcome=generation-error.
      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains(
          'make: behavior=U3 outcome=green-with-failed-build '
          'feature=${fx.featureName}',
        ),
        reason:
            '#942: a tolerated build failure must be distinguished from '
            'the #694 skip transition in the summary (out:\n$out)',
      );
      // The plan executed end to end: the func step ran (scaffolded) and
      // the build step ran (and failed — the failure is what the
      // per-behavior guard tolerates).
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('tdd func')),
        isNotEmpty,
        reason: 'the func scaffold must have run: ${log.join('\n')}',
      );
      expect(
        log.where((l) => l.contains('build')),
        isNotEmpty,
        reason: 'the build step must have run: ${log.join('\n')}',
      );
      // Green evidence appended for U3 (the tolerated-failure shape:
      // exit 0, run loop proceeds — the label is what stays honest).
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U3 (green)'));
    });

    test('a failed terminal build whose output reports analyzer errors is '
        'NOT tolerated: the make stops with generation-error and appends no '
        'green entry (issue #942 — green accounting stays honest)', () async {
      // Issue #942 state: the generated tree does not compile (an entity
      // named Credentials collides with the framework barrel — 20
      // ambiguous_import errors). The behavior's own test can still pass
      // because nothing exercises the broken files, and the #737
      // tolerance then green-washed the make: outcome=skipped, exit 0,
      // green evidence appended. A non-compiling generated tree is not
      // tolerable noise: when the failed build's output carries analyzer
      // error lines, the tolerance must refuse and the make must keep the
      // honest generation-error stop (safe-failure, never a silent pass).
      const description = 'returns 42 when invoked with no args';
      await fx.seedCertifiedRed(
        id: 'U3',
        description: description,
        testContent: TddFixture.subjectDrivenTest('U3', description),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U3',
            TddFixture.subjectReturning('U3', 42),
          ),
        },
        stdoutByArgv: {
          'build': [
            '   error - lib/src/data/datasources/credentials/credentials_mock_datasource.dart:21:10 - The name Credentials is defined in two libraries. - ambiguous_import',
            '   error - lib/src/data/datasources/credentials/credentials_datasource.dart:5:8 - The name Credentials is defined in two libraries. - ambiguous_import',
          ],
        },
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      // Pre-#942: exit 0 with outcome=skipped and a green entry — the
      // green-wash this test forbids.
      expect(exitCode, isNot(0), reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U3 outcome=generation-error'),
        reason: 'out:\n$out',
      );
      expect(
        out,
        contains('analyzer error(s)'),
        reason:
            'the report must name WHY the tolerance refused '
            '(out:\n$out)',
      );
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: U3 (green)')));
    });

    test('the tolerance never masks a genuinely failed generation: a red '
        'target test after the failed build still stops with '
        'generation-error', () async {
      // Same failed terminal build step — but the func step leaves the
      // stub unimplemented, so the behavior's own test is still red. The
      // per-behavior guard must refuse to tolerate and keep the honest
      // generation-error (safe-failure, never a silent pass).
      const description = 'returns 42 when invoked with no args';
      await fx.seedCertifiedRed(
        id: 'U3',
        description: description,
        testContent: TddFixture.subjectDrivenTest('U3', description),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        exitByArgv: {'build': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0), reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U3 outcome=generation-error'),
        reason: 'out:\n$out',
      );
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: U3 (green)')));
    });

    test('only the terminal build step qualifies: a failed scaffold step '
        'keeps the honest generation-error', () async {
      // The func step itself fails — real generation work never ran, so
      // the per-behavior build tolerance must not engage (the fix is
      // scoped to the make plan's build/guard logic, issue #737).
      const description = 'returns 42 when invoked with no args';
      await fx.seedCertifiedRed(
        id: 'U3',
        description: description,
        testContent: TddFixture.subjectDrivenTest('U3', description),
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        exitByArgv: {'tdd func': 3},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U3', zfaBin: zfaBin),
      );

      expect(exitCode, isNot(0), reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U3 outcome=generation-error'),
        reason: 'out:\n$out',
      );
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, isNot(contains('## Cycle: U3 (green)')));
    });
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
    test('bug 731: pre-existing red behaviors with unstable failing-test '
        'ids never flip an already-green target to regression — the '
        'skip transition reports skipped', () async {
      // A deferred acceptance sibling: red in EVERY suite run (honest
      // pre-existing breakage, like A1-A5 deferred to phase 2), but its
      // failing-test IDENTIFIER varies between the baseline and guard
      // runs (a dynamic test name) — the exact #731 false-positive
      // shape: the guard's name-diff sees a "new" failure that is
      // really the same pre-existing red behavior.
      final deferredSibling = '''
import 'package:test/test.dart';

void main() {
  test('deferred acceptance \${DateTime.now().microsecondsSinceEpoch}', () {
    fail('deferred to phase 2');
  });
}
''';
      await fx.registerBehavior(
        id: 'A-DEF',
        description: 'deferred acceptance behavior',
        testContent: deferredSibling,
      );
      // The target's test ALREADY passes (a prior run made it green)
      // while its certified-red evidence is still present: the issue
      // #694 skip transition. No pipeline runs (skip never generates).
      await fx.seedCertifiedRed(
        id: 'B-001',
        description: _targetDescription,
        testContent: _greenTest,
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(makeArgs(fx, id: 'B-001'));
      expect(
        exitCode,
        0,
        reason:
            'pre-existing red behaviors must not block an '
            'already-green target (issue #731); out: $out',
      );
      expect(out, contains('outcome=skipped'));
      expect(out, isNot(contains('outcome=regression')));
      // Green evidence with an explicitly empty generation block is
      // appended (the skip transition's contract, issue #694).
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('## Cycle: B-001 (green)'));
    });

    test('bug 731: a regression in a file that was ALREADY red at baseline '
        'is tolerated on the generation path too — make goes green when '
        'only pre-existing red behaviors fail', () async {
      // Same unstable pre-existing red sibling; this time the target is
      // genuinely red and the fake pipeline turns it green. The
      // deferred sibling fails both suite runs with different ids —
      // the guard must not call that a regression.
      final deferredSibling = '''
import 'package:test/test.dart';

void main() {
  test('deferred acceptance \${DateTime.now().microsecondsSinceEpoch}', () {
    fail('deferred to phase 2');
  });
}
''';
      await fx.registerBehavior(
        id: 'A-DEF',
        description: 'deferred acceptance behavior',
        testContent: deferredSibling,
      );
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
      expect(
        exitCode,
        0,
        reason:
            'failures confined to already-red files are pre-existing '
            'red behaviors (issue #731); out: $out',
      );
      expect(out, contains('outcome=green'));
      expect(out, isNot(contains('outcome=regression')));
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

    test('A15 (amended by issue #737): a failed terminal build after a '
        'successful compose takes the per-behavior skip transition when the '
        'behavior\'s own test passes — outcome=skipped, green entry', () async {
      // Issue #737 amended the terminal-build contract for EVERY make
      // plan shape (the composition plan included — the composition
      // path hits the same pre-existing-red suite in phase 2): a
      // non-zero terminal `build` step is only fatal when the
      // behavior's own test fails. The compose step succeeded and the
      // acceptance subject's test passes, so the build failure —
      // unattributable to this make — is tolerated and the make takes
      // the #694 skip transition instead of the #737 false-negative
      // `generation-error` stop.
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

      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains(
          'make: behavior=A-100 outcome=skipped feature=${fx.featureName}',
        ),
        reason: 'out:\n$out',
      );
      expect(out, contains('issue #737'));
      expect(
        await File(fx.cycleLogPath).readAsString(),
        contains('## Cycle: A-100 (green)'),
      );
    });
  });

  // -------------------------------------------------------------------
  // Bug #726 — tdd-suite-template-truncation. With an ecosystem-style
  // profile whose `suite:` value is UNQUOTED and multi-word
  // (`suite: dart test`), the old unquoted-value regex truncated the
  // template to its first word (`dart`), so the suite baseline ran the
  // bare `dart` CLI (help text, exit 0, unparseable) and make refused
  // with "the suite baseline did not produce a usable snapshot" even
  // though the package is a perfectly normal pure-Dart project.
  // -------------------------------------------------------------------
  group('bug #726 — make with an unquoted multi-word suite template', () {
    test('U15: the suite baseline runs the REAL suite and make completes '
        'green on a certified-red behavior', () async {
      final fx2 = await TddFixture.create(writeProfile: false);
      try {
        // Ecosystem-detector-style profile: frontmatter shape, quoted
        // single (isolate the suite bug), unquoted multi-word suite.
        final dir = Directory('${fx2.root.path}/.specify/memory');
        await dir.create(recursive: true);
        await File('${dir.path}/tdd-profile.md').writeAsString('''
---
detected_at: 2026-01-15
project: tdd_fixture
stacks:
  dart:
    runner: dart
    single: 'dart test {file} --plain-name "{name}"'
    file: 'dart test {file}'
    suite: dart test
---
# TDD Profile
''');
        await fx2.seedCertifiedRed(
          id: 'B-001',
          description: _targetDescription,
          testContent: TddFixture.subjectDrivenTest(
            'B-001',
            _targetDescription,
          ),
        );
        final zfaBin = await fx2.writeFakeZfaBin(
          logPath: fx2.fakeZfaLogPath,
          sideEffectByArgv: {
            'entity create': fx2.overwriteSubjectCommands(
              'B-001',
              TddFixture.subjectReturning('B-001', 42),
            ),
          },
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx2, id: 'B-001', zfaBin: zfaBin),
        );

        expect(exitCode, 0, reason: out);
        expect(out, contains('suite baseline: dart test'));
        expect(out, contains('outcome=green'));
        final log = await File(fx2.cycleLogPath).readAsString();
        expect(log, contains('- suite: baseline='));
        expect(log, contains('new=(none)'));
      } finally {
        fx2.dispose();
        exitCode = 0;
      }
    });
  });

  group('bug 829 — unit behaviors traced to a spec Key Entity route to '
      'the entity pipeline', () {
    Future<void> seedEntityTracedFeature() async {
      await fx.seedCertifiedRed(
        id: 'U1',
        description:
            'The system shall persist a User with a name and an '
            'email.',
        sourceCriterion: 'FR-001',
        testContent: TddFixture.subjectDrivenTest(
          'U1',
          'The system shall persist a User with a name and an email.',
        ),
      );
      // The test list (as `zfa tdd plan` writes it post-829): the unit
      // row plus the extracted Key entities section.
      await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
      await File(p.join(fx.featureDir, 'tdd', 'test-list.md')).writeAsString('''
# Test List: ${fx.featureName}

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system shall persist a User with a name and an email. | FR-001 | PENDING |

## Key entities

| entity | fields |
| ------ | ------ |
| User | name: String, email: String |
''');
    }

    test('U-829g: the plan is entity create -> make <Entity> -> wire -> '
        'build, and the wire step flips the subject green', () async {
      await seedEntityTracedFeature();
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd wire': fx.overwriteSubjectCommands(
            'U1',
            TddFixture.subjectReturning('U1', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U1', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      expect(
        out,
        contains('make: behavior=U1 outcome=green feature=${fx.featureName}'),
        reason: 'out:\n$out',
      );
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('entity create -n User')),
        isNotEmpty,
        reason: 'the entity must be created when absent: ${log.join('\n')}',
      );
      expect(
        log.where((l) => l.startsWith('make User')),
        isNotEmpty,
        reason:
            'the entity pipeline must generate the domain layer '
            '(usecases/repos/di): ${log.join('\n')}',
      );
      expect(
        log.where((l) => l.contains('tdd wire U1 --entity User')),
        isNotEmpty,
        reason: 'the subject must be wired to the entity: ${log.join('\n')}',
      );
    });

    test(
      'U-829h: an existing entity is REUSED — the plan drops the '
      'entity create step (never regenerates over hand-tuned fields)',
      () async {
        await seedEntityTracedFeature();
        final entityFile = File(
          p.join(
            fx.root.path,
            'lib',
            'src',
            'domain',
            'entities',
            'user',
            'user.dart',
          ),
        );
        await entityFile.parent.create(recursive: true);
        await entityFile.writeAsString('// hand-tuned entity\n');
        final zfaBin = await fx.writeFakeZfaBin(
          logPath: fx.fakeZfaLogPath,
          sideEffectByArgv: {
            'tdd wire': fx.overwriteSubjectCommands(
              'U1',
              TddFixture.subjectReturning('U1', 42),
            ),
          },
        );

        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(
          makeArgs(fx, id: 'U1', zfaBin: zfaBin),
        );

        expect(exitCode, 0, reason: 'out:\n$out');
        expect(out, contains('already exists — reuse'));
        final log = await fx.readFakeZfaLog();
        expect(
          log.where((l) => l.contains('entity create')),
          isEmpty,
          reason:
              'an existing entity must never be regenerated: '
              '${log.join('\n')}',
        );
        expect(
          log.where((l) => l.startsWith('make User')),
          isNotEmpty,
          reason:
              'the rest of the entity pipeline still runs: '
              '${log.join('\n')}',
        );
        expect(
          await entityFile.readAsString(),
          '// hand-tuned entity\n',
          reason: 'the hand-tuned entity file must be untouched',
        );
      },
    );

    test('U-829i: a unit behavior whose FR traces to NO declared entity '
        'keeps the func surface (no phase-0-style entity spawn)', () async {
      await fx.seedCertifiedRed(
        id: 'U2',
        description: 'render returns a non-empty string',
        sourceCriterion: 'FR-002',
        testContent: TddFixture.subjectDrivenTest(
          'U2',
          'render returns a non-empty string',
        ),
      );
      await Directory(p.join(fx.featureDir, 'tdd')).create(recursive: true);
      await File(p.join(fx.featureDir, 'tdd', 'test-list.md')).writeAsString('''
# Test List: ${fx.featureName}

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U2 | render returns a non-empty string | FR-002 | PENDING |

## Key entities

| entity | fields |
| ------ | ------ |
| User | name: String |
''');
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            'U2',
            TddFixture.subjectReturning('U2', 42),
          ),
        },
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'U2', zfaBin: zfaBin),
      );

      expect(exitCode, 0, reason: 'out:\n$out');
      final log = await fx.readFakeZfaLog();
      expect(log.where((l) => l.contains('tdd func')), isNotEmpty);
      expect(log.where((l) => l.contains('entity create')), isEmpty);
      expect(log.where((l) => l.startsWith('make ')), isEmpty);
    });
  });

  group('bug 873 — the behavior id never reaches `zfa make` from the '
      'acceptance path', () {
    test('the issue #873 repro (A3, real gen composite) honest-stops '
        'unexpressible — no `zfa make A3` / `entity create -n A3` '
        'dispatch', () async {
      // Issue #873 repro shape: spec 004-dependency-injection, A3
      // "all use cases are registered as factories". The REAL gen
      // composite embeds the generated TEST NAME as the registry's
      // description segment — `<id> — <description>`
      // (behavior_test_writer.dart) — so the planner saw the leading
      // behavior id as a capitalized "named entity", skipped the #758
      // unexpressible guard, and dispatched the issue's 4-step plan
      // whose index-1 step `zfa make A3` fail-fasts with "no entity
      // source file was found". seedCertifiedRed writes the
      // description into that segment verbatim, so passing the
      // prefixed text reproduces the real registry record byte for
      // byte.
      const description = 'A3 \u2014 all use cases are registered as factories';
      await fx.seedTestList([
        (
          id: 'A3',
          description: 'all use cases are registered as factories',
          traces: 'AC-3',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'A3',
        description: description,
        testContent: TddFixture.subjectDrivenTest('A3', description),
      );
      // The real `zfa make A3` fail-fast (#496): exit 1 "no entity
      // source file was found" — the issue's index-1 step failure.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        exitByArgv: {'make A3': 1},
      );

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        makeArgs(fx, id: 'A3', zfaBin: zfaBin),
      );

      // Post-fix: the planner refuses the prose (the leading "A3" is a
      // test-name prefix, not an entity named in the description), the
      // composition fallback finds zero green unit anchors in this
      // feature, and the make honest-stops unexpressible — the SAME
      // deferral A1 ("all data sources ...") and A2 ("all repositories
      // ...") already got in the issue's run log.
      expect(exitCode, isNot(0), reason: out);
      expect(
        out,
        contains(
          'make: behavior=A3 outcome=unexpressible '
          'feature=${fx.featureName}',
        ),
        reason: out,
      );
      // The #696-family signature is unreachable: the behavior id is
      // NEVER dispatched as an entity name — no `make A3`, no
      // `entity create -n A3`.
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('make A3')),
        isEmpty,
        reason:
            'issue #873: the behavior id must never be dispatched as a '
            'make entity name. Dispatched: ${log.join(' | ')}',
      );
      expect(
        log.where((l) => l.contains('-n A3')),
        isEmpty,
        reason:
            'issue #873: the behavior id must never be created as an '
            'entity. Dispatched: ${log.join(' | ')}',
      );
      expect(
        log,
        isEmpty,
        reason:
            'the fallback disengaged before any spawn — the pipeline '
            'never ran. Dispatched: ${log.join(' | ')}',
      );
      // No green evidence — nothing was generated.
      expect(
        await File(fx.cycleLogPath).readAsString(),
        isNot(contains('## Cycle: A3 (green)')),
      );
    });
  });
}
