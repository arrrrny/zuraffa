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
// pull/1516 review round: the mock binding is keyed to the plan's own
// entity (`--entity`), the declared return's class is imported when it
// differs, unsupported scalar returns get real literals, and the fixture
// is rendered by the real `SubjectWriter` (never a hand-copied
// template).
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
//   U-1500m — a declared return entity DIFFERENT from --entity is
//             imported and bound to its OWN mock data when present;
//             `dart analyze` over the wired subject is clean (review
//             findings 1, 2, 5).
//   U-1500n — the declared entity's mock data is absent: falls back to
//             the stub's renderable shape — no dead-end, no crashing
//             cast (review finding 1).
//   U-1500u — a declared return entity that is not a generated entity
//             falls back to the stub's renderable shape (never an
//             undefined class).
//   U-1500o — declared Set<Task> binds to `sampleList.toSet()`.
//   U-1500p — declared Iterable<Task> binds to `sampleList`.
//   U-1500q — declared nullable `List<Task>?` binds too (no null cast).
//   U-1500r — a prose-adjacent header return is rejected by the
//             plausibility gate (description-derived type wins).
//   U-1500s — declared `num`/`DateTime` returns get type-correct
//             literals, never `return null as <T>;`.
//   U-1500t — a malformed declared signature is refused (errors are an
//             API; never a silent prose fallback).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/unit_contract_shape.dart';

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

/// The contract-derived stub the REAL producer emits for
/// [declaredSignature] — `SubjectWriter` rendered through the same
/// [UnitContractShape] gen uses (pull/1516 review finding 5: the fixture
/// must track the producer, never a hand-copied template pinned to
/// today's header format).
String contractStub(
  String id, {
  required String declaredSignature,
  String description = 'the behavior under test',
}) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return SubjectWriter(
    contractShape: UnitContractShape.of(Signature.parse(declaredSignature)),
  ).render(_behaviorFor(id, symbol, description));
}

Behavior _behaviorFor(String id, String symbol, String description) => Behavior(
  id: id,
  feature: '090-tdd-fixture',
  kind: BehaviorKind.unit,
  description: description,
  sourceCriterion: 'FR-007',
  target: symbol,
);

/// The snake_case directory/file name a zfa entity uses for [name].
String snakeName(String name) => name
    .replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (m) => '${m.group(1)}_${m.group(2)}',
    )
    .toLowerCase();

/// The entity file a `zfa entity create -n <Name>` step lays out
/// (entities/<snake>/<snake>.dart). Self-contained (no imports) so a
/// wired subject that imports it can be `dart analyze`d cleanly.
Future<void> seedEntity(TddFixture fx, String name) async {
  final snake = snakeName(name);
  final entity = File(
    '${fx.root.path}/lib/src/domain/entities/$snake/$snake.dart',
  );
  await entity.create(recursive: true);
  await entity.writeAsString('''
/// $name entity
class $name {
  const $name();
}
''');
}

/// The entity file `zfa entity create -n Task` lays out
/// (entities/<snake>/<snake>.dart).
Future<void> seedTaskEntity(TddFixture fx) => seedEntity(fx, 'Task');

/// The mock-data file `zfa mock create --name <Name>` writes
/// (data/mock/<snake>_mock_data.dart: `<Name>MockData.sample<Name>`/
/// `.sampleList`).
Future<void> seedMockData(TddFixture fx, String name) async {
  final snake = snakeName(name);
  final mock = File(
    '${fx.root.path}/lib/src/data/mock/${snake}_mock_data.dart',
  );
  await mock.create(recursive: true);
  await mock.writeAsString('''
// Generated by zfa for: $name
import 'package:tdd_fixture/src/domain/entities/$snake/$snake.dart';

/// Mock data for $name
class ${name}MockData {
  static final List<$name> items = <$name>[];
  static $name get sample$name => items.first;
  static List<$name> get sampleList => items;
  static List<$name> get emptyList => <$name>[];
}
''');
}

/// The mock-data file `zfa mock create --name Task` writes.
Future<void> seedTaskMockData(TddFixture fx) => seedMockData(fx, 'Task');

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
          contractStub('U2', declaredSignature: 'create(String title) -> Task'),
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
          contractStub('U2', declaredSignature: 'create(String title) -> Task'),
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
        contractStub('U3', declaredSignature: 'readAll() -> List<Task>'),
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
          contractStub('U4', declaredSignature: 'find(int id) -> Task?'),
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
        contractStub('U5', declaredSignature: 'label(Task task) -> String'),
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
        contractStub('U6', declaredSignature: 'isDone(Task task) -> bool'),
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
      await File(
        fx.subjectPathOf('U7'),
      ).writeAsString(contractStub('U7', declaredSignature: 'count() -> int'));
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
        contractStub('U2', declaredSignature: 'create(String title) -> Task'),
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
          contractStub('U2', declaredSignature: 'create(String title) -> Task'),
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

    // -----------------------------------------------------------------
    // pull/1516 review fixes.
    // -----------------------------------------------------------------

    /// Seed a declared feature from an explicit Layer Contracts
    /// [contract] block plus one test-list entry per behavior in [rows].
    Future<void> seedContractFeature({
      required String contract,
      required List<({String id, String description, String traces})> rows,
    }) async {
      await fx.seedTestList([
        for (final r in rows)
          (
            id: r.id,
            description: r.description,
            traces: r.traces,
            state: 'PENDING',
            kind: 'unit',
          ),
      ]);
      await Directory(fx.featureDir).create(recursive: true);
      await File(
        p.join(fx.featureDir, 'spec.md'),
      ).writeAsString('# Todo Feature\n\n### Layer Contracts\n\n$contract\n');
    }

    /// `dart analyze <relative>` inside the fixture package.
    Future<ProcessResult> analyze(String relative) => Process.run('dart', [
      'analyze',
      relative,
    ], workingDirectory: fx.root.path);

    test('U-1500m: a declared return entity that differs from --entity is '
        'imported and bound to its OWN mock data when that exists '
        '(findings 1+2) — and the wired subject compiles', () async {
      await seedContractFeature(
        contract:
            '**Domain**:\n'
            '- `OrderStore`: `execute(String title) -> Order`',
        rows: [
          (
            id: 'U2',
            description: 'execute an order with a title',
            traces: 'OrderStore.execute',
          ),
        ],
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'execute an order with a title',
      );
      await File(fx.subjectPathOf('U2')).writeAsString(
        contractStub('U2', declaredSignature: 'execute(String title) -> Order'),
      );
      await seedTaskEntity(fx);
      await seedEntity(fx, 'Order');
      await seedMockData(fx, 'Order');

      final out = await runWire(id: 'U2');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U2')).readAsString();
      // The declared shape is kept, and its own class is imported —
      // Dart imports are not transitive (finding 2).
      expect(subject, contains('Order subject_u2(String title) {'));
      expect(
        subject,
        contains(
          "import 'package:tdd_fixture/src/domain/entities/order/"
          "order.dart';",
        ),
      );
      expect(subject, contains('final Type wiredEntityAnchor = Task;'));
      // Bound to the DECLARED entity's own mock data, never the
      // plan's (Task) — and never a dead-end (finding 1).
      expect(subject, contains('return OrderMockData.sampleOrder;'));
      expect(subject, isNot(contains('TaskMockData')));
      expect(subject, isNot(contains('UnimplementedError')));
      expect(subject, isNot(contains('return null as')));
      final result = await analyze('lib/u2_subject.dart');
      expect(
        result.exitCode,
        0,
        reason: 'dart analyze out: ${result.stdout}${result.stderr}',
      );
    });

    test('U-1500n: a declared return entity whose mock data the plan never '
        'creates falls back to the stub\'s renderable shape — no dead-end, '
        'no crashing cast (finding 1)', () async {
      await seedContractFeature(
        contract:
            '**Domain**:\n'
            '- `OrderStore`: `execute(String title) -> Order`',
        rows: [
          (
            id: 'U2',
            description: 'execute an order with a title',
            traces: 'OrderStore.execute',
          ),
        ],
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'execute an order with a title',
      );
      await File(fx.subjectPathOf('U2')).writeAsString(
        contractStub('U2', declaredSignature: 'execute(String title) -> Order'),
      );
      await seedTaskEntity(fx);
      await seedEntity(fx, 'Order');
      // NO order mock data: the plan's `mock create` runs for the
      // TRACED entity (Task) alone — binding a mock the plan never
      // creates used to hard-stop the pipeline forever.

      final out = await runWire(id: 'U2');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U2')).readAsString();
      // Degraded to the stub's own renderable shape: the declared class
      // is not referenced, so it is not imported (an unused import is
      // itself an analyzer warning).
      expect(subject, contains('Object? subject_u2(String title) {'));
      expect(subject, isNot(contains('Order subject_u2')));
      expect(subject, isNot(contains('entities/order/order.dart')));
      expect(subject, isNot(contains('MockData')));
      expect(subject, isNot(contains('return null as Order')));
      expect(subject, isNot(contains('UnimplementedError')));
      final result = await analyze('lib/u2_subject.dart');
      expect(
        result.exitCode,
        0,
        reason: 'dart analyze out: ${result.stdout}${result.stderr}',
      );
    });

    test('U-1500u: a declared return entity that is not a generated entity '
        'falls back to the stub\'s renderable shape — never an undefined '
        'class', () async {
      await seedContractFeature(
        contract:
            '**Domain**:\n'
            '- `OrderStore`: `execute(String title) -> Order`',
        rows: [
          (
            id: 'U2',
            description: 'execute an order with a title',
            traces: 'OrderStore.execute',
          ),
        ],
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'execute an order with a title',
      );
      await File(fx.subjectPathOf('U2')).writeAsString(
        contractStub('U2', declaredSignature: 'execute(String title) -> Order'),
      );
      await seedTaskEntity(fx);
      // NO order entity file: the declared token cannot be imported.

      final out = await runWire(id: 'U2');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U2')).readAsString();
      expect(subject, contains('Object? subject_u2(String title) {'));
      expect(subject, isNot(contains('Order subject_u2')));
      expect(subject, isNot(contains('entities/order/order.dart')));
      expect(subject, isNot(contains('UnimplementedError')));
      final result = await analyze('lib/u2_subject.dart');
      expect(
        result.exitCode,
        0,
        reason: 'dart analyze out: ${result.stdout}${result.stderr}',
      );
    });

    test('U-1500o: a declared Set<Task> return binds to sampleList.toSet() '
        '(finding 4)', () async {
      await seedContractFeature(
        contract: '**Domain**:\n- `TaskStore`: `readAllSet() -> Set<Task>`',
        rows: [
          (
            id: 'U2',
            description: 'read all the distinct tasks',
            traces: 'TaskStore.readAllSet',
          ),
        ],
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'read all the distinct tasks',
      );
      await File(fx.subjectPathOf('U2')).writeAsString(
        contractStub('U2', declaredSignature: 'readAllSet() -> Set<Task>'),
      );
      await seedTaskEntity(fx);
      await seedTaskMockData(fx);

      final out = await runWire(id: 'U2');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U2')).readAsString();
      expect(subject, contains('Set<Task> subject_u2() {'));
      expect(subject, contains('return TaskMockData.sampleList.toSet();'));
      expect(subject, isNot(contains('return null as')));
    });

    test('U-1500p: a declared Iterable<Task> return binds to sampleList '
        '(finding 4)', () async {
      await seedContractFeature(
        contract:
            '**Domain**:\n'
            '- `TaskStore`: `stream() -> Iterable<Task>`',
        rows: [
          (
            id: 'U2',
            description: 'stream every persisted task',
            traces: 'TaskStore.stream',
          ),
        ],
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'stream every persisted task',
      );
      await File(fx.subjectPathOf('U2')).writeAsString(
        contractStub('U2', declaredSignature: 'stream() -> Iterable<Task>'),
      );
      await seedTaskEntity(fx);
      await seedTaskMockData(fx);

      final out = await runWire(id: 'U2');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U2')).readAsString();
      expect(subject, contains('Iterable<Task> subject_u2() {'));
      expect(subject, contains('return TaskMockData.sampleList;'));
      expect(subject, isNot(contains('return null as')));
    });

    test('U-1500q: a declared nullable collection (List<Task>?) binds too — '
        'no crashing null cast', () async {
      await seedContractFeature(
        contract:
            '**Domain**:\n'
            '- `TaskStore`: `readAllMaybe() -> List<Task>?`',
        rows: [
          (
            id: 'U2',
            description: 'read all the persisted tasks when known',
            traces: 'TaskStore.readAllMaybe',
          ),
        ],
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'read all the persisted tasks when known',
      );
      await File(fx.subjectPathOf('U2')).writeAsString(
        contractStub('U2', declaredSignature: 'readAllMaybe() -> List<Task>?'),
      );
      await seedTaskEntity(fx);
      await seedTaskMockData(fx);

      final out = await runWire(id: 'U2');

      expect(exitCode, 0, reason: 'out: $out');
      final subject = await File(fx.subjectPathOf('U2')).readAsString();
      expect(subject, contains('List<Task>? subject_u2() {'));
      expect(subject, contains('return TaskMockData.sampleList;'));
      expect(subject, isNot(contains('return null as')));
    });

    test(
      'U-1500r: a prose-adjacent header return is rejected by the '
      'plausibility gate — the description-derived type wins (finding 4)',
      () async {
        await fx.registerBehavior(
          id: 'U2',
          description: 'render returns a non-empty string for the task',
        );
        await File(fx.subjectPathOf('U2')).writeAsString(
          contractStub(
            'U2',
            declaredSignature: 'create(String title) -> Whatever works',
          ),
        );
        await seedTaskEntity(fx);

        final out = await runWire(id: 'U2');

        expect(exitCode, 0, reason: 'out: $out');
        final subject = await File(fx.subjectPathOf('U2')).readAsString();
        expect(subject, contains('String subject_u2(String title) {'));
        expect(subject, isNot(contains('Whatever works')));
        expect(subject, isNot(contains('return null as')));
      },
    );

    test('U-1500s: declared `num`/`DateTime` returns get type-correct '
        'literals, never the crashing cast (finding 3)', () async {
      await seedContractFeature(
        contract:
            '**Domain**:\n'
            '- `TaskStore`: `count() -> num`, `now() -> DateTime`',
        rows: [
          (
            id: 'U2',
            description: 'count the persisted tasks',
            traces: 'TaskStore.count',
          ),
          (
            id: 'U3',
            description: 'stamp when the tasks were read',
            traces: 'TaskStore.now',
          ),
        ],
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'count the persisted tasks',
      );
      await fx.registerBehavior(
        id: 'U3',
        description: 'stamp when the tasks were read',
      );
      await File(
        fx.subjectPathOf('U2'),
      ).writeAsString(contractStub('U2', declaredSignature: 'count() -> num'));
      await File(fx.subjectPathOf('U3')).writeAsString(
        contractStub('U3', declaredSignature: 'now() -> DateTime'),
      );
      await seedTaskEntity(fx);

      final out2 = await runWire(id: 'U2');
      expect(exitCode, 0, reason: 'out: $out2');
      final subject2 = await File(fx.subjectPathOf('U2')).readAsString();
      expect(subject2, contains('num subject_u2() {'));
      expect(subject2, contains('return 0;'));
      expect(subject2, isNot(contains('return null as')));

      final out3 = await runWire(id: 'U3');
      expect(exitCode, 0, reason: 'out: $out3');
      final subject3 = await File(fx.subjectPathOf('U3')).readAsString();
      expect(subject3, contains('DateTime subject_u3() {'));
      expect(subject3, contains('return DateTime.now();'));
      expect(subject3, isNot(contains('return null as')));
    });

    test('U-1500t: a malformed declared signature is refused — the '
        'declaration error is an API, never a silent prose fallback '
        '(finding 4)', () async {
      await seedContractFeature(
        contract: '**Function**:\n- `TaskStore`: `execute( -> num`',
        rows: [
          (
            id: 'U2',
            description: 'execute the declared store method',
            traces: 'TaskStore.execute',
          ),
        ],
      );
      await fx.registerBehavior(
        id: 'U2',
        description: 'execute the declared store method',
      );
      await File(fx.subjectPathOf('U2')).writeAsString(
        contractStub('U2', declaredSignature: 'create(String title) -> Task'),
      );
      await seedTaskEntity(fx);

      final out = await runWire(id: 'U2');

      expect(exitCode, isNot(0));
      expect(out, contains('declaration refused'));
      expect(out, contains('malformed signature'));
      expect(out, contains('outcome=runner-error'));
      final subject = await File(fx.subjectPathOf('U2')).readAsString();
      expect(
        subject,
        contains('UnimplementedError'),
        reason: 'a refused declaration never rewrites the subject',
      );
    });
  });
}
