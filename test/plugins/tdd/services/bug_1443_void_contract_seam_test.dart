// Issue #1443 — a void-return traced contract emitted a NON-COMPILING
// pair: `ContractSubjectWriter._render` treats `void` as renderable
// (it is in `_scalarTypes`), so the subject seam was `void register(...)`
// while the paired test captures `final Object? outcome = _captured(() =>
// impl(...))` — `return`ing a void value is a compile error and
// verify-red classifies the pair compile-error (violating gen's spec-044
// contract: a compiling honest-red pair).
//
// Fix under test (spec 1443-void-contract-seam): `void` is
// non-renderable for the seam — the subject returns `Object?` like the
// entity-return case, so the capture compiles and the honest red stands.
//
// Behaviors:
//   B1 — a void-return contract renders the subject seam as
//        `Object? register(...)` (never `void register(...)`).
//   B2 — a non-void contract still renders its declared renderable
//        return (`int add(...)`).

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_test_writer.dart';

Behavior _contract(String signature) => Behavior(
  id: 'A1',
  feature: '035-fixture',
  kind: BehaviorKind.contract,
  description: 'contract:A1 — $signature (usecase contract)',
  sourceCriterion: 'AC-1',
  target: signature.substring(0, signature.indexOf('(')),
);

Future<String> writeSubject(Behavior b, Directory tmp) async {
  final subjectPath = p.join(
    tmp.path,
    'lib',
    'tdd',
    '035-fixture',
    'a1_subject.dart',
  );
  await const ContractSubjectWriter().write(
    behavior: b,
    subjectPath: subjectPath,
  );
  return File(subjectPath).readAsStringSync();
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('zfa-1443');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('B1: a void-return contract renders an Object? seam', () async {
    final source = await writeSubject(
      _contract('MessagingService.register(MessageTransport) -> void'),
      tmp,
    );
    expect(
      source,
      contains('Object? register('),
      reason: 'the seam returns Object? so the capture pattern compiles',
    );
    expect(
      source,
      isNot(contains('void register(')),
      reason: 'a void seam cannot feed the capture-based guard test',
    );
  });

  test('B2: a non-void renderable return is unchanged (guard)', () async {
    final source = await writeSubject(
      _contract('Calculator.add(int a, int b) -> int'),
      tmp,
    );
    expect(source, contains('int add('), reason: source);
  });
}
