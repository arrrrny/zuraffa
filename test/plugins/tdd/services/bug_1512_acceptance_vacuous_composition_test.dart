// Bug #1512 — the acceptance lane is a vacuous composition seam.
//
// Three pins, one per root cause:
//
//   (a) the acceptance capture threads the DECLARED arguments (the shape's
//       arg expressions reach the call site — never a bare empty call);
//   (b) the acceptance assertion checks the DECLARED outcome surface
//       (`isA<T>()` for scalar outcomes; the #1259 vacuous-guard marker seam
//       whenever the assertion set would be the bare guard — never silent);
//   (c) the planner returns a real make surface for acceptance rows
//       (entity pipeline when the row names an entity; the spec-052
//       composition lane otherwise) instead of the default unexpressible.
//
// Content-level assertions (the bug_830/bug_912 convention): the emitted
// artifacts are validated through `write()` / `plan()` into a temp tree.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/generation_planner.dart';
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
  await BehaviorTestWriter(contractShape: shape).write(
    behavior: behavior,
    testPath: testPath,
    subjectPath: subjectPath,
  );
  return File(testPath).readAsString();
}

UnitContractShape shapeOf(String declared) =>
    UnitContractShape.of(Signature.parse(declared));

void main() {
  group('bug #1512 (a): the acceptance capture threads declared args', () {
    test('a declared scalar contract reaches the call site with its args '
        'and returns the result — never the empty-call discard', () async {
      final content = await renderTest(
        acceptanceBehavior(),
        shape: shapeOf('start(String session) -> String'),
      );
      // The declared arg expression (a scalar String literal) must be
      // threaded into the invocation — the vacuous empty call is gone.
      expect(
        content,
        contains("return subject.subject_a1(r'sample');"),
        reason:
            'the acceptance capture must thread the declared args and '
            'return the subject result (the unit lane capture surface), '
            'not `subject.subject_a1(); return null;`',
      );
      expect(
        content,
        isNot(contains('subject.subject_a1();')),
        reason: 'the empty call is the vacuous seam (root cause 1)',
      );
      expect(
        content,
        isNot(contains('return null;')),
        reason: 'the unconditional `return null;` discards the result',
      );
    });

    test('a declared entity-return contract threads args and captures the '
        'result through the renderable degradation (Object?)', () async {
      final content = await renderTest(
        acceptanceBehavior(),
        shape: shapeOf('complete(String session) -> Todo'),
      );
      expect(
        content,
        contains("return subject.subject_a1(r'sample');"),
        reason:
            'the declared return degrades to Object? (renderable, '
            'non-void) — the capture can return the subject result',
      );
    });

    test('a declared VOID return keeps the void-safe capture form but '
        'still threads the declared args', () async {
      final content = await renderTest(
        acceptanceBehavior(),
        shape: shapeOf('start(String session) -> void'),
      );
      // Args threaded…
      expect(
        content,
        contains("subject.subject_a1(r'sample');"),
        reason: 'declared args reach the call site even for void returns',
      );
      // …but the capture stays void-safe: a void expression can never be
      // returned as a value (use_of_void_result — the pair must compile
      // against the void scenario-runner subject).
      expect(content, isNot(contains('return subject.')));
    });
  });

  group('bug #1512 (b): the acceptance assertion checks the declared '
      'outcome surface', () {
    test('a declared scalar outcome asserts isA<T>() and the test is '
        'mechanically non-vacuous', () async {
      final content = await renderTest(
        acceptanceBehavior(),
        shape: shapeOf('start(String session) -> String'),
      );
      expect(
        content,
        contains('expect(result, isA<String>())'),
        reason:
            'the acceptance assertion must sit ON the declared outcome '
            'surface (the #1259 unit-lane shape), not the bare guard',
      );
      expect(
        contentIsVacuousGreen(content),
        isFalse,
        reason: 'an isA<T>() outcome assertion is not the vacuous guard',
      );
    });

    test('a declared entity outcome carries the vacuous-guard marker seam '
        '(the designed hand-delta, never silent vacuity)', () async {
      final content = await renderTest(
        acceptanceBehavior(),
        shape: shapeOf('complete(String session) -> Todo'),
      );
      expect(content, contains(vacuousGuardMarker));
      expect(contentIsVacuousGreen(content), isTrue,
          reason: 'the marker makes the guard-only assertion set refuse');
    });

    test('an UNDECLARED acceptance fallback guard carries the marker seam '
        'too — an empty body can no longer pass silently', () async {
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
        contains(vacuousGuardMarker),
        reason:
            'the undeclared acceptance guard is the vacuous-green class '
            '(an empty subject body passes it) — the artifact must name '
            'the vacuity and the remedy (issue #1512)',
      );
      expect(contentIsVacuousGreen(content), isTrue);
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

    test('a scenario row whose literals name an entity routes to the '
        '#758 entity pipeline (entity create → make → wire → build)', () {
      final plan = planner.plan(
        acceptanceSummary('the Todo item persists across restarts.'),
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

    test('an explicit target wins the entity derivation', () {
      final plan = planner.plan(
        acceptanceSummary(
          'the scenario completes.',
          target: 'Invoice',
        ),
      );
      expect(plan.isExpressible, isTrue);
      expect(plan.steps.first.args, ['entity', 'create', '-n', 'Invoice']);
    });

    test('the honest #758 refusal stays: CRUD prose with no named entity '
        'is still the actionable unexpressible stop', () {
      final plan = planner.plan(
        acceptanceSummary(
          'the repository service persists the scenario.',
        ),
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
      expect(
        plan.unexpressibleReason,
        contains('no generator surface maps'),
      );
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
    });
  });
}
