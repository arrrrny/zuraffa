// Issue #1363 — `zfa tdd gen` emits an UNCOMPILABLE contract subject
// stub for multi-param declared contracts: bare-name cells (the Layer
// Contracts grammar `validate(email, password) -> LoginVerdict`) each
// fall back to `arg0`, so the generated signature is
// `validate(Object? arg0, Object? arg0)` — duplicate parameter names,
// duplicate_definition at analysis, and a load-error that smears the
// verify-red batch classification.
//
// Contract under test (spec 1363-contract-stub-dup-args):
//   B1 — the issue's exact repro: bare-name cells become the DECLARED
//        parameter names (`dynamic email`, `dynamic password`) — no
//        duplicate names in the emitted subject signature.
//   B2 — typed cells keep their declared names and types.
//   B3 — bare NON-identifier cells (unnamed generic types) fall back to
//        positional arg<i> names — distinct per position.
//   B4 — the generated contract TEST no longer echoes duplicate names
//        in its signature summary.
//   B5 — a mixed row (typed + bare cells) keeps every name unique.

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_test_writer.dart';

Behavior _contractBehavior(String signature) => Behavior(
  id: 'A1',
  feature: '035-fixture',
  kind: BehaviorKind.contract,
  description: 'contract:A1 — $signature (usecase contract)',
  sourceCriterion: 'AC-1',
  target: signature.substring(0, signature.indexOf('(')),
);

Future<File> _writePair(Behavior b, Directory tmp) async {
  final subjectPath = p.join(
    tmp.path,
    'lib',
    'tdd',
    '035-fixture',
    'contract_a1_subject.dart',
  );
  final testPath = p.join(
    tmp.path,
    'test',
    'tdd',
    '035-fixture',
    'contract_a1_test.dart',
  );
  await const ContractSubjectWriter().write(
    behavior: b,
    subjectPath: subjectPath,
  );
  await const ContractTestWriter().write(
    behavior: b,
    testPath: testPath,
    subjectPath: subjectPath,
  );
  return File(subjectPath);
}

/// Extracts the parameter-name list from the subject's ACTUAL method
/// signature — skipping comment lines (the stub's header echoes the
/// declared grammar verbatim, which is not the emitted signature).
List<String> _paramNamesOf(String subjectSource, String method) {
  final marker = '$method(';
  var searchFrom = 0;
  var open = -1;
  while (true) {
    open = subjectSource.indexOf(marker, searchFrom);
    expect(
      open,
      greaterThanOrEqualTo(0),
      reason: 'the subject declares the method',
    );
    final lineStart = subjectSource.lastIndexOf('\n', open) + 1;
    final linePrefix = subjectSource.substring(lineStart, open).trim();
    if (!linePrefix.startsWith('//')) break;
    searchFrom = open + marker.length;
  }
  final close = subjectSource.indexOf(')', open);
  final inside = subjectSource.substring(open + method.length + 1, close);
  if (inside.trim().isEmpty) return [];
  // Depth-aware split: generic commas (`Map<String, int>`) are not
  // parameter separators.
  final names = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < inside.length; i++) {
    final c = inside[i];
    if (c == '<' || c == '(') depth++;
    if (c == '>' || c == ')') depth--;
    if (c == ',' && depth == 0) {
      names.add(inside.substring(start, i).trim().split(' ').last);
      start = i + 1;
    }
  }
  names.add(inside.substring(start).trim().split(' ').last);
  return names;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('zfa-1363');
  });

  tearDown(() => tmp.delete(recursive: true));

  test(
    'B1: the issue repro — bare-name cells keep their declared names',
    () async {
      final subject = await _writePair(
        _contractBehavior(
          'LoginValidation.validate(email, password) -> LoginVerdict',
        ),
        tmp,
      );
      final source = await subject.readAsString();
      final names = _paramNamesOf(source, 'validate');
      expect(
        names,
        ['email', 'password'],
        reason:
            'the declared parameter names survive into the stub — '
            'never a duplicate arg0 pair',
      );
      expect(
        names.toSet().length,
        names.length,
        reason: 'duplicate parameter names never compile',
      );
    },
  );

  test('B2: typed cells keep declared names and types', () async {
    final subject = await _writePair(
      _contractBehavior('Calculator.sum(int a, int b) -> int'),
      tmp,
    );
    final source = await subject.readAsString();
    expect(_paramNamesOf(source, 'sum'), ['a', 'b']);
    expect(source, contains('int a'));
    expect(source, contains('int b'));
  });

  test(
    'B3: unnamed generic-type params fall back to positional names',
    () async {
      final subject = await _writePair(
        _contractBehavior(
          'Processor.process(List<int>, Map<String, int>) -> void',
        ),
        tmp,
      );
      final source = await subject.readAsString();
      final names = _paramNamesOf(source, 'process');
      expect(
        names,
        ['arg0', 'arg1'],
        reason:
            'the positional fallback numbers per position — '
            'never the same name twice',
      );
    },
  );

  test('B4: the generated test summary echoes unique names', () async {
    final behavior = _contractBehavior(
      'LoginValidation.validate(email, password) -> LoginVerdict',
    );
    final testPath = p.join(
      tmp.path,
      'test',
      'tdd',
      '035-fixture',
      'contract_a1_test.dart',
    );
    final subjectPath = p.join(
      tmp.path,
      'lib',
      'tdd',
      '035-fixture',
      'contract_a1_subject.dart',
    );
    await const ContractTestWriter().write(
      behavior: behavior,
      testPath: testPath,
      subjectPath: subjectPath,
    );
    final source = await File(testPath).readAsString();
    expect(source, contains('dynamic email, dynamic password'));
    expect(
      source,
      isNot(contains('arg0, Object? arg0')),
      reason: 'the duplicate-arg echo from the issue is gone',
    );
  });

  test(
    'B6: a repeated declared name falls back to a unique positional name',
    () async {
      final subject = await _writePair(
        _contractBehavior(
          'LoginValidation.validate(email, email) -> LoginVerdict',
        ),
        tmp,
      );
      final source = await subject.readAsString();
      final names = _paramNamesOf(source, 'validate');
      expect(
        names.toSet().length,
        names.length,
        reason:
            'duplicate_definition can never return via a repeated '
            'declared name',
      );
    },
  );

  test('B5: a mixed row keeps every name unique', () async {
    final subject = await _writePair(
      _contractBehavior(
        'Transfer.send(int amount, currency, AuditTrail trail) -> void',
      ),
      tmp,
    );
    final source = await subject.readAsString();
    final names = _paramNamesOf(source, 'send');
    expect(
      names.toSet().length,
      names.length,
      reason: 'every parameter name in the signature is unique',
    );
  });
}
