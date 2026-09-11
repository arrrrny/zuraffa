// Bug #1512 — the acceptance lane is a vacuous composition seam.
//
// Three pins, one per root cause:
//
//   (a) the acceptance capture stays the VOID-SAFE, ARGUMENT-FREE form: the
//       paired subject is a parameterless `void` scenario runner, and an
//       injected contract shape must NOT thread args or return a value — the
//       "thread declared args / assert the declared result" composition is
//       unreachable from `gen` (which resolves a shape only for unit
//       behaviours) and would be a `use_of_void_result` + arity compile
//       error against the pair production actually builds;
//   (b) the acceptance fallback names its gap with the acceptance-lane token
//       — never the #1259 vacuous-guard marker, whose presence is the run
//       driver's traced hand-delta (`stopped_at=<id>:hand`) discriminator;
//   (c) the planner returns a real make surface for acceptance rows (entity
//       pipeline when an EXPLICIT prose signal names an entity; the spec-052
//       composition lane otherwise) instead of the default unexpressible.
//
// Content-level assertions (the bug_830/bug_912 convention): the emitted
// artifacts are validated through `write()` / `plan()` into a temp tree. The
// slow pin runs the emitted test+subject pair through `dart test` — the
// compile proof the round-2 review asked for — and the structural pins prove
// the call site and the paired subject's signature stay arity-compatible.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/unit_contract_shape.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

Behavior acceptanceBehavior({
  String id = 'A1',
  String description = 'the session starts.',
  String target = 'subject_a1',
}) => Behavior(
  id: id,
  feature: '1512-acceptance-vacuous-composition',
  kind: BehaviorKind.acceptance,
  description: description,
  sourceCriterion: 'AC-1',
  target: target,
);

Future<String> renderTest(Behavior behavior, {UnitContractShape? shape}) async {
  final dir = Directory.systemTemp.createTempSync('bug_1512_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final testPath = p.join(dir.path, 'test', 'tdd', 'a1_test.dart');
  final subjectPath = p.join(dir.path, 'lib', 'tdd', 'a1_subject.dart');
  await BehaviorTestWriter(
    contractShape: shape,
  ).write(behavior: behavior, testPath: testPath, subjectPath: subjectPath);
  return File(testPath).readAsString();
}

UnitContractShape shapeOf(String declared) =>
    UnitContractShape.of(Signature.parse(declared));

void main() {
  group('bug #1512 (a): the acceptance capture is the void-safe, '
      'argument-free form', () {
    test('an undeclared acceptance row emits the parameterless void-safe '
        'capture — never a threaded call or a returned result', () async {
      final content = await renderTest(acceptanceBehavior());
      expect(
        content,
        contains('subject.subject_a1();'),
        reason:
            'the paired acceptance subject is a parameterless `void '
            'subject_a1()` scenario runner (subject_writer.dart) — the call '
            'site must match its arity',
      );
      expect(
        content,
        contains('return null;'),
        reason:
            'the void scenario runner has no value to return; the capture '
            'stays void-safe (`final Object? result`)',
      );
      expect(content, contains('final Object? result'));
      expect(content, isNot(contains('return subject.')));
    });

    test(
      'a directly-injected scalar shape is inert for acceptance — the '
      'gen pipeline never supplies one, so it must not thread args',
      () async {
        final content = await renderTest(
          acceptanceBehavior(),
          shape: shapeOf('start(String session) -> String'),
        );
        expect(
          content,
          contains('subject.subject_a1();'),
          reason:
              'acceptance subjects take no arguments; threading the declared '
              'args would be an arity compile error against the emitted pair',
        );
        expect(content, isNot(contains('return subject.')));
        expect(content, isNot(contains('r\'sample\'')));
        expect(content, isNot(contains('_arg0()')));
        expect(
          content,
          isNot(contains('isA<String>()')),
          reason:
              'the acceptance capture can never yield a declared non-void '
              'result, so a declared outcome assertion would sit on null',
        );
      },
    );

    test('a directly-injected entity-return shape is inert too', () async {
      final content = await renderTest(
        acceptanceBehavior(),
        shape: shapeOf('complete(String session) -> Todo'),
      );
      expect(content, contains('subject.subject_a1();'));
      expect(content, isNot(contains('return subject.')));
      expect(content, isNot(contains('_arg0()')));
    });

    test('the paired subject signature the writer targets is the '
        'parameterless `void` scenario runner the test calls', () async {
      final dir = Directory.systemTemp.createTempSync('bug_1512_pair_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final behavior = acceptanceBehavior();
      final testPath = p.join(dir.path, 'test', 'tdd', 'a1_test.dart');
      final subjectPath = p.join(dir.path, 'lib', 'tdd', 'a1_subject.dart');
      await const BehaviorTestWriter().write(
        behavior: behavior,
        testPath: testPath,
        subjectPath: subjectPath,
      );
      await const SubjectWriter().write(
        behavior: behavior,
        subjectPath: subjectPath,
      );
      final subject = File(subjectPath).readAsStringSync();
      final content = File(testPath).readAsStringSync();
      expect(
        subject,
        contains('void subject_a1() => throw UnimplementedError'),
        reason: 'the paired subject is a parameterless void scenario runner',
      );
      expect(
        content,
        contains('subject.subject_a1();'),
        reason: 'the test call is arity-compatible with the paired subject',
      );
    });
  });

  group('bug #1512 (b): the acceptance fallback names its gap without the '
      'traced hand-delta marker', () {
    test('an undeclared acceptance fallback carries the acceptance token — '
        'never the #1259 vacuous-guard marker', () async {
      final content = await renderTest(
        acceptanceBehavior(description: 'the scenario completes.'),
      );
      expect(
        content,
        contains('expect(result, isNot(isA<UnimplementedError>()));'),
        reason: 'the guard stays as the red surface (the stub throws)',
      );
      expect(
        content,
        contains(acceptanceFallbackGuardToken),
        reason: 'the acceptance lane names its own fallback gap',
      );
      expect(
        content,
        isNot(contains(vacuousGuardMarker)),
        reason:
            'marker presence is the run driver\'s traced hand-delta '
            '(`stopped_at=<id>:hand`) discriminator; this fallback is not a '
            'traced contract and its honest class is `:make`',
      );
      expect(contentCarriesVacuousGuardMarker(content), isFalse);
      expect(
        contentIsVacuousGreen(content),
        isTrue,
        reason:
            'the guard-only set is still refused by the content backstop — '
            'the refusal never depended on the marker',
      );
    });

    test('the acceptance fallback does not reuse the unit-lane comment '
        'block', () async {
      final content = await renderTest(
        acceptanceBehavior(description: 'the scenario completes.'),
      );
      expect(content, contains(acceptanceFallbackGuardToken));
      expect(content, isNot(contains(vacuousGuardComment)));
    });
  });

  group('bug #1512 (c): the planner returns a real make surface for '
      'acceptance rows', () {
    const planner = GenerationPlanner();

    BehaviorSummary acceptanceSummary(
      String description, {
      String id = 'A1',
      String? target,
      BehaviorKind? kind = BehaviorKind.acceptance,
    }) => BehaviorSummary(
      behaviorId: id,
      feature: '1512-acceptance-vacuous-composition',
      sourceCriterion: 'AC-1',
      description: description,
      target: target,
      kind: kind,
    );

    test('a plain scenario row routes to the spec-052 composition lane '
        '(tdd compose → build) — not unexpressible', () {
      final plan = planner.plan(
        acceptanceSummary('the user completes a todo item.'),
      );
      expect(
        plan.isExpressible,
        isTrue,
        reason:
            'the acceptance lane must have a real make surface — '
            'unexpressible is not the default (issue #1512)',
      );
      expect(plan.steps, hasLength(2));
      expect(plan.steps.first.args, [
        'tdd',
        'compose',
        'A1',
        '--feature',
        '1512-acceptance-vacuous-composition',
      ]);
      expect(plan.steps.last.args, ['build']);
    });

    test('an incidental capitalised word does NOT fabricate an entity — the '
        'row composes instead', () {
      final plan = planner.plan(acceptanceSummary('the User signs in.'));
      expect(
        plan.isExpressible,
        isTrue,
        reason: 'the row still has a real make surface (the compose lane)',
      );
      expect(
        plan.steps.first.args.first,
        'tdd',
        reason:
            'a capitalised word in scenario prose is not a declared entity: '
            '`entity create -n User` would scaffold use-cases/repositories/DI '
            'for an entity nobody asked for (issue #1512 review)',
      );
      expect(plan.steps, hasLength(2));
    });

    test('a scenario row that names an entity ONLY by a capitalised word '
        'composes (no entity pipeline from prose alone)', () {
      final plan = planner.plan(
        acceptanceSummary('the Todo item persists across restarts.'),
      );
      expect(plan.steps.first.args.first, 'tdd');
      expect(plan.steps, hasLength(2));
    });

    test('an explicit `entity <Name>` prose signal routes to the #758 entity '
        'pipeline (entity create → make → wire → build)', () {
      final plan = planner.plan(
        acceptanceSummary('entity Todo persists across restarts.'),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps, hasLength(4));
      expect(plan.steps[0].args, ['entity', 'create', '-n', 'Todo']);
      expect(plan.steps[1].args, ['make', 'Todo']);
      expect(plan.steps[2].args, [
        'tdd',
        'wire',
        'A1',
        '--entity',
        'Todo',
        '--feature',
        '1512-acceptance-vacuous-composition',
      ]);
      expect(plan.steps.last.args, ['build']);
    });

    test('an explicit `create <Name>` prose signal routes to the entity '
        'pipeline too', () {
      final plan = planner.plan(
        acceptanceSummary('create Invoice for the order.'),
      );
      expect(plan.steps.first.args, ['entity', 'create', '-n', 'Invoice']);
    });

    test('an explicit target wins the entity derivation', () {
      final plan = planner.plan(
        acceptanceSummary('the scenario completes.', target: 'Invoice'),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.first.args, ['entity', 'create', '-n', 'Invoice']);
    });

    test('the honest #758 refusal stays: CRUD prose with no named entity '
        'is still the actionable unexpressible stop', () {
      final plan = planner.plan(
        acceptanceSummary('the repository service persists the scenario.'),
      );
      expect(plan.isExpressible, isFalse);
      expect(
        plan.unexpressibleReason,
        contains('names no entity'),
        reason:
            'the #758 refusal names the remedy (name the entity, or add a '
            'green unit behavior for the composition fallback)',
      );
    });

    test('non-acceptance rows keep the generic misfire (the branch must '
        'not steal them)', () {
      final plan = planner.plan(
        const BehaviorSummary(
          behaviorId: 'B-009',
          feature: '1512-acceptance-vacuous-composition',
          sourceCriterion: 'FR-1',
          description: 'something unrouteable happens.',
        ),
      );
      expect(plan.isExpressible, isFalse);
      expect(plan.unexpressibleReason, contains('no generator surface maps'));
    });
  });

  group('bug #1512 guardrails: the unit lane stays byte-for-byte', () {
    test('a unit scalar capture keeps the inferred annotation, the '
        'threaded args, and the isA<T>() assertion — no marker', () async {
      final dir = Directory.systemTemp.createTempSync('bug_1512_unit_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final testPath = p.join(dir.path, 'test', 'tdd', 'u1_test.dart');
      final subjectPath = p.join(dir.path, 'lib', 'tdd', 'u1_subject.dart');
      await BehaviorTestWriter(
        contractShape: shapeOf('login(String session) -> bool'),
      ).write(
        behavior: Behavior(
          id: 'U1',
          feature: '1512-acceptance-vacuous-composition',
          kind: BehaviorKind.unit,
          description: 'the login outcome.',
          sourceCriterion: 'FR-1',
          target: 'subject_u1',
        ),
        testPath: testPath,
        subjectPath: subjectPath,
      );
      final content = await File(testPath).readAsString();
      expect(content, contains('final result = (() {'));
      expect(content, isNot(contains('final Object? result')));
      expect(content, contains("return subject.subject_u1(r'sample');"));
      expect(content, contains('expect(result, isA<bool>())'));
      expect(content, isNot(contains(vacuousGuardMarker)));
      expect(content, isNot(contains(acceptanceFallbackGuardToken)));
    });

    test('an undeclared unit fallback guard stays UNMARKED (the #1308 '
        'fallback-remedy class is unit-lane only)', () async {
      final dir = Directory.systemTemp.createTempSync('bug_1512_unit2_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final testPath = p.join(dir.path, 'test', 'tdd', 'u2_test.dart');
      final subjectPath = p.join(dir.path, 'lib', 'tdd', 'u2_subject.dart');
      await const BehaviorTestWriter().write(
        behavior: Behavior(
          id: 'U2',
          feature: '1512-acceptance-vacuous-composition',
          kind: BehaviorKind.unit,
          description: 'some observable behavior.',
          sourceCriterion: 'FR-2',
          target: 'subject_u2',
        ),
        testPath: testPath,
        subjectPath: subjectPath,
      );
      final content = await File(testPath).readAsString();
      expect(
        content,
        contains('expect(result, isNot(isA<UnimplementedError>()));'),
      );
      expect(
        content,
        isNot(contains(vacuousGuardMarker)),
        reason:
            'the #1308 two-class dispatch keys on the marker being '
            'ABSENT on the unit fallback path — unchanged',
      );
      expect(
        content,
        isNot(contains(acceptanceFallbackGuardToken)),
        reason: 'the acceptance token never leaks into the unit lane',
      );
    });
  });

  test(
    'the emitted acceptance test+subject pair compiles and fails through an '
    'assertion (round-2 review: prove the pair, never only its text)',
    () async {
      final dir = Directory.systemTemp.createTempSync('bug_1512_compile_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final behavior = acceptanceBehavior();
      final testPath = p.join(dir.path, 'a1_test.dart');
      final subjectPath = p.join(dir.path, 'a1_subject.dart');
      await const BehaviorTestWriter().write(
        behavior: behavior,
        testPath: testPath,
        subjectPath: subjectPath,
      );
      await const SubjectWriter().write(
        behavior: behavior,
        subjectPath: subjectPath,
      );
      await File(p.join(dir.path, 'pubspec.yaml')).writeAsString('''
name: bug_1512_compile_pair
environment:
  sdk: ^3.11.0
dependencies:
  test: ^1.25.0
''');
      final result = await Process.run('dart', [
        'test',
        testPath,
      ], workingDirectory: dir.path);
      final combined = '${result.stdout}\n${result.stderr}';
      // The pair must RUN: a compile error never reaches an assertion.
      expect(
        result.exitCode,
        isNot(0),
        reason: 'the stub must be honestly red on first run',
      );
      expect(
        combined.toLowerCase(),
        isNot(contains('compile-time error')),
        reason: combined,
      );
      expect(
        combined.toLowerCase(),
        isNot(contains('undefined name')),
        reason: combined,
      );
      expect(combined, allOf(contains('Expected:'), contains('Actual:')));
    },
    tags: 'slow',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
