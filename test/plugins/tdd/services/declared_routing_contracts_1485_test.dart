// Issue #1485 — the declared-row source reads the feature's contracts/
// directory. `DeclaredRouting.contractFiles` enumerates every `*.md`
// under `<featureDir>/contracts/` (sorted; a missing directory yields
// nothing), and `DeclaredRouting.declaredSignatureFor` — the gen-time
// signature resolution make/func share — resolves against the SAME
// merged source plan binds at plan time: declare once, resolve
// everywhere.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/declared_routing.dart';

void main() {
  late Directory tmpDir;
  const feature = '1485-todo';

  const specMd = '''
# Spec: todo

**Template Version**: `zuraffa-1.0`

## Acceptance Scenarios

1. **Given** a stored task, **When** the app launches, **Then** the task list renders in file order

## Functional Requirements

- **FR-001**: The system shall load stored tasks from the task store at launch.
  traces: task-store.getAll
''';

  const taskStoreMd = '''
# Contract: TaskStore

## Methods

- `getAll() -> List<Task>`
- `create(Task) -> Task`
''';

  setUp(
    () => tmpDir = Directory.systemTemp.createTempSync('declared_rt_1485_'),
  );

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  String featureDir() => p.join(tmpDir.path, 'specs', feature);

  void seedFeature({
    String? contractMd,
    List<(String, String)> extra = const [],
  }) {
    Directory(featureDir()).createSync(recursive: true);
    File(p.join(featureDir(), 'spec.md')).writeAsStringSync(specMd);
    // A minimal planned test list (the canonical 4-column shape) so
    // declaredSignatureFor finds U1's traces cell.
    final tddDir = Directory(p.join(featureDir(), 'tdd'));
    tddDir.createSync(recursive: true);
    File(p.join(tddDir.path, 'test-list.md')).writeAsStringSync('''
## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | loads stored tasks at launch | FR-001, task-store.getAll | PENDING |
''');
    if (contractMd != null) {
      final contracts = Directory(p.join(featureDir(), 'contracts'));
      contracts.createSync(recursive: true);
      File(
        p.join(contracts.path, 'task-store.md'),
      ).writeAsStringSync(contractMd);
      for (final (name, md) in extra) {
        File(p.join(contracts.path, name)).writeAsStringSync(md);
      }
    }
  }

  group('U-1485-5: contractFiles enumeration', () {
    test('a missing contracts/ directory yields an empty list', () {
      seedFeature();
      expect(DeclaredRouting.contractFiles(featureDir()), isEmpty);
    });

    test('every *.md file is enumerated sorted; non-md files are ignored', () {
      seedFeature(
        contractMd: taskStoreMd,
        extra: [('a-data-layer.md', '# data\n'), ('notes.txt', 'nope')],
      );
      final files = DeclaredRouting.contractFiles(featureDir());
      expect(files.map((f) => f.file).toList(), [
        'a-data-layer.md',
        'task-store.md',
      ], reason: 'sorted by file name — the collision policy is deterministic');
      expect(files.last.md, contains('getAll'));
    });
  });

  group('U-1485-6: declaredSignatureFor resolves contract-file rows', () {
    test(
      'a task-store.getAll trace binds the contract-file signature',
      () async {
        seedFeature(contractMd: taskStoreMd);
        final signature = await DeclaredRouting.declaredSignatureFor(
          cwd: tmpDir.path,
          featureName: feature,
          behaviorId: 'U1',
        );
        expect(
          signature,
          isNotNull,
          reason:
              'the gen-time resolution reads the same merged source plan '
              'binds at plan time',
        );
        expect(signature!.toString(), 'getAll() -> List<Task>');
      },
    );

    test('without the contract file the same trace dangles (null)', () async {
      seedFeature();
      final signature = await DeclaredRouting.declaredSignatureFor(
        cwd: tmpDir.path,
        featureName: feature,
        behaviorId: 'U1',
      );
      expect(
        signature,
        isNull,
        reason: 'nothing declares the row — the trace cannot bind',
      );
    });
  });
}
