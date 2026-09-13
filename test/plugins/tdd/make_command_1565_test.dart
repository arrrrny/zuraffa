@Tags(['slow'])
// SPEC 1565 — `zfa tdd make` does not schedule the doomed func step
// (slow tier: the make runs real `dart test` subprocesses in the fixture).
//
// When the behavior's subject is already the gen contract-derived stub
// (issue #1259 provenance header + a SPEC-1489 verbatim entity signature
// func's bounded rewrite set does not cover), the plan must skip the
// `tdd func` step: scheduling it dead-ends the make in a generation-error
// ON A SUBJECT THAT IS ALREADY WHAT THE BEHAVIOR NEEDS. A scalar
// contract-derived subject (func CAN rewrite it — the declared-dummy path)
// keeps the func step.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// The exact subject SubjectWriter's contract-derived template emits when
/// the declared entity EXISTS on disk (SPEC 1489 verbatim rendering) — the
/// #1565 deadlock shape.
String contractDerivedSubject(String id) {
  final symbol = id.toLowerCase().replaceAll('-', '_');
  final target = 'subject_$symbol';
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// behavior_id: $id
// source_criterion: FR-1
// description: the scanner returns the active session
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
// derived from the spec's declared Layer Contract:
//
//     scan() -> ScanSession
//
// This is a MINIMAL
// COMPILABLE STUB: it does NOT satisfy the behavior — the paired test
// fails on first execution (honest red). Replace this stub body with
// the real implementation of the declared contract to make the test
// pass.
// ignore_for_file: non_constant_identifier_names
library;

/// Subject for behavior $id — declared contract:
/// `scan() -> ScanSession`.
///
/// Throws [UnimplementedError] until the real implementation lands.
ScanSession $target() => throw UnimplementedError('$target not implemented: scan() -> ScanSession');
''';
}

/// A compiling standalone red test (no subject import): the honest red the
/// baseline and the post-generation target run both observe. The target
/// test's grade after generation is the PRE-EXISTING make machinery (the
/// #1565 constraints leave it untouched); this suite pins the PLAN shape.
const _redTest = '''
import 'package:test/test.dart';

void main() {
  test('the scanner returns the active session', () {
    expect(1, equals(2));
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

  group('SPEC 1565 — make plan skip for contract-derived subjects', () {
    test('U-1565-10: a contract-derived entity subject schedules NO tdd func '
        'step and the func refusal never appears', () async {
      const id = 'U1';
      final subject = contractDerivedSubject(id);
      await fx.seedCertifiedRed(
        id: id,
        description: 'the scanner returns the active session',
        testContent: _redTest,
        subjectContent: subject,
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        id,
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);

      final log = await File(fx.fakeZfaLogPath).readAsString();
      // The plan skipped the func step: the pipeline never spawned it.
      expect(
        log,
        isNot(contains('tdd func')),
        reason:
            'the func step must not be scheduled for a contract-derived '
            'subject (out: $out)',
      );
      expect(log, contains('build'), reason: 'out: $out');
      // The #1565 refusal — the symptom this spec removes — never prints.
      expect(out, isNot(contains('refusing to rewrite a file this command')));
      // The subject survives byte-identical (func never rewrote it; the
      // #1036 restore contract holds).
      expect(await File(fx.subjectPathOf(id)).readAsString(), subject);
      // The skip is visible in the make output for audit.
      expect(out, contains('#1565'));
    });

    test('U-1565-11: a scalar contract-derived subject KEEPS the func step '
        '(the declared-dummy path is not regressed)', () async {
      const id = 'U2';
      await fx.seedCertifiedRed(
        id: id,
        description: 'returns 42 when invoked with no args',
        testContent: _redTest,
        subjectContent:
            '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
//
//     count() -> int
//
library;

int subject_u2() => throw UnimplementedError('subject_u2 not implemented: count() -> int');
''',
      );
      final zfaBin = await fx.writeFakeZfaBin(logPath: fx.fakeZfaLogPath);

      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'make',
        id,
        '--project',
        fx.root.path,
        '--zfa-bin',
        zfaBin,
      ]);

      final log = await File(fx.fakeZfaLogPath).readAsString();
      expect(
        log,
        contains('tdd func'),
        reason:
            'func CAN rewrite a scalar contract-derived stub — the step is '
            'kept (out: $out)',
      );
      expect(out, isNot(contains('plan: func step skipped')));
    });
  });
}
