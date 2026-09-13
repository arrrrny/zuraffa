// SPEC 1568 — `tdd make` reports `outcome=hand-step` for planner-declared
// hand-steps (entity-return contract subjects).
//
// The make integration pins: the post-generation red stop on a behavior
// whose declared contract return is entity-shaped grades the DESIGNED
// hand step (`outcome=hand-step`, issue #1568) — never
// `generation-error` — and the scalar/undeclared classes keep the
// honest generic stop (the SC-7 regression guard).
//
// Mirrors bug_1551's content-level convention: drive the public CLI
// surface in-process via CliRunner against a real temp fixture (real
// `dart test` children; the fixture root is passed via --project).
@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_provenance.dart';

import '../helpers/tdd_fixture.dart';

/// The spec declaring a FUNCTION-row contract whose return is the
/// entity `ScanSession` (the issue's exact subject shape:
/// `ScanSession scan() => throw UnimplementedError(...)`).
String specWithFunctionRow(String returnSignature) =>
    '''
**Template Version**: `zuraffa-1.0`

# Spec: 090-hand-step-1568

## Functional Requirements

- **FR-001**: The scanner exposes the active session.

## Layer Contracts

**Function**:
- `ScanService`: `$returnSignature`
''';

/// The gen contract-derived stub with the VERBATIM entity-typed
/// signature (SPEC 1489 rendering — the entity exists on disk): the
/// provenance markers prove gen wrote it; func's bounded rewrite set
/// does not cover the entity type, so make's #1565 plan-skip fires.
String handStepSubject() => '''
// GENERATED STUB — `zfa tdd gen U1` (spec 044-test-tdd-generation + issue
// #1259 contract derivation).
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
// derived from the spec's declared Layer Contracts.
import 'scan_session.dart';

ScanSession scan() => throw UnimplementedError('implement per declared signature: scan() -> ScanSession');
''';

/// A minimal entity class on disk (the SPEC 1489 verbatim-rendering
/// world: the entity file exists, so the declared type renders
/// verbatim).
String scanSessionEntity() => 'class ScanSession {}\n';

/// The paired test asserting the real declared outcome — red against
/// the throwing stub (an assertion failure, never a compile error).
String handStepTest(String description) =>
    '''
// GENERATED TEST — `zfa tdd gen U1`.
import '../lib/u1_subject.dart';
import '../lib/scan_session.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(scan(), isA<ScanSession>());
  });
}
''';

/// The scalar-contract shape (the SC-7 guard): the declared return is a
/// renderable scalar — func CAN rewrite the stub, so the post-generation
/// red keeps the honest generic stop.
String scalarSubject() => '''
// GENERATED STUB — `zfa tdd gen U1` (spec 044-test-tdd-generation + issue
// #1259 contract derivation).
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
// derived from the spec's declared Layer Contracts.

bool check() => throw UnimplementedError('implement per declared signature: check() -> bool');
''';

String scalarTest(String description) =>
    '''
// GENERATED TEST — `zfa tdd gen U1`.
import '../lib/u1_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$description', () {
    expect(check(), isTrue);
  });
}
''';

void main() {
  late TddFixture fx;
  final runner = CliRunner(exitOnCompletion: false);

  setUp(() async {
    fx = await TddFixture.create(featureName: '090-hand-step-1568');
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  /// Seeds the certified-red world for U1: the declared contract row
  /// (spec.md), the test-list trace cell, the registry pair, and the
  /// red evidence — the state a make walks into after verify-red.
  Future<void> seedHandStepBehavior({
    required String returnSignature,
    required String subjectContent,
    required String testContent,
    String method = 'scan',
    String id = 'U1',
  }) async {
    await File(
      p.join(fx.featureDir, 'spec.md'),
    ).writeAsString(specWithFunctionRow(returnSignature));
    await fx.seedTestList([
      (
        id: 'U1',
        description: 'the scanner exposes the active session',
        traces: 'ScanService.$method',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await fx.seedCertifiedRed(
      id: id,
      description: 'the scanner exposes the active session',
      testContent: testContent,
      subjectContent: subjectContent,
    );
    // The entity on disk (the verbatim-rendering world for the
    // entity-return shape).
    await File(
      p.join(fx.root.path, 'lib', 'scan_session.dart'),
    ).writeAsString(scanSessionEntity());
  }

  group('A-1568-s1: the entity-return post-generation red is a hand-step, '
      'never a generation-error', () {
    test('a make whose plan completed but whose target test is still red '
        'reports outcome=hand-step and exits non-zero', () async {
      await seedHandStepBehavior(
        returnSignature: 'scan() -> ScanSession',
        subjectContent: handStepSubject(),
        testContent: handStepTest('the scanner exposes the active session'),
      );
      final stubBefore = await File(fx.subjectPathOf('U1')).readAsString();
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await runner.runCapturing([
        'tdd',
        'make',
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
        'U1',
      ]);

      // SC-1: the machine summary is the hand-step verdict.
      expect(
        out,
        contains(
          'make: behavior=U1 outcome=hand-step feature=${fx.featureName}',
        ),
        reason: out,
      );
      expect(
        out,
        isNot(contains('outcome=generation-error')),
        reason:
            'the planner declared this behavior hand-step (SPEC 1489 seam '
            'forecast); grading it generation-error is the #1568 wall. '
            'Output:\n$out',
      );
      // The make did not certify green: non-zero exit, no green entry.
      expect(exitCode, isNot(0), reason: out);
      expect(
        await File(fx.cycleLogPath).readAsString(),
        isNot(contains('## Cycle: U1 (green)')),
      );
      // The #1036 failed-make contract holds for the park too: the
      // certified-red subject shape survives byte-identically.
      expect(await File(fx.subjectPathOf('U1')).readAsString(), stubBefore);
      // The func step was skipped (#1565): the plan carried no tdd func
      // spawn — the subject is already the declared contract.
      final log = await fx.readFakeZfaLog();
      expect(
        log.where((l) => l.contains('tdd func')),
        isEmpty,
        reason:
            'the #1565 plan-skip keeps func away from the verbatim '
            'entity-typed subject',
      );
    });
  });

  group('A-1568-s2: the hand-step stop names the designed hand step', () {
    test('the stop message names U1:hand, the declared contract, and the '
        're-run remedy', () async {
      await seedHandStepBehavior(
        returnSignature: 'scan() -> ScanSession',
        subjectContent: handStepSubject(),
        testContent: handStepTest('the scanner exposes the active session'),
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await runner.runCapturing([
        'tdd',
        'make',
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
        'U1',
      ]);

      // SC-2: the #1308 hand-step vocabulary + the declared contract +
      // the exact remedy.
      expect(out, contains('U1:hand'), reason: out);
      expect(out, contains('#1568'), reason: out);
      expect(out, contains('scan() -> ScanSession'), reason: out);
      expect(out, contains('zfa tdd make U1'), reason: out);
    });
  });

  group('A-1568-g1 (SC-7 guard): the honest generic stop stands for the '
      'classes the planner never declared hand-step', () {
    test('a SCALAR-return contract keeps the generation-error stop', () async {
      await seedHandStepBehavior(
        returnSignature: 'check() -> bool',
        subjectContent: scalarSubject(),
        testContent: scalarTest('the scanner validates the session'),
        method: 'check',
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await runner.runCapturing([
        'tdd',
        'make',
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
        'U1',
      ]);

      expect(out, contains('outcome=generation-error'), reason: out);
      expect(out, isNot(contains('outcome=hand-step')), reason: out);
      expect(exitCode, isNot(0), reason: out);
    });

    test('an UNDECLARED behavior (no resolvable contract row) keeps the '
        'generation-error stop', () async {
      // No spec.md, no traces: the classifier must fail OPEN to the
      // generic stop — only the planner's declared seam class parks.
      await fx.seedCertifiedRed(
        id: 'U1',
        description: 'returns 42 when invoked with no args',
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final out = await runner.runCapturing([
        'tdd',
        'make',
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
        'U1',
      ]);

      expect(out, contains('outcome=generation-error'), reason: out);
      expect(out, isNot(contains('outcome=hand-step')), reason: out);
    });
  });

  // The provenance predicate the verbatim shape relies on is pinned by
  // its own suite (func_command_1565_test.dart); this suite pins only
  // that the fixture subject IS that shape — a mis-edited fixture would
  // otherwise silently weaken S1.
  test('fixture integrity: the hand-step subject IS the #1565 refused '
      'shape (func would refuse it)', () {
    expect(
      SubjectProvenance.funcWouldRefuseContractDerivedStub(handStepSubject()),
      isTrue,
    );
    expect(
      SubjectProvenance.funcWouldRefuseContractDerivedStub(scalarSubject()),
      isFalse,
      reason: 'the scalar stub is func-rewritable (the bounded set)',
    );
  });
}
