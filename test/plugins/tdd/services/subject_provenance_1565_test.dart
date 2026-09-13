// SPEC 1565 — the shared subject-provenance predicates (fast tier).
//
// The single source of truth for the gen contract-derived stub markers and
// func's rewritability set: make's plan decision (skip the func step) and
// func's refusal decision (no-op vs refuse) must not be able to disagree.
// The markers are consumed verbatim from SubjectWriter's contract-derived
// template (`_renderContractUnitSubject`) so the two sides cannot drift.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_provenance.dart';

/// The exact header + declaration SubjectWriter emits for a contract-
/// derived unit stub whose declared entity EXISTS on disk (SPEC 1489
/// verbatim rendering) — the #1565 deadlock shape.
String contractDerivedStub({
  String id = 'U1',
  String returnType = 'ScanSession',
  String target = 'subject_u1',
  String params = '',
  String declaredSignature = 'scan() -> ScanSession',
  String headerSuffix =
      '(spec 044-test-tdd-generation\n'
      '// + issue #1259 contract derivation).',
}) {
  return '''
// GENERATED STUB — `zfa tdd gen $id` $headerSuffix
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
library;

/// Subject for behavior $id — declared contract:
/// `$declaredSignature`.
$returnType $target($params) => throw UnimplementedError('$target not implemented: $declaredSignature');
''';
}

void main() {
  group('isContractDerivedGenStub (provenance markers)', () {
    test('U-1565-P1: both markers present → true', () {
      expect(
        SubjectProvenance.isContractDerivedGenStub(contractDerivedStub()),
        isTrue,
      );
    });

    test('U-1565-P2: the gen header WITHOUT the contract-derived marker '
        '→ false (the legacy/hand-authored class)', () {
      const legacy = '''
// GENERATED STUB — `zfa tdd gen U1` (spec 044-test-tdd-generation).
library;

int subject_u1() => throw UnimplementedError('subject_u1 not implemented');
''';
      expect(SubjectProvenance.isContractDerivedGenStub(legacy), isFalse);
    });

    test('U-1565-P3: the contract-derived marker WITHOUT the gen header '
        '→ false (never treats a non-gen file as gen output)', () {
      const markerOnly = '''
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
library;

ScanSession subject_u1() => throw UnimplementedError('x');
''';
      expect(SubjectProvenance.isContractDerivedGenStub(markerOnly), isFalse);
    });
  });

  group('funcRewritableStubPattern (func\'s bounded rewrite set)', () {
    test('U-1565-P4: legacy bounded shapes still match', () {
      const shapes = [
        "int subject_u1() => throw UnimplementedError('subject_u1 not implemented');",
        "String subject_u1() => throw UnimplementedError('x');",
        "Object? login(Object? request) => throw UnimplementedError('x');",
        "void subject_u1() => throw UnimplementedError('x');",
      ];
      for (final shape in shapes) {
        expect(
          SubjectProvenance.funcRewritableStubPattern.hasMatch(shape),
          isTrue,
          reason: shape,
        );
      }
    });

    test('U-1565-P5: entity-typed signatures do NOT match the bounded set', () {
      const shapes = [
        "ScanSession subject_u1() => throw UnimplementedError('x');",
        "User login(AuthRequest request) => throw UnimplementedError('x');",
        "List<Task> scanTasks() => throw UnimplementedError('x');",
        "Task? latest() => throw UnimplementedError('x');",
      ];
      for (final shape in shapes) {
        expect(
          SubjectProvenance.funcRewritableStubPattern.hasMatch(shape),
          isFalse,
          reason: shape,
        );
      }
    });
  });

  group('contractDerivedDeclarationPattern (the gen-emitted shape)', () {
    test('U-1565-P6: recognizes every declaration gen emits', () {
      const shapes = [
        "ScanSession subject_u1() => throw UnimplementedError('subject_u1 not implemented: scan() -> ScanSession');",
        "User login(AuthRequest request) => throw UnimplementedError('login not implemented: login(AuthRequest) -> User');",
        "Task? latest(String board) => throw UnimplementedError('x');",
        "List<Task> scanTasks(String board) => throw UnimplementedError('x');",
        "int count() => throw UnimplementedError('x');",
      ];
      for (final shape in shapes) {
        expect(
          SubjectProvenance.contractDerivedDeclarationPattern.hasMatch(shape),
          isTrue,
          reason: shape,
        );
      }
    });

    test('U-1565-P6b: a block-bodied or non-throw declaration does not '
        'match (the mangled/hand classes)', () {
      const shapes = [
        "int subject_u1() { throw UnimplementedError('x'); }",
        "ScanSession subject_u1() => 'done';",
      ];
      for (final shape in shapes) {
        expect(
          SubjectProvenance.contractDerivedDeclarationPattern.hasMatch(shape),
          isFalse,
          reason: shape,
        );
      }
    });
  });

  group('funcWouldRefuseContractDerivedStub (the plan-skip predicate)', () {
    test('U-1565-P7: provenance + throw + non-rewritable → true', () {
      expect(
        SubjectProvenance.funcWouldRefuseContractDerivedStub(
          contractDerivedStub(),
        ),
        isTrue,
      );
    });

    test('U-1565-P7b: a scalar contract-derived stub (func CAN rewrite it) '
        '→ false — the declared-dummy path keeps its func step', () {
      expect(
        SubjectProvenance.funcWouldRefuseContractDerivedStub(
          contractDerivedStub(
            returnType: 'int',
            declaredSignature: 'count() -> int',
          ),
        ),
        isFalse,
      );
    });

    test('U-1565-P7c: provenance + no throw (already implemented) → false', () {
      final implemented = contractDerivedStub().replaceFirst(
        ' => throw UnimplementedError(\'subject_u1 not implemented: scan() -> ScanSession\');',
        " => 'done';",
      );
      expect(
        SubjectProvenance.funcWouldRefuseContractDerivedStub(implemented),
        isFalse,
      );
    });

    test('U-1565-P7d: no provenance (hand-authored entity subject) → false '
        '— the plan never skips on a file gen did not write', () {
      const handAuthored = '''
library;

User login(AuthRequest request) => throw UnimplementedError('x');
''';
      expect(
        SubjectProvenance.funcWouldRefuseContractDerivedStub(handAuthored),
        isFalse,
      );
    });
  });
}
