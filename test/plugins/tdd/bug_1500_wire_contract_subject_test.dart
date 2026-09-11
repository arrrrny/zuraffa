// Bug #1500 — `zfa tdd wire` accepts contract-derived subject stubs and
// binds entity returns to the generated MockData.
//
// `zfa tdd wire <id>` could only wire a subject whose stub matches the
// legacy no-arg function stub (`int|void name() => throw
// UnimplementedError(`). Every CONTRACT-DERIVED subject (issue #1259)
// has a different shape — declared parameters + a degraded `Object?`
// return — so wire fell into `stub == null` and refused with
// "unrecognized shape", and the entity create → mock create → wire →
// build pipeline could never complete for a contract-derived behavior.
//
// Even with the shape accepted, `_defaultBodyFor` emitted
// `return null as Task;` — a runtime cast error routed to runner-error —
// while the pipeline had already generated the value one step earlier
// (`zfa mock create --name Task` writes `TaskMockData.sampleTask`).
//
// Remediation pinned here (wire_command.dart only):
//   1. `_stubSignature` accepts what SubjectWriter emits: any return
//      type, any parameter list (single-line stub form — hand-written
//      block bodies and the FFI harness stay refused).
//   2. wire resolves the declared signature and uses the declared
//      return — never the degraded `Object?`.
//   3. Entity returns bind to `<Entity>MockData.sample<Entity>` /
//      `.sampleList` and the mock-data file is imported.
//   4. A missing mock-data file is an honest misfire-stop naming
//      `zfa mock create --name <Entity>`.
//   5. The wired signature keeps the declared parameters.
//   6. Legacy no-arg stubs keep wiring byte-compatibly.
//
// Test map:
//   U-1500a — contract-derived stub, entity return: wired to the
//             declared type + TaskMockData.sampleTask + both imports.
//   U-1500b — missing mock-data file: honest misfire-stop naming
//             `zfa mock create --name Task`; subject untouched.
//   U-1500c — declared List<Task> return binds to sampleList.
//   U-1500d — declared Task? return binds to sampleTask.
//   U-1500e — declared String return: type-correct literal, no mock.
//   U-1500f — declared bool return: `return false;`, no mock.
//   U-1500g — declared int return: `return 0;`, no mock (legacy-safe).
//   U-1500h — legacy no-arg int/void stubs wire byte-compatibly.
//   U-1500i — a commented-out stub line is not a stub (already-wired).
//   U-1500j — a hand-written non-stub UnimplementedError shape is still
//             refused (the widened regex stays safe).
//   U-1500k — the stub's provenance header resolves the declared return
//             when the spec artifacts are absent (header fallback).
//   U-1500l — the declared return wins over description inference.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// The spec the issue's repro declares (001-todo-app): a Domain-layer
/// store whose methods carry scalar params, entity returns, generic
/// returns and nullable returns.
const todoStoreSpec = '''
# Todo Feature

### Layer Contracts

**Domain**:
- `TaskStore`: `create(String title) -> Task`, `readAll() -> List<Task>`, `find(int id) -> Task?`, `label(Task task) -> String`, `isDone(Task task) -> bool`, `count() -> int`
''';

/// The contract-derived stub SubjectWriter emits for [signature] with a
/// [renderedReturn]/[renderedParams] pair (issue #1259 degradation):
/// non-renderable declared types render as `Object?`, the declared
/// signature survives in the provenance header.
String contractStub(
  String id, {
  required String declaredSignature,
  required String renderedReturn,
  required String renderedParams,
}) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
// GENERATED STUB — `zfa tdd gen $id` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// behavior_id: $id
// source_criterion: FR-007
// description: the behavior under test
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
// derived from the spec's declared Layer Contract:
//
//     $declaredSignature
//
// The declared request and result types are preserved above. A
// non-renderable declared type (an entity that does not exist yet)
// renders as `Object?` so the stub compiles cleanly (FR-011); replace
// it with the declared type when implementing.
//
// The subject name is derived from the behavior id and is deliberately
// snake_cased — the generator KNOWS the name it emits, so the lint its
// shape provably trips is suppressed here rather than renaming the
// contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

/// Subject for behavior $id — declared contract:
/// `$declaredSignature`.
///
/// Throws [UnimplementedError] until the real implementation lands.
$renderedReturn $symbol($renderedParams) => throw UnimplementedError('$symbol not implemented: $declaredSignature');
''';
}

/// The entity file `zfa entity create -n Task` lays out
/// (entities/<snake>/<snake>.dart).
Future<void> seedTaskEntity(TddFixture fx) async {
  final entity = File('${fx.root.path}/lib/src/domain/entities/task/task.dart');
  await entity.create(recursive: true);
  await entity.writeAsString('''
// Auto-generated by Zorphy
import 'package:zorphy_annotation/zorphy_annotation.dart';

part 'task.zorphy.dart';

/// Task entity
@Zorphy(generateJson: true)
abstract class \$Task {}
''');
}

/// The mock-data file `zfa mock create --name Task` writes
/// (data/mock/task_mock_data.dart: `TaskMockData.sampleTask`/
/// `.sampleList`).
Future<void> seedTaskMockData(TddFixture fx) async {
  final mock = File('${fx.root.path}/lib/src/data/mock/task_mock_data.dart');
  await mock.create(recursive: true);
  await mock.writeAsString('''
// Generated by zfa for: Task
import 'package:tdd_fixture/src/domain/entities/task/task.dart';

/// Mock data for Task
class TaskMockData {
  static final List<Task> tasks = <Task>[];
  static Task get sampleTask => tasks.first;
  static List<Task> get sampleList => tasks;
  static List<Task> get emptyList => <Task>[];
}
''');
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
    // The subject files live under lib/ — same provision the entity
    // seeding in wire_command_test's setUp achieves implicitly.
    await Directory('${fx.root.path}/lib').create(recursive: true);
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  Future<String> runWire({required String id, String entity = 'Task'}) {
    final runner = CliRunner(exitOnCompletion: false);
    return runner.runCapturing([
      'tdd',
      'wire',
      id,
      '--project',
      fx.root.path,
      '--entity',
      entity,
    ]);
  }

  /// Seed the declared todo-store feature (spec + test-list traces).
  Future<void> seedDeclaredFeature() async {
    await fx.seedTestList([
      (
        id: 'U2',
        description: 'create a task with a title',
        traces: 'TaskStore.create',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U3',
        description: 'read all the persisted tasks',
        traces: 'TaskStore.readAll',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U4',
        description: 'find a task by its id',
        traces: 'TaskStore.find',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U5',
        description: 'label the task for display',
        traces: 'TaskStore.label',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U6',
        description: 'report whether the task is done',
        traces: 'TaskStore.isDone',
        state: 'PENDING',
        kind: 'unit',
      ),
      (
        id: 'U7',
        description: 'count the persisted tasks',
        traces: 'TaskStore.count',
        state: 'PENDING',
        kind: 'unit',
      ),
    ]);
    await Directory(fx.featureDir).create(recursive: true);
    await File(p.join(fx.featureDir, 'spec.md')).writeAsString(todoStoreSpec);
  }

  group('bug 1500: wire accepts contract-derived stubs', () {
    test(
      'U-1500a: a contract-derived stub with a declared entity return '
      'wires to the declared type + MockData sample, params preserved',
      () async {
        await seedDeclaredFeature();
        await fx.registerBehavior(
          id: 'U2',
          description: 'create a task with a title',
        );
        await File(fx.subjectPathOf('U2')).writeAsString(
          contractStub(
            'U2',
            declaredSignature: 'create(String title) -> Task',
            renderedReturn: 'Object?',
            renderedParams: 'String title',
          ),
        );
        await seedTaskEntity(fx);
        await seedTaskMockData(fx);

        final out = await runWire(id: 'U2');

        expect(exitCode, 0, reason: 'out: $out');
        expect(
          out,
          contains('wire: behavior=U2 outcome=wired feature=${fx.featureName}'),
        );
        final subject = await File(fx.subjectPathOf('U2')).readAsString();
        expect(subject, isNot(contains('UnimplementedError')));
        // The DECLARED return — never the degraded `Object?`.
        expect(subject, contains('Task subject_u2(String title) {'));
        expect(subject, isNot(contains('Object? subject_u2')));
        // The declared parameters survive the rewrite.
        expect(subject, isNot(contains('subject_u2() {')));
        // The entity anchor + the MockData binding with its import.
        expect(subject, contains('final Type wiredEntityAnchor = Task;'));
        expect(subject, contains('return TaskMockData.sampleTask;'));
        expect(
          subject,
          contains(
            "import 'package:tdd_fixture/src/data/mock/task_mock_data.dart';",
          ),
        );
        expect(subject, contains('entities/task/task.dart'));
        // No runtime cast error body.
        expect(subject, isNot(contains('return null as')));
      },
    );

    test(
      'U-1500b: a missing mock-data file is an honest misfire-stop '
      'naming `zfa mock create --name Task` — the subject is untouched',
      () async {
        await seedDeclaredFeature();
        await fx.registerBehavior(
          id: 'U2',
          description: 'create a task with a title',
        );
        await File(fx.subjectPathOf('U2')).writeAsString(
          contractStub(
            'U2',
            declaredSignature: 'create(String title) -> Task',
            renderedReturn: 'Object?',
            renderedParams: 'String title',
          ),
        );
        await seedTaskEntity(fx);
        // NO mock data file — the pipeline step was skipped.

        final out = await runWire(id: 'U2');

        expect(exitCode, isNot(0));
        expect(out, contains('mock data for entity "Task"'));
        expect(out, contains('zfa mock create --name Task'));
        expect(
          out,
          contains(
            'wire: behavior=U2 outcome=runner-error '
            'feature=${fx.featureName}',
          ),
        );
        final subject = await File(fx.subjectPathOf('U2')).readAsString();
        expect(
          subject,
          contains('UnimplementedError'),
          reason: 'a misfired wire never rewrites the subject',
        );
      },
    );

    test('U-1500c: a declared List<Task> return binds to sampleList', () async {
      await seedDeclaredFeature();
      await fx.registerBehavior(
        id: 'U3',
        description: 'read all the persisted tasks',
      );
      await File(fx.subjectPathOf('U3')).writeAsString(
        contractStub(
          'U3',
          declaredSignature: 'readAll() -> List<Task>',
          renderedReturn: 'Object?',
          renderedParams: '',
        ),
      );
      await seedTaskEntity(fx);
      await seedTaskMockData(fx);

      final out = await runWire(id: 'U3');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U3')).readAsString();
      expect(subject, contains('List<Task> subject_u3() {'));
      expect(subject, contains('return TaskMockData.sampleList;'));
      expect(
        subject,
        contains(
          "import 'package:tdd_fixture/src/data/mock/task_mock_data.dart';",
        ),
      );
      expect(subject, isNot(contains('return null as')));
    });

    test(
      'U-1500d: a declared nullable Task? return binds to sampleTask',
      () async {
        await seedDeclaredFeature();
        await fx.registerBehavior(
          id: 'U4',
          description: 'find a task by its id',
        );
        await File(fx.subjectPathOf('U4')).writeAsString(
          contractStub(
            'U4',
            declaredSignature: 'find(int id) -> Task?',
            renderedReturn: 'Object?',
            renderedParams: 'int id',
          ),
        );
        await seedTaskEntity(fx);
        await seedTaskMockData(fx);

        final out = await runWire(id: 'U4');

        expect(exitCode, 0, reason: 'out: $out');
        final subject = await File(fx.subjectPathOf('U4')).readAsString();
        expect(subject, contains('Task? subject_u4(int id) {'));
        expect(subject, contains('return TaskMockData.sampleTask;'));
        expect(subject, isNot(contains('return null as')));
      },
    );

    test('U-1500e: a declared String return keeps a type-correct literal '
        '— no mock data needed', () async {
      await seedDeclaredFeature();
      await fx.registerBehavior(
        id: 'U5',
        description: 'label the task for display',
      );
      await File(fx.subjectPathOf('U5')).writeAsString(
        contractStub(
          'U5',
          declaredSignature: 'label(Task task) -> String',
          renderedReturn: 'String',
          renderedParams: 'Object? task',
        ),
      );
      await seedTaskEntity(fx);

      final out = await runWire(id: 'U5');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U5')).readAsString();
      expect(subject, contains('String subject_u5(Object? task) {'));
      expect(subject, contains("return 'subject_u5';"));
      expect(subject, isNot(contains('MockData')));
      expect(subject, isNot(contains('return null as')));
    });

    test('U-1500f: a declared bool return keeps `return false;` — no mock '
        'data needed', () async {
      await seedDeclaredFeature();
      await fx.registerBehavior(
        id: 'U6',
        description: 'report whether the task is done',
      );
      await File(fx.subjectPathOf('U6')).writeAsString(
        contractStub(
          'U6',
          declaredSignature: 'isDone(Task task) -> bool',
          renderedReturn: 'bool',
          renderedParams: 'Object? task',
        ),
      );
      await seedTaskEntity(fx);

      final out = await runWire(id: 'U6');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U6')).readAsString();
      expect(subject, contains('bool subject_u6(Object? task) {'));
      expect(subject, contains('return false;'));
      expect(subject, isNot(contains('MockData')));
    });

    test('U-1500g: a declared int return keeps `return 0;` — no mock data '
        'needed', () async {
      await seedDeclaredFeature();
      await fx.registerBehavior(
        id: 'U7',
        description: 'count the persisted tasks',
      );
      await File(fx.subjectPathOf('U7')).writeAsString(
        contractStub(
          'U7',
          declaredSignature: 'count() -> int',
          renderedReturn: 'int',
          renderedParams: '',
        ),
      );
      await seedTaskEntity(fx);

      final out = await runWire(id: 'U7');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U7')).readAsString();
      expect(subject, contains('int subject_u7() {'));
      expect(subject, contains('return 0;'));
      expect(subject, isNot(contains('MockData')));
    });

    test('U-1500h: legacy no-arg int/void stubs keep wiring '
        'byte-compatibly (backwards compatible)', () async {
      // No declared test-list rows for B-001/B-002 — the legacy path.
      await fx.registerBehavior(
        id: 'B-001',
        description: 'create entity User with email',
      );
      await fx.registerBehavior(
        id: 'B-002',
        description: 'create entity User with email',
      );
      await File(fx.subjectPathOf('B-001')).writeAsString('''
// GENERATED STUB — `zfa tdd gen B-001` (spec 044-test-tdd-generation).
library;

/// Subject for behavior B-001.
int subject_b_001() => throw UnimplementedError('subject_b_001 not implemented');
''');
      await File(fx.subjectPathOf('B-002')).writeAsString('''
// GENERATED STUB — `zfa tdd gen B-002` (spec 044-test-tdd-generation).
library;

/// Scenario runner for behavior B-002.
void subject_b_002() => throw UnimplementedError('subject_b_002 not implemented');
''');
      final user = File(
        '${fx.root.path}/lib/src/domain/entities/user/user.dart',
      );
      await user.create(recursive: true);
      await user.writeAsString('''
// Auto-generated by Zorphy
abstract class \$User {}
''');

      final out1 = await runWire(id: 'B-001', entity: 'User');
      expect(exitCode, 0, reason: 'out: $out1');
      final subject1 = await File(fx.subjectPathOf('B-001')).readAsString();
      expect(subject1, contains('int subject_b_001() {'));
      expect(subject1, contains('return 0;'));
      expect(subject1, contains('final Type wiredEntityAnchor = User;'));

      final out2 = await runWire(id: 'B-002', entity: 'User');
      expect(exitCode, 0, reason: 'out: $out2');
      final subject2 = await File(fx.subjectPathOf('B-002')).readAsString();
      expect(subject2, contains('void subject_b_002() {'));
      expect(subject2, contains('final Type wiredEntityAnchor = User;'));
    });

    test('U-1500i: a commented-out stub line is not a stub — '
        'already-wired survives the widened shape', () async {
      await fx.registerBehavior(
        id: 'B-003',
        description: 'create entity User with email',
      );
      final user = File(
        '${fx.root.path}/lib/src/domain/entities/user/user.dart',
      );
      await user.create(recursive: true);
      await user.writeAsString(
        '// Auto-generated by Zorphy\nabstract class \$User {}\n',
      );
      await File(fx.subjectPathOf('B-003')).writeAsString('''
library;

// Object? subject_b_003(String title) => throw UnimplementedError('x');

int already_done() => 7;
''');

      final out = await runWire(id: 'B-003', entity: 'User');

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=already-wired'));
      final subject = await File(fx.subjectPathOf('B-003')).readAsString();
      expect(subject, contains('int already_done() => 7;'));
    });

    test('U-1500j: a hand-written non-stub UnimplementedError shape is '
        'STILL refused — the widened regex stays safe', () async {
      await fx.registerBehavior(
        id: 'B-004',
        description: 'create entity User with email',
      );
      final user = File(
        '${fx.root.path}/lib/src/domain/entities/user/user.dart',
      );
      await user.create(recursive: true);
      await user.writeAsString(
        '// Auto-generated by Zorphy\nabstract class \$User {}\n',
      );
      await File(fx.subjectPathOf('B-004')).writeAsString('''
library;

class Weird {
  void run() {
    throw UnimplementedError('hand-written shape');
  }
}
''');

      final out = await runWire(id: 'B-004', entity: 'User');

      expect(exitCode, isNot(0));
      expect(out, contains('unrecognized shape'));
      final subject = await File(fx.subjectPathOf('B-004')).readAsString();
      expect(subject, contains('class Weird'));
    });

    test('U-1500k: the stub provenance header resolves the declared '
        'return when the spec artifacts are absent', () async {
      // NO seedDeclaredFeature — declared routing finds no test-list,
      // so the stub's own provenance header is the declared-shape
      // source (the SubjectWriter contract stub carries it).
      await fx.registerBehavior(
        id: 'U2',
        description: 'create a task with a title',
      );
      await File(fx.subjectPathOf('U2')).writeAsString(
        contractStub(
          'U2',
          declaredSignature: 'create(String title) -> Task',
          renderedReturn: 'Object?',
          renderedParams: 'String title',
        ),
      );
      await seedTaskEntity(fx);
      await seedTaskMockData(fx);

      final out = await runWire(id: 'U2');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U2')).readAsString();
      expect(subject, contains('Task subject_u2(String title) {'));
      expect(subject, contains('return TaskMockData.sampleTask;'));
      expect(subject, isNot(contains('Object? subject_u2')));
    });

    test(
      'U-1500l: the declared return wins over description inference',
      () async {
        await seedDeclaredFeature();
        // The description alone would infer String (`render`/`string`
        // phrases, the U-920 path) — the declared contract says Task.
        await fx.registerBehavior(
          id: 'U2',
          description: 'render returns a non-empty string for the task',
        );
        await File(fx.subjectPathOf('U2')).writeAsString(
          contractStub(
            'U2',
            declaredSignature: 'create(String title) -> Task',
            renderedReturn: 'Object?',
            renderedParams: 'String title',
          ),
        );
        await seedTaskEntity(fx);
        await seedTaskMockData(fx);

        final out = await runWire(id: 'U2');

        expect(exitCode, 0, reason: 'out: $out');
        final subject = await File(fx.subjectPathOf('U2')).readAsString();
        expect(subject, contains('Task subject_u2(String title) {'));
        expect(subject, isNot(contains('String subject_u2(')));
        expect(subject, contains('return TaskMockData.sampleTask;'));
      },
    );
  });
}
