// SPEC 1536 — contract-row named-parameter syntax (`({a, b})`).
//
// A declared Layer Contract row using Dart named-parameter syntax makes
// `zfa tdd gen` emit a subject + test pair that does not compile
// (FR-011 violation). Two defects compound:
//
//   Defect 1 (brace-ignorant comma split): `Signature.parse` splits the
//   parameter text on every bare comma, so `{level, onRecord}` parses
//   as two POSITIONAL tokens with dangling braces (`{level`,
//   `onRecord}`) — named syntax silently degrades to a positional list.
//
//   Defect 2 (camelCase mangling): `UnitContractShape._defaultParamName`
//   lowercases the whole first word, so the mangled token renders the
//   subject parameter as `onrecord`.
//
// Remediation: parse named parameters (Option A) — named group survives
// whole, named params render `{...}` in subject signatures and named
// arguments in the paired test's capture site — and refuse genuinely
// unparseable parameter syntax with a named remedy riding the existing
// malformed-declaration machinery (Option B's refusal surface).
//
// Test map (specs/1536-named-param-syntax-parsing/spec.md):
//   AC-1/FR-001 — the named group survives as ONE token.
//   AC-2/FR-002 — the shape expands named params; names preserved.
//   AC-3/FR-003 — subject renders `{...}`; test passes named args.
//   AC-4/FR-002 — names-only vs `Type name` group tokens.
//   AC-5/FR-005 — stray braces refuse with the named remedy.
//   AC-6/FR-004 — positional rows stay byte-identical.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/unit_contract_shape.dart';

Behavior unitBehavior(String id, String target) => Behavior(
  id: id,
  feature: '1536-named-param-syntax-parsing',
  kind: BehaviorKind.unit,
  description: 'logs the declared record fields',
  sourceCriterion: 'FR-001',
  target: target,
);

void main() {
  group('1536 AC-1/FR-001: the named group survives as ONE token', () {
    test('a names-only group stays whole with its braces (SC-1)', () {
      final sig = Signature.parse('log({level, onRecord}) -> void');
      expect(sig.name, 'log');
      expect(sig.returnType, 'void');
      expect(sig.parameters, ['{level, onRecord}']);
    });

    test('a typed group stays whole (SC-1)', () {
      final sig = Signature.parse(
        'log({Object? level, Object? onRecord}) -> void',
      );
      expect(sig.parameters, ['{Object? level, Object? onRecord}']);
    });

    test('a mixed row keeps the positional token and the group apart', () {
      final sig = Signature.parse('log(String id, {Object? level}) -> void');
      expect(sig.parameters, ['String id', '{Object? level}']);
    });

    test('a generic type inside the group survives the split', () {
      final sig = Signature.parse('pick({Map<String, int> table}) -> int');
      expect(sig.parameters, ['{Map<String, int> table}']);
    });

    test('an optional-positional group is not corrupted', () {
      final sig = Signature.parse('f(int x, [int a, int b]) -> void');
      expect(sig.parameters, ['int x', '[int a, int b]']);
    });

    test('toString() re-renders the declared text (provenance stays true)', () {
      expect(
        Signature.parse('log({level, onRecord}) -> void').toString(),
        'log({level, onRecord}) -> void',
      );
    });
  });

  group('1536 AC-4/FR-002: the shape expands named params', () {
    test('names-only tokens are NAMES with the Object? type', () {
      final shape = UnitContractShape.of(
        Signature.parse('log({level, onRecord}) -> void'),
      );
      expect(shape.params, hasLength(2));
      expect(shape.params.map((param) => param.name), ['level', 'onRecord']);
      for (final param in shape.params) {
        expect(param.named, isTrue, reason: '${param.name} is a named param');
        expect(param.type, 'Object?');
        expect(param.declaredType, 'Object?');
      }
    });

    test('a two-word group token keeps the Type name split', () {
      final shape = UnitContractShape.of(
        Signature.parse('log({AuthRequest request}) -> void'),
      );
      expect(shape.params.single.name, 'request');
      expect(shape.params.single.declaredType, 'AuthRequest');
      expect(shape.params.single.named, isTrue);
    });

    test('a mixed row carries positional first, then the named group', () {
      final shape = UnitContractShape.of(
        Signature.parse('log(String id, {Object? level}) -> void'),
      );
      expect(shape.params, hasLength(2));
      expect(shape.params.first.named, isFalse);
      expect(shape.params.first.type, 'String');
      expect(shape.params.first.name, 'id');
      expect(shape.params.last.named, isTrue);
      expect(shape.params.last.name, 'level');
    });

    test('ofResolved expands named groups too', () async {
      final tmp = Directory.systemTemp.createTempSync('spec_1536_resolved_');
      File(
        p.join(tmp.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture_app\n');
      try {
        final shape = await UnitContractShape.ofResolved(
          Signature.parse('log({level, onRecord}) -> void'),
          cwd: tmp.path,
        );
        expect(shape.params.map((param) => param.name), ['level', 'onRecord']);
        expect(shape.params.every((param) => param.named), isTrue);
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('1536 AC-6/FR-004: camelCase is preserved, legacy rows unchanged', () {
    test('a lower-first camel identifier is kept verbatim', () {
      // The positional single-identifier reading makes `onRecord` a TYPE
      // here; its derived name must not lose its internal caps (the
      // issue's Defect 2, surfaced through the legacy mangle).
      final shape = UnitContractShape.of(
        Signature.parse('log(onRecord) -> void'),
      );
      expect(shape.params.single.name, 'onRecord');
      expect(shape.params.single.declaredType, 'onRecord');
    });

    test('upper-first type-derived names keep the legacy output', () {
      final shape = UnitContractShape.of(
        Signature.parse('login(AuthRequest) -> User'),
      );
      expect(shape.params.single.name, 'authrequest');
      expect(shape.params.single.type, 'Object?');
    });

    test('an explicit declared name always wins, camelCase intact', () {
      final shape = UnitContractShape.of(
        Signature.parse('log(Record onRecord) -> void'),
      );
      expect(shape.params.single.name, 'onRecord');
      expect(shape.params.single.declaredType, 'Record');
    });
  });

  group('1536 AC-2/AC-3/FR-003: the generated pair renders named', () {
    test('the subject renders the trailing named group (SC-2)', () {
      final shape = UnitContractShape.of(
        Signature.parse('log({level, onRecord}) -> void'),
      );
      final content = SubjectWriter(
        contractShape: shape,
      ).render(unitBehavior('U3', 'subject_u3'));
      expect(
        content,
        contains('void subject_u3({Object? level, Object? onRecord}) =>'),
      );
    });

    test('the subject renders positionals first, group last', () {
      final shape = UnitContractShape.of(
        Signature.parse('log(String id, {Object? level}) -> void'),
      );
      final content = SubjectWriter(
        contractShape: shape,
      ).render(unitBehavior('U3', 'subject_u3'));
      expect(
        content,
        contains('void subject_u3(String id, {Object? level}) =>'),
      );
    });

    test('the paired test passes named arguments (SC-3)', () async {
      final shape = UnitContractShape.of(
        Signature.parse('log({level, onRecord}) -> bool'),
      );
      final tmp = Directory.systemTemp.createTempSync('spec_1536_pair_');
      try {
        final testPath = p.join(tmp.path, 'u3_test.dart');
        await BehaviorTestWriter(contractShape: shape).write(
          behavior: unitBehavior('U3', 'subject_u3'),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u3_subject.dart'),
        );
        final content = File(testPath).readAsStringSync();
        expect(
          content,
          contains('subject.subject_u3(level: _arg0(), onRecord: _arg1())'),
        );
        // No dangling brace fragment anywhere in the generated test.
        expect(content, isNot(contains('{level')));
        expect(content, isNot(contains('onRecord}')));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('scalar named params pass their representative literal', () async {
      final shape = UnitContractShape.of(
        Signature.parse('log(String tag, {int count}) -> int'),
      );
      final tmp = Directory.systemTemp.createTempSync('spec_1536_scalar_');
      try {
        final testPath = p.join(tmp.path, 'u3_test.dart');
        await BehaviorTestWriter(contractShape: shape).write(
          behavior: unitBehavior('U3', 'subject_u3'),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u3_subject.dart'),
        );
        final content = File(testPath).readAsStringSync();
        expect(content, contains("subject.subject_u3(r'sample', count: 0)"));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test('positional rows keep the legacy pair byte-for-byte (SC-6)', () async {
      final shape = UnitContractShape.of(
        Signature.parse('format(String input) -> String'),
      );
      final subject = SubjectWriter(
        contractShape: shape,
      ).render(unitBehavior('U6', 'subject_u6'));
      expect(subject, contains('String subject_u6(String input) =>'));
      final tmp = Directory.systemTemp.createTempSync('spec_1536_legacy_');
      try {
        final testPath = p.join(tmp.path, 'u6_test.dart');
        await BehaviorTestWriter(contractShape: shape).write(
          behavior: unitBehavior('U6', 'subject_u6'),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u6_subject.dart'),
        );
        final content = File(testPath).readAsStringSync();
        expect(content, contains("subject.subject_u6(r'sample')"));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });

    test(
      'the legacy mangled pair is gone: no onrecord, no positional group',
      () async {
        final shape = UnitContractShape.of(
          Signature.parse('log({level, onRecord}) -> void'),
        );
        final subject = SubjectWriter(
          contractShape: shape,
        ).render(unitBehavior('U3', 'subject_u3'));
        expect(subject, isNot(contains('onrecord')));
        expect(subject, isNot(contains('Object? level, Object? onRecord) =>')));
      },
    );
  });

  group('1536 AC-5/FR-005: unparseable syntax refuses with a named remedy', () {
    test('a stray open brace throws FormatException naming the grammar', () {
      expect(
        () => Signature.parse('log({level, onRecord) -> void'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('name(Type) -> Return'),
              contains('{a, b}'),
              contains('--> fix: use the supported parameter grammar'),
            ),
          ),
        ),
      );
    });

    test('a stray close brace throws the same refusal', () {
      expect(
        () => Signature.parse('log(}level) -> void'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains('}level'), contains('--> fix:')),
          ),
        ),
      );
    });

    test('a FUNCTION-layer spec row refuses naming the row and spec line', () {
      const spec = '''
### Layer Contracts

**Function**:
- `Logger`: `log({level, onRecord) -> void`
''';
      expect(
        () => const SpecParser().parseContractRows(spec),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('Logger'),
              contains('log({level, onRecord) -> void'),
              contains('spec line 4'),
              contains('--> fix: use the supported parameter grammar'),
              // Exactly ONE remedy line: the parameter-syntax message
              // carries its own, so no second prefixed copy appears.
              isNot(contains('--> fix: parameter syntax')),
            ),
          ),
        ),
      );
    });

    test('a function-typed parameter refuses with its real cause', () {
      // `_shape`'s `[^)]*` capture ends the parameters region at the
      // first `)`, so this valid Dart callback shape never parses; the
      // refusal names that cause instead of the missing-`-> Return`
      // remedy, which would be wrong advice (the arrow is present).
      for (final raw in const [
        'log(void Function(int) cb) -> void',
        'log({void Function(int) cb}) -> void',
      ]) {
        expect(
          () => Signature.parse(raw),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('not a flat'),
                contains('Function(int) cb'),
                contains('--> fix: declare the callback parameter'),
              ),
            ),
          ),
          reason: raw,
        );
      }
    });

    test(
      'a FUNCTION-layer row with a function-typed parameter names the cause',
      () {
        const spec = '''
### Layer Contracts

**Function**:
- `Logger`: `log(void Function(int) cb) -> void`
''';
        expect(
          () => const SpecParser().parseContractRows(spec),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Logger'),
                contains('not a flat'),
                isNot(contains('add the `-> Return` part.')),
              ),
            ),
          ),
        );
      },
    );
  });
}
