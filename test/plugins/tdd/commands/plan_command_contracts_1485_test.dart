// Issue #1485 — `zfa tdd plan` reads `specs/<feature>/contracts/*.md` as
// a declared-row source. Plan reports what it read (per-file declared-row
// counts), binds contract-file traces declared (no fallback routing),
// warns about a contracts/ directory that yields nothing, and stays
// byte-identical for features with no contracts/ directory.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

const feature = '1485-todo';

const specMd = '''
# Spec: todo

**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** a stored task, **When** the app launches, **Then** the task list renders in file order

## Functional Requirements

- **FR-001**: The system shall load stored tasks from the task store at launch.
  traces: task-store.Create
- **FR-002**: The system shall add a submitted task to the store.
''';

const taskStoreMd = '''
# Contract: TaskStore

| Operation | Input                   | Behaviour                   |
|-----------|-------------------------|-----------------------------|
| Read all  | —                       | Returns tasks in file order |
| Create    | a Task + placeholder id | Assigns fresh id, appends   |
| Update    | a Task                  | Replaces the stored task    |
| Delete    | an id                   | Removes the task            |
''';

const dataLayerMd = '''
# Contract: data layer

## Methods

- `loadAll() -> List<Task>`
- `persist(Task) -> void`
- `wipe() -> void`
''';

void main() {
  late Directory tmpDir;

  setUp(() => tmpDir = Directory.systemTemp.createTempSync('plan_1485_'));

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<String> plan() async {
    final out = await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'plan', '--project', tmpDir.path, feature]);
    return out;
  }

  void seedFeature({Directory? contracts}) {
    final dir = Directory(p.join(tmpDir.path, 'specs', feature));
    dir.createSync(recursive: true);
    File(p.join(dir.path, 'spec.md')).writeAsStringSync(specMd);
    if (contracts != null) contracts.createSync(recursive: true);
  }

  void seedContracts(Map<String, String> files) {
    final contracts = Directory(
      p.join(tmpDir.path, 'specs', feature, 'contracts'),
    );
    contracts.createSync(recursive: true);
    files.forEach((name, md) {
      File(p.join(contracts.path, name)).writeAsStringSync(md);
    });
  }

  group('A-1485-1: plan reports what it read', () {
    test('one declared-rows line per contract file, per-file counts', () async {
      seedFeature();
      seedContracts({
        'task-store.md': taskStoreMd,
        'data-layer.md': dataLayerMd,
      });

      final out = await plan();

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason: 'the plan succeeds with the supplement in place',
      );
      expect(
        out,
        contains('declared rows: 4 from contracts/task-store.md'),
        reason: 'plan names the file and how many rows it extracted',
      );
      expect(out, contains('declared rows: 3 from contracts/data-layer.md'));
    });
  });

  group('A-1485-2: contract-file traces route declared', () {
    test(
      'an FR traced to task-store.Create binds the contract-file row',
      () async {
        seedFeature();
        seedContracts({'task-store.md': taskStoreMd});

        final out = await plan();

        expect(
          out,
          contains('route: U1 -> unit lane'),
          reason:
              'the traced behavior routes declared — the contract-file row '
              'resolved (the issue: 42 behaviours fallback-route)',
        );
        expect(
          out,
          isNot(contains('U1 -> refused')),
          reason: 'the trace no longer dangles',
        );
        final list = File(
          p.join(tmpDir.path, 'specs', feature, 'tdd', 'test-list.md'),
        ).readAsStringSync();
        expect(
          list,
          contains('task-store.Create'),
          reason:
              'the trace token travels to the test list so gen resolves '
              'the declared signature',
        );
      },
    );
  });

  group('A-1485-3: no contracts/ directory — output unchanged', () {
    test('plan emits none of the new lines', () async {
      seedFeature();

      final out = await plan();

      expect(CliRunner.lastDispatchedExitCode, 0);
      expect(out, isNot(contains('declared rows:')));
      expect(out, isNot(contains('contracts/')));
    });
  });

  group('A-1485-4: a contracts/ directory that yields nothing warns', () {
    test('an empty contracts/ directory warns naming the path', () async {
      seedFeature();
      seedContracts({});

      final out = await plan();

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason: 'the warning is advisory — the plan still succeeds',
      );
      expect(out, contains('WARNING'));
      expect(out, contains('contracts'));
    });

    test('a prose-only contracts/ directory warns too', () async {
      seedFeature();
      seedContracts({
        'notes.md': '# Notes\n\nSome CLI flags:\n\n- `--target` — the target\n',
      });

      final out = await plan();

      expect(out, contains('WARNING'));
      expect(out, contains('contracts'));
      expect(out, isNot(contains('declared rows:')));
    });
  });
}
