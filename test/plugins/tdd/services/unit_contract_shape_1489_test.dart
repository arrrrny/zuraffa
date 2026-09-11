// SPEC 1489 — entity-return renderability (fast tier).
//
// Every entity-returning Layer Contract degraded to `Object?` in the
// generated subject — permanently. `isRenderableDartType` was a pure
// scalar predicate with no filesystem access, so an entity type never
// became renderable even where phase-0 had already created the entity
// before gen spawned. The remediation gives the predicate (and its
// caller, `UnitContractShape.of`) an OPTIONAL entity registry: when the
// entity exists on disk (`locateEntityFile`), the declared type renders
// verbatim, the subject carries the entity's import, `scalarOutcome`
// treats the entity return as a mechanically assertable outcome, and the
// plan/driver surface the remaining hand-step seam cost. Missing
// entities still degrade to `Object?` — byte-for-byte the legacy shapes.
//
// Test map (specs/1489-entity-return-renderability/spec.md):
//   SC-1 — the predicate + shape render the declared type when the
//          entity exists (single, `List<E>`, `E?`, `Map<K, E>`).
//   SC-2 — the generated subject carries the entity import (directly
//          implementable stub) and the paired test imports exactly the
//          return entity when its assertion references the type.
//   SC-3 — `scalarOutcome` reflects corrected renderability: existing
//          entity-returns leave the hand-step seam.
//   SC-4 — the seam-cost line: exact "N of M unit behaviors will
//          hand-step because return is an entity" wording.
//   SC-5 — missing entities still degrade to `Object?`; no registry ==
//          legacy behavior byte-for-byte.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/unit_contract_shape.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

/// Runs [body] and returns everything printed (via [ZoneSpecification.print])
/// as a single newline-joined string.
Future<String> capturePrint(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

Behavior unitBehavior(String id, String target) => Behavior(
  id: id,
  feature: '1489-entity-return-renderability',
  kind: BehaviorKind.unit,
  description: 'creates the declared entity from the title',
  sourceCriterion: 'FR-001',
  target: target,
);

/// The registry used across the unit groups: only `Task` exists.
bool taskExists(String entityName) => entityName == 'Task';

/// The entity file map matching [taskExists] (lib-relative paths — what
/// `ofResolved` derives from `locateEntityFile`).
const Map<String, String> taskFiles = {
  'Task': 'src/domain/entities/task/task.dart',
};

void main() {
  group('1489 SC-1: isRenderableDartType gains the entity registry', () {
    test('an existing entity renders — single, generic, nullable, map', () {
      expect(isRenderableDartType('Task', entityExists: taskExists), isTrue);
      expect(isRenderableDartType('Task?', entityExists: taskExists), isTrue);
      expect(
        isRenderableDartType('List<Task>', entityExists: taskExists),
        isTrue,
      );
      expect(
        isRenderableDartType('Set<Task>', entityExists: taskExists),
        isTrue,
      );
      expect(
        isRenderableDartType('Iterable<Task>', entityExists: taskExists),
        isTrue,
      );
      expect(
        isRenderableDartType('Map<String, Task>', entityExists: taskExists),
        isTrue,
      );
    });

    test('a missing entity still degrades (SC-5)', () {
      expect(isRenderableDartType('Ghost', entityExists: taskExists), isFalse);
      expect(isRenderableDartType('Ghost?', entityExists: taskExists), isFalse);
      expect(
        isRenderableDartType('List<Ghost>', entityExists: taskExists),
        isFalse,
      );
      expect(
        isRenderableDartType('Map<String, Ghost>', entityExists: taskExists),
        isFalse,
      );
    });

    test('no predicate keeps the legacy predicate byte-for-byte (SC-5)', () {
      expect(isRenderableDartType('Task'), isFalse);
      expect(isRenderableDartType('List<Task>'), isFalse);
      expect(isRenderableDartType('String'), isTrue);
      expect(isRenderableDartType('String?'), isTrue);
      expect(isRenderableDartType('List<String>'), isTrue);
      expect(isRenderableDartType('Map<String, int>'), isTrue);
      expect(isRenderableDartType('void'), isTrue);
      expect(isRenderableDartType('dynamic'), isTrue);
    });
  });

  group('1489 SC-1/SC-3: UnitContractShape.of reflects the registry', () {
    const createTask = Signature(
      name: 'create',
      parameters: ['String title'],
      returnType: 'Task',
    );

    test('an existing entity return renders the declared type', () {
      final shape = UnitContractShape.of(
        createTask,
        entityExists: taskExists,
        entityFiles: taskFiles,
        packageName: 'fixture_app',
      );
      expect(shape.declaredReturn, 'Task');
      expect(shape.returnType, 'Task');
      expect(shape.entityReturn, isTrue);
      // SC-3: the entity return is a mechanically assertable outcome —
      // the paired test emits `isA<Task>()`, not the vacuous guard.
      expect(shape.scalarOutcome, isTrue);
    });

    test('a missing entity return still degrades to Object? (SC-5)', () {
      final shape = UnitContractShape.of(
        createTask,
        entityExists: taskExists,
        entityFiles: taskFiles,
        packageName: 'fixture_app',
      );
      final ghost = const Signature(
        name: 'create',
        parameters: ['String title'],
        returnType: 'Ghost',
      );
      final ghostShape = UnitContractShape.of(
        ghost,
        entityExists: taskExists,
        entityFiles: taskFiles,
        packageName: 'fixture_app',
      );
      expect(ghostShape.returnType, 'Object?');
      expect(ghostShape.entityReturn, isFalse);
      expect(ghostShape.scalarOutcome, isFalse);
      expect(ghostShape.entityImports, isEmpty);
      // The existing-entity shape is unaffected by the ghost's.
      expect(shape.returnType, 'Task');
    });

    test('no registry keeps the legacy shape byte-for-byte (SC-5)', () {
      final shape = UnitContractShape.of(createTask);
      expect(shape.returnType, 'Object?');
      expect(shape.entityReturn, isFalse);
      expect(shape.scalarOutcome, isFalse);
      expect(shape.entityImports, isEmpty);
    });

    test('scalar/void/dynamic returns keep their legacy scalarOutcome', () {
      for (final entry in {
        'bool': true,
        'String': true,
        'int': true,
        'double': true,
        'num': true,
        'void': false,
        'dynamic': false,
        'Object': false,
        'Never': false,
      }.entries) {
        final shape = UnitContractShape.of(
          Signature(name: 'f', parameters: const [], returnType: entry.key),
          entityExists: taskExists,
          entityFiles: taskFiles,
          packageName: 'fixture_app',
        );
        expect(
          shape.scalarOutcome,
          entry.value,
          reason: '${entry.key} scalarOutcome',
        );
        expect(
          shape.entityReturn,
          isFalse,
          reason: '${entry.key} entityReturn',
        );
      }
    });

    test('entity params render verbatim and carry their import (SC-1)', () {
      final shape = UnitContractShape.of(
        const Signature(
          name: 'save',
          parameters: ['Task task', 'String title'],
          returnType: 'bool',
        ),
        entityExists: taskExists,
        entityFiles: taskFiles,
        packageName: 'fixture_app',
      );
      expect(shape.params.first.type, 'Task');
      expect(shape.params.first.declaredType, 'Task');
      expect(shape.params[1].type, 'String');
      expect(
        shape.entityImports,
        contains('package:fixture_app/src/domain/entities/task/task.dart'),
      );
      // A bool return keeps the scalar path; the import list exists for
      // the param's entity only.
      expect(shape.returnEntityImports, isEmpty);
      expect(shape.scalarOutcome, isTrue);
    });

    test('nullable and generic entity returns carry the import too', () {
      for (final ret in const ['Task?', 'List<Task>', 'Map<String, Task>']) {
        final shape = UnitContractShape.of(
          Signature(name: 'f', parameters: const [], returnType: ret),
          entityExists: taskExists,
          entityFiles: taskFiles,
          packageName: 'fixture_app',
        );
        expect(shape.returnType, ret, reason: ret);
        expect(shape.returnEntityImports, [
          'package:fixture_app/src/domain/entities/task/task.dart',
        ], reason: ret);
        expect(shape.scalarOutcome, isTrue, reason: ret);
      }
    });
  });

  group('1489 SC-1: UnitContractShape.ofResolved resolves the registry', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('spec_1489_resolved_');
      File(
        p.join(tmp.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: fixture_app\n');
      final taskFile = File(
        p.join(
          tmp.path,
          'lib',
          'src',
          'domain',
          'entities',
          'task',
          'task.dart',
        ),
      );
      taskFile.createSync(recursive: true);
      taskFile.writeAsStringSync('class Task {}\n');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('an entity created by phase-0 renders the declared type', () async {
      final shape = await UnitContractShape.ofResolved(
        const Signature(
          name: 'create',
          parameters: ['String title'],
          returnType: 'Task',
        ),
        cwd: tmp.path,
      );
      // SC-1: Task subject_u1(...) — NOT Object?.
      expect(shape.returnType, 'Task');
      expect(shape.scalarOutcome, isTrue);
      // SC-2: the baked import is the package URI of the resolved file.
      expect(shape.returnEntityImports, [
        'package:fixture_app/src/domain/entities/task/task.dart',
      ]);
      expect(shape.entityImports, [
        'package:fixture_app/src/domain/entities/task/task.dart',
      ]);
    });

    test('an unresolved entity still degrades to Object? (SC-5)', () async {
      final shape = await UnitContractShape.ofResolved(
        const Signature(
          name: 'login',
          parameters: ['AuthRequest request'],
          returnType: 'User',
        ),
        cwd: tmp.path,
      );
      expect(shape.returnType, 'Object?');
      expect(shape.params.single.type, 'Object?');
      expect(shape.params.single.declaredType, 'AuthRequest');
      expect(shape.scalarOutcome, isFalse);
      expect(shape.entityImports, isEmpty);
    });

    test(
      'the resolved seam counter counts only the missing entities',
      () async {
        final seams = await UnitContractShape.countEntityReturnSeamsResolved(
          declared: const [
            Signature(name: 'a', parameters: [], returnType: 'Task'), // exists
            Signature(name: 'b', parameters: [], returnType: 'User'), // missing
            Signature(name: 'c', parameters: [], returnType: 'bool'), // scalar
            null, // undeclared
          ],
          cwd: tmp.path,
        );
        expect(seams, 1);
      },
    );
  });

  group('1489 SC-2: the generated subject is directly implementable', () {
    test('existing entity: declared type + entity import in the subject', () {
      final shape = UnitContractShape.of(
        const Signature(
          name: 'create',
          parameters: ['String title'],
          returnType: 'Task',
        ),
        entityExists: taskExists,
        entityFiles: taskFiles,
        packageName: 'fixture_app',
      );
      final content = SubjectWriter(
        contractShape: shape,
      ).render(unitBehavior('U1', 'subject_u1'));
      // The declared signature, verbatim — no Object? degradation.
      expect(content, contains('Task subject_u1(String title) =>'));
      // SC-2: the entity's import rides the stub.
      expect(
        content,
        contains(
          "import 'package:fixture_app/src/domain/entities/task/task.dart';",
        ),
      );
      // The header no longer tells the author to replace the type.
      expect(content, isNot(contains('replace it with the declared type')));
    });

    test('missing entity: Object? subject with no entity imports (SC-5)', () {
      final shape = UnitContractShape.of(
        const Signature(
          name: 'create',
          parameters: ['String title'],
          returnType: 'Ghost',
        ),
        entityExists: taskExists,
        entityFiles: taskFiles,
        packageName: 'fixture_app',
      );
      final content = SubjectWriter(
        contractShape: shape,
      ).render(unitBehavior('U1', 'subject_u1'));
      expect(content, contains('Object? subject_u1(String title) =>'));
      // No entity import for the degraded type.
      expect(content.contains("import '"), isFalse);
      // The conditional-degradation wording: unconditional ONLY for
      // entities that do not exist yet.
      expect(content, contains('does not exist yet'));
    });

    test('no registry: the legacy subject is byte-identical (SC-5)', () {
      final legacyShape = UnitContractShape.of(
        const Signature(
          name: 'create',
          parameters: ['String title'],
          returnType: 'Task',
        ),
      );
      final content = SubjectWriter(
        contractShape: legacyShape,
      ).render(unitBehavior('U1', 'subject_u1'));
      expect(content, contains('Object? subject_u1(String title) =>'));
      expect(content, isNot(contains("import 'package:fixture_app/")));
    });
  });

  group('1489 SC-2/SC-3: the paired test asserts the declared outcome', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('spec_1489_test_writer_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('existing entity: isA<Task>() + the return-entity import', () async {
      final shape = UnitContractShape.of(
        const Signature(
          name: 'create',
          parameters: ['String title'],
          returnType: 'Task',
        ),
        entityExists: taskExists,
        entityFiles: taskFiles,
        packageName: 'fixture_app',
      );
      final testPath = p.join(tmp.path, 'u1_test.dart');
      await BehaviorTestWriter(contractShape: shape).write(
        behavior: unitBehavior('U1', 'subject_u1'),
        testPath: testPath,
        subjectPath: p.join(tmp.path, 'u1_subject.dart'),
      );
      final content = File(testPath).readAsStringSync();
      // SC-3: a real outcome assertion on the declared type — the
      // behavior does NOT route to the hand-step seam.
      expect(content, contains('expect(result, isA<Task>());'));
      expect(contentCarriesVacuousGuardMarker(content), isFalse);
      // SC-2: the test imports exactly the return entity (never the
      // param entities — the _argN() placeholders own those).
      expect(
        content,
        contains(
          "import 'package:fixture_app/src/domain/entities/task/task.dart';",
        ),
      );
    });

    test(
      'missing entity: the vacuous-guard seam is unchanged (SC-5)',
      () async {
        final shape = UnitContractShape.of(
          const Signature(
            name: 'create',
            parameters: ['String title'],
            returnType: 'Ghost',
          ),
          entityExists: taskExists,
          entityFiles: taskFiles,
          packageName: 'fixture_app',
        );
        final testPath = p.join(tmp.path, 'u1_test.dart');
        await BehaviorTestWriter(contractShape: shape).write(
          behavior: unitBehavior('U1', 'subject_u1'),
          testPath: testPath,
          subjectPath: p.join(tmp.path, 'u1_subject.dart'),
        );
        final content = File(testPath).readAsStringSync();
        expect(
          content,
          contains('expect(result, isNot(isA<UnimplementedError>()));'),
        );
        expect(contentCarriesVacuousGuardMarker(content), isTrue);
        expect(content, isNot(contains('isA<Ghost>')));
      },
    );
  });

  group('1489 SC-4: the seam-cost forecast', () {
    test('counts entity returns that still hand-step (missing entities)', () {
      final seams = UnitContractShape.countEntityReturnSeams(
        declaredReturns: const [
          'Task', // entity, exists → no seam
          'Ghost', // entity, missing → seam
          'List<Task>', // generic entity, exists → no seam
          'List<Ghost>', // generic entity, missing → seam
          'bool', // scalar → never a seam
          'String',
          'void', // not an entity → never counted
          'dynamic',
          'Object',
          null, // undeclared behavior → not counted
        ],
        entityExists: taskExists,
      );
      expect(seams, 2);
    });

    test('without a registry the entity returns all still hand-step', () {
      final seams = UnitContractShape.countEntityReturnSeams(
        declaredReturns: const ['Task', 'bool', null],
        entityExists: null,
      );
      expect(seams, 1);
    });

    test('the surfaced line carries the exact wording (SC-4)', () {
      expect(
        UnitContractShape.entityReturnSeamCostLine(seams: 3, total: 21),
        'Seam cost: 3 of 21 unit behaviors will hand-step because return '
        'is an entity.',
      );
      // Zero seams: nothing is surfaced (no line).
      expect(
        UnitContractShape.entityReturnSeamCostLine(seams: 0, total: 21),
        isNull,
      );
    });
  });
}
