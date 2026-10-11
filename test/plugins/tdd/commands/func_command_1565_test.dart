// SPEC 1565 — `zfa tdd func` is provenance-aware (fast tier).
//
// The gen contract-derived stub (issue #1259 header + SPEC 1489 verbatim
// entity types) is ALREADY the shape the behavior needs: func must treat it
// as a no-op success (exit 0, subject byte-identical) instead of refusing
// with "refusing to rewrite a file this command did not generate". Every
// unrecognized shape WITHOUT the provenance markers keeps the refusal.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import '../helpers/tdd_fixture.dart';

/// The exact subject SubjectWriter's contract-derived template emits for a
/// behavior whose declared entity EXISTS on disk (SPEC 1489): the
/// provenance header, the CONTRACT-DERIVED SUBJECT marker, the declared
/// signature, and the verbatim entity return type.
String genContractDerivedStub(
  String id, {
  String returnType = 'ScanSession',
  String params = '',
  String declaredSignature = 'scan() -> ScanSession',
}) {
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
//     $declaredSignature
//
// This is a MINIMAL
// COMPILABLE STUB: it does NOT satisfy the behavior — the paired test
// fails on first execution (honest red). Replace this stub body with
// the real implementation of the declared contract to make the test
// pass.
// ignore_for_file: non_constant_identifier_names
library;

/// Subject for behavior $id — declared contract:
/// `$declaredSignature`.
///
/// Throws [UnimplementedError] until the real implementation lands.
$returnType $target($params) => throw UnimplementedError('$target not implemented: $declaredSignature');
''';
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    await Directory('${fx.root.path}/lib').create(recursive: true);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> runFunc(String id) {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing(['tdd', 'func', id, '--project', fx.root.path]);
  }

  test(
    'U-1565-1: a contract-derived stub with an existing-entity return is '
    'a no-op success (exit 0, contract-derived-noop, byte-identical)',
    () async {
      await fx.registerBehavior(
        id: 'B-001',
        description: 'the scanner returns the active session',
      );
      final stub = genContractDerivedStub('B-001');
      await File(fx.subjectPathOf('B-001')).writeAsString(stub);

      final out = await runFunc('B-001');

      expect(exitCode, 0, reason: 'out: $out');
      expect(
        out,
        contains(
          'func: behavior=B-001 outcome=contract-derived-noop '
          'feature=${fx.featureName}',
        ),
      );
      final after = await File(fx.subjectPathOf('B-001')).readAsString();
      expect(
        after,
        stub,
        reason: 'the contract-derived subject is not rewritten',
      );
      expect(out, contains('CONTRACT-DERIVED'));
    },
  );

  test('U-1565-2: a parametrized entity contract-derived stub is a no-op '
      'success too', () async {
    await fx.registerBehavior(
      id: 'B-002',
      description: 'login exchanges the request for the session owner',
    );
    final stub = genContractDerivedStub(
      'B-002',
      returnType: 'User',
      params: 'AuthRequest request',
      declaredSignature: 'login(AuthRequest) -> User',
    );
    await File(fx.subjectPathOf('B-002')).writeAsString(stub);

    final out = await runFunc('B-002');

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('outcome=contract-derived-noop'));
    expect(await File(fx.subjectPathOf('B-002')).readAsString(), stub);
  });

  test('U-1565-3: an entity-typed subject WITHOUT the contract-derived '
      'marker still refuses (the did-not-generate guard stands)', () async {
    await fx.registerBehavior(
      id: 'B-003',
      description: 'render returns a non-empty string',
    );
    await File(fx.subjectPathOf('B-003')).writeAsString('''
// GENERATED STUB
library;

User login(AuthRequest request) => throw UnimplementedError('odd');
''');

    final out = await runFunc('B-003');

    expect(exitCode, isNot(0), reason: 'out: $out');
    expect(out, contains('unrecognized'));
    expect(
      out.trim().split('\n').last,
      'func: behavior=B-003 outcome=runner-error feature=${fx.featureName}',
    );
  });

  test('U-1565-4: a provenance-backed stub with a mangled declaration '
      '(block body) still refuses — only the exact gen shape no-ops', () async {
    await fx.registerBehavior(
      id: 'B-004',
      description: 'the scanner returns the active session',
    );
    await File(fx.subjectPathOf('B-004')).writeAsString('''
// GENERATED STUB — `zfa tdd gen B-004` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
library;

ScanSession subject_b_004() {
  throw UnimplementedError('mangled');
}
''');

    final out = await runFunc('B-004');

    expect(exitCode, isNot(0), reason: 'out: $out');
    expect(out, contains('unrecognized'));
  });

  test('U-1565-5: an implemented contract-derived subject keeps the '
      'already-implemented path (no UnimplementedError left)', () async {
    await fx.registerBehavior(
      id: 'B-005',
      description: 'the scanner returns the active session',
    );
    await File(fx.subjectPathOf('B-005')).writeAsString('''
// GENERATED STUB — `zfa tdd gen B-005` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
library;

ScanSession subject_b_005() => ScanSession();
''');

    final out = await runFunc('B-005');

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('outcome=already-implemented'));
  });

  test(
    'U-1565-6: a generic entity return (List<Task>) is a no-op success',
    () async {
      await fx.registerBehavior(
        id: 'B-006',
        description: 'the scanner lists the tracked tasks',
      );
      final stub = genContractDerivedStub(
        'B-006',
        returnType: 'List<Task>',
        declaredSignature: 'scanTasks() -> List<Task>',
      );
      await File(fx.subjectPathOf('B-006')).writeAsString(stub);

      final out = await runFunc('B-006');

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=contract-derived-noop'));
      expect(await File(fx.subjectPathOf('B-006')).readAsString(), stub);
    },
  );

  test('U-1565-7: a legacy plain-function stub still scaffolds '
      '(the bounded path is untouched)', () async {
    await fx.registerBehavior(
      id: 'B-007',
      description:
          'render returns a non-empty string for a fully populated task',
    );
    await File(fx.subjectPathOf('B-007')).writeAsString('''
// GENERATED STUB — `zfa tdd gen B-007` (spec 044-test-tdd-generation).
library;

/// Subject for behavior B-007.
int subject_b_007() => throw UnimplementedError('subject_b_007 not implemented');
''');

    final out = await runFunc('B-007');

    expect(exitCode, 0, reason: 'out: $out');
    expect(out, contains('outcome=scaffolded'));
    final subject = await File(fx.subjectPathOf('B-007')).readAsString();
    expect(subject, contains('String subject_b_007()'));
    expect(subject, isNot(contains('UnimplementedError')));
  });
}
