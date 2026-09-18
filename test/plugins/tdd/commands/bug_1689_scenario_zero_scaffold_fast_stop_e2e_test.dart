@Tags(['regression', 'e2e'])
// Issue #1689 — the scenario × zero-scaffold fast stop (E2E).
//
// `zfa tdd make` for a scenaried unit behavior (the post-#1679 COMMON
// case) paid a ~37s guaranteed-failing attempt: the plan's func pass
// scaffolded the #1517 zero-value dummy (`return 0;`), the post-
// generation target test failed against it (`equals(5)` vs 0), the
// certified-red stub was restored, and the make stopped
// `generation-error` — provably wasted work, because a zero-value
// scaffold can never satisfy a value assertion naming a different
// literal, and the recovery the stop prescribed was always going to be
// the hand step.
//
// Remediation pinned here (from the spec):
//   1. The make pre-flights the attempt: scenario value assertion ×
//      zero-scaffold prediction → stop BEFORE the pipeline
//      (outcome=would-never-pass, the hand-step remedy, exit 1).
//   2. ZERO zfa spawns on the fast stop (the fake-zfa argv log is the
//      observer — the #1587 SC pattern).
//   3. Non-scenaried behaviors (guard-only + marker) keep their
//      unchanged fast refusals; zero-matching value assertions and real
//      implementations keep the unchanged attempt paths.
//
// Test map:
//   E-1689-e1 — (AC1) the scenaried make stops `would-never-pass`
//               BEFORE the pipeline: no spawns, remedy printed, subject
//               byte-identical, no green evidence, wall time printed.
//   E-1689-e2 — (AC3) guard-only → the 3c vacuous-green refusal,
//               unchanged.
//   E-1689-e3 — (AC3) type-only + marker over a dummy → the 9b
//               vacuous-green refusal, unchanged.
//   E-1689-e4 — (AC2) zero-matching `equals(0)` → the gate stays
//               silent: `tdd func` SPAWNS (the attempt runs as before).
//   E-1689-e5 — (AC5) a real implementation + `equals(5)` → the
//               unchanged skip transition (`outcome=skipped`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

const behaviorId = 'B-1689';
const description = 'the engine adds two integers';

/// The zcalc3 fixture's spec: the declared Layer Contract row the
/// resolver binds the behavior's trace to — the shape that schedules
/// the make plan's `tdd func` step (the #1679 scenario class is
/// contract-declared by construction).
const zcalc3Spec = '''
**Template Version**: `zuraffa-1.0`

# Spec: zcalc3

### Layer Contracts

**Function**:
- `Calculator`: `add(int a, int b) -> int`

### Functional Requirements

- **FR-001**: The engine MUST add two integers via `Calculator.add` and
  return their sum.
  traces: Calculator.add
''';

String get subjectSymbol =>
    'subject_${behaviorId.toLowerCase().replaceAll('-', '_')}';

/// gen's provenance-marked scalar stub — the certified-red subject the
/// make finds on disk (the exact single-line arrow-throw shape
/// SubjectWriter renders, the shape func rewrites to the #1517 dummy).
String get genStubSubject =>
    '''
// GENERATED STUB — `zfa tdd gen $behaviorId` (spec 044-test-tdd-generation + issue #1259 contract derivation).
library;

/// Throws [UnimplementedError] until the real implementation lands.
int $subjectSymbol(int a, int b) => throw UnimplementedError('$subjectSymbol not implemented: add(int a, int b) -> int');
''';

/// The func pass's #1517 zero-value scaffold — what the REAL func pass
/// writes for an `int` declared return (the fake zfa side effect writes
/// the same bytes, so the red→green comparison isolates the gate).
String get scalarDummySubject =>
    '''
library;

int $subjectSymbol(int a, int b) {
  return 0;
}
''';

/// A real implementation — the discriminating-green class.
String get realAddSubject =>
    '''
library;

int $subjectSymbol(int a, int b) => a + b;
''';

/// The #1679 scenario-derived unit test — the capture catches the stub's
/// throw, the assertion pins the scenario's concrete outcome.
String scenarioTest(String expected) =>
    '''
import 'package:test/test.dart';

import '../lib/${behaviorId.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;

void main() {
  test('$behaviorId — $description', () {
    final result = (() {
      try {
        return subject.$subjectSymbol(2, 3);
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, equals($expected));
  });
}
''';

/// The #1259 guard-only shape (the non-scenaried class).
String guardOnlyTest() =>
    '''
import 'package:test/test.dart';

import '../lib/${behaviorId.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;

void main() {
  test('$behaviorId — $description', () {
    final result = subject.$subjectSymbol(0, 0);
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''';

/// The post-#1259 type-only + marker fallback (the #1651 class).
String typeOnlyMarkerTest() =>
    '''
import 'package:test/test.dart';

import '../lib/${behaviorId.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;

void main() {
  test('$behaviorId — $description', () {
    final result = subject.$subjectSymbol(0, 0);
    // zfa:tdd: vacuous-guard — replace with an outcome-value assertion.
    expect(result, isA<int>());
  });
}
''';

Future<SeedBehavior> seed(
  TddFixture fx, {
  required String testContent,
  required String subjectContent,
}) async {
  await fx.seedTestList([
    (
      id: behaviorId,
      description: description,
      traces: 'Calculator.add',
      state: 'PENDING',
      kind: 'unit',
    ),
  ]);
  await Directory(fx.featureDir).create(recursive: true);
  await File(p.join(fx.featureDir, 'spec.md')).writeAsString(zcalc3Spec);
  await fx.registerBehavior(
    id: behaviorId,
    description: description,
    sourceCriterion: 'FR-001',
    testContent: testContent,
  );
  // make requires a certified red before it drives the cycle; the
  // hashless legacy evidence fails open to the live drift re-run.
  await fx.seedRedEvidence(behaviorId);
  final subjectPath = fx.subjectPathOf(behaviorId);
  await File(subjectPath).parent.create(recursive: true);
  await File(subjectPath).writeAsString(subjectContent);
  return (subjectPath: subjectPath);
}

/// The #1587 no-drift certification: a red entry whose `subject-hash`
/// matches the CURRENT subject bytes — the common
/// verify-red-just-certified path. The drift check is satisfied FROM
/// THE EVIDENCE (no target-test re-run), so a wall-time measurement
/// isolates the func attempt itself. Everything else matches [seed].
Future<SeedBehavior> seedNoDrift(
  TddFixture fx, {
  required String testContent,
  required String subjectContent,
}) async {
  await fx.seedTestList([
    (
      id: behaviorId,
      description: description,
      traces: 'Calculator.add',
      state: 'PENDING',
      kind: 'unit',
    ),
  ]);
  await Directory(fx.featureDir).create(recursive: true);
  await File(p.join(fx.featureDir, 'spec.md')).writeAsString(zcalc3Spec);
  await fx.registerBehavior(
    id: behaviorId,
    description: description,
    sourceCriterion: 'FR-001',
    testContent: testContent,
  );
  final subjectPath = fx.subjectPathOf(behaviorId);
  await File(subjectPath).parent.create(recursive: true);
  await File(subjectPath).writeAsString(subjectContent);
  final hash = sha256.convert(utf8.encode(subjectContent)).toString();
  final cycleLog = File(fx.cycleLogPath);
  await cycleLog.parent.create(recursive: true);
  await cycleLog.writeAsString('''
## Cycle: $behaviorId (red)

- behavior: $behaviorId
- kind: red
- classification: assertionFailure
- criterion: FR-001
- subject-hash: $hash
- test: test/${behaviorId.toLowerCase().replaceAll('-', '_')}_test.dart
- command: `dart test test/${behaviorId.toLowerCase().replaceAll('-', '_')}_test.dart --plain-name "$behaviorId — $description"`
- exit: 1
- at: 2026-09-17T17:18:14.000Z
- output:
```
Expected: <5>
```

''');
  return (subjectPath: subjectPath);
}

typedef SeedBehavior = ({String subjectPath});

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create(featureName: 'zcalc3');
    final pubGet = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: fx.root.path);
    expect(
      pubGet.exitCode,
      0,
      reason: 'pub get failed:\n${pubGet.stdout}${pubGet.stderr}',
    );
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1689 — the scenario × zero-scaffold fast stop (E2E)', () {
    test('E-1689-e1 (AC1): the scenaried make stops BEFORE the pipeline — '
        'no spawns, hand-step remedy, subject survives', () async {
      final seedResult = await seed(
        fx,
        testContent: scenarioTest('5'),
        subjectContent: genStubSubject,
      );
      // The fake zfa stands in for the pipeline: `tdd func` writes the
      // #1517 dummy (the exact bytes the real func pass writes), so the
      // pre-fix attempt shape matches the zcalc3 probe's transcript.
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            behaviorId,
            scalarDummySubject,
          ),
        },
      );

      final clock = Stopwatch()..start();
      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'make',
        behaviorId,
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);
      clock.stop();
      // The measurable analogue of the zcalc3 37.5s span (the fixture's
      // absolute time scales with its target-compile time).
      // ignore: avoid_print
      print('E-1689-e1 make wall time: ${clock.elapsed}');

      expect(exitCode, 1, reason: 'the honest stop exits non-zero: $out');
      expect(
        out,
        contains('outcome=would-never-pass'),
        reason: 'the fast stop grades its own outcome: $out',
      );
      expect(
        out,
        contains('#1689'),
        reason: 'the diagnosis names the issue: $out',
      );
      expect(
        out,
        contains('equals(5)'),
        reason: 'the diagnosis names the offending assertion: $out',
      );
      expect(
        out,
        contains('--> fix:'),
        reason: 'the single-sourced hand-step remedy is printed: $out',
      );
      expect(
        out,
        contains(
          'lib/${behaviorId.toLowerCase().replaceAll('-', '_')}_subject.dart',
        ),
        reason:
            'the remedy names the subject path (the recorded '
            'project-relative form, the 9b call-site convention): $out',
      );

      // The pipeline never ran: ZERO zfa spawns (the #1587 argv-log
      // observability — the fake zfa would have logged `tdd func` and
      // `build`).
      final spawns = await fx.readFakeZfaLog();
      expect(
        spawns,
        isEmpty,
        reason:
            'no zfa subprocess may run for a would-never-pass stop — '
            'the guaranteed-failing attempt is skipped: $spawns',
      );

      // The subject survives byte-identical (#1036) — and trivially so:
      // nothing ran after the gate.
      expect(
        await File(seedResult.subjectPath).readAsString(),
        genStubSubject,
        reason: 'the certified-red stub shape survives the stop',
      );

      // No green evidence may be appended.
      final log = await File(fx.cycleLogPath).readAsString();
      expect(
        log,
        isNot(contains('## Cycle: $behaviorId (green)')),
        reason: 'a would-never-pass stop appends no green entry',
      );
    });

    test('E-1689-e2 (AC3): guard-only → the unchanged 3c vacuous-green '
        'refusal', () async {
      final seedResult = await seed(
        fx,
        testContent: guardOnlyTest(),
        subjectContent: genStubSubject,
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'make',
        behaviorId,
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);

      expect(exitCode, 1, reason: out);
      expect(
        out,
        contains('outcome=vacuous-green'),
        reason:
            'the #1259/#1488 preflight refuses guard-only as before: '
            '$out',
      );
      expect(
        out,
        isNot(contains('outcome=would-never-pass')),
        reason:
            'the new gate must not fire on the non-scenaried class: '
            '$out',
      );
      expect(await File(seedResult.subjectPath).readAsString(), genStubSubject);
    });

    test('E-1689-e3 (AC3): type-only + marker over a dummy subject → the '
        'unchanged 9b vacuous-green refusal', () async {
      final seedResult = await seed(
        fx,
        testContent: typeOnlyMarkerTest(),
        subjectContent: scalarDummySubject,
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'make',
        behaviorId,
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);

      expect(exitCode, 1, reason: out);
      expect(
        out,
        contains('outcome=vacuous-green'),
        reason: 'the #1651 placeholder refusal stands unchanged: $out',
      );
      expect(
        await File(seedResult.subjectPath).readAsString(),
        scalarDummySubject,
      );
    });

    test('E-1689-e4 (AC2): a zero-matching equals(0) keeps the attempt — '
        'the gate stays silent and func spawns', () async {
      await seed(
        fx,
        testContent: scenarioTest('0'),
        subjectContent: genStubSubject,
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            behaviorId,
            scalarDummySubject,
          ),
        },
      );

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'make',
        behaviorId,
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);

      expect(
        out,
        isNot(contains('outcome=would-never-pass')),
        reason:
            'equals(0) may pass on the int dummy — the attempt is not '
            'provably wasted, the gate must stay silent: $out',
      );
      final spawns = await fx.readFakeZfaLog();
      expect(
        spawns.join(' '),
        contains('tdd func'),
        reason:
            'the pipeline ran exactly as before the gate existed: '
            '$spawns',
      );
    });

    test('E-1689-e5 (AC5): a real implementation with a discriminating '
        'scenario test certifies via the unchanged skip transition', () async {
      final seedResult = await seed(
        fx,
        testContent: scenarioTest('5'),
        subjectContent: realAddSubject,
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'make',
        behaviorId,
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=skipped'), reason: out);
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, contains('## Cycle: $behaviorId (green)'), reason: out);
      expect(await File(seedResult.subjectPath).readAsString(), realAddSubject);
    });

    test('E-1689-e6 (SC-002): the no-drift path — with the drift check '
        'satisfied from the certified red (#1587), the pre-fix make '
        'still spends the func write + post-generation target test on '
        'the doomed attempt, and the fast stop spends nothing', () async {
      final seedResult = await seedNoDrift(
        fx,
        testContent: scenarioTest('5'),
        subjectContent: genStubSubject,
      );
      final zfaBin = await fx.writeFakeZfaBin(
        logPath: fx.fakeZfaLogPath,
        sideEffectByArgv: {
          'tdd func': fx.overwriteSubjectCommands(
            behaviorId,
            scalarDummySubject,
          ),
        },
      );

      final clock = Stopwatch()..start();
      final out = await CliRunner(exitOnCompletion: false).runCapturing([
        'tdd',
        'make',
        behaviorId,
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);
      clock.stop();
      // ignore: avoid_print
      print('E-1689-e6 (no-drift) make wall time: ${clock.elapsed}');

      expect(
        out,
        contains('drift check satisfied from the certified red evidence'),
        reason:
            'the drift re-run is deduped (#1587) — the measurement '
            'isolates the attempt: $out',
      );
      expect(exitCode, 1, reason: out);
      expect(out, contains('outcome=would-never-pass'), reason: out);
      final spawns = await fx.readFakeZfaLog();
      expect(
        spawns,
        isEmpty,
        reason: 'zero subprocesses on the no-drift fast stop: $spawns',
      );
      expect(await File(seedResult.subjectPath).readAsString(), genStubSubject);
    });
  });
}
