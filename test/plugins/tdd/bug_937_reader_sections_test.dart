// Bug #937 ([TDD-131]) — the reader must speak every shape plan writes.
//
// #926 taught `zfa tdd plan` to render `## External dependencies` and
// `## Layer contracts` sections in the test list; `TestListReader.read()`
// only skipped `## Key entities`, so the new sections' table rows died as
// "table row outside an outer/inner loop behavior section" — killing
// `zfa tdd run` (exit 2) on every deps-declaring (zuraffa-1.0) spec and
// making re-plan drop ffi preservation with a noisy note.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('bug937_reader_');
    featureDir = p.join(tmpDir.path, 'specs', '001-demo');
    Directory(p.join(featureDir, 'tdd')).createSync(recursive: true);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> writeTestList(String body) async {
    await File(p.join(featureDir, 'tdd', 'test-list.md')).writeAsString(body);
  }

  test('read() tolerates the External dependencies and Layer contracts '
      'sections plan writes (returns behavior rows, no exception)', () async {
    await writeTestList('''
# Test List: 001-demo

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the app responds | AC-1 | PENDING |

## Key entities

| entity | fields | purpose |
| ------ | ------ | ------- |
| Demo | `id: String` | one demo |

## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| Hive | storage | `read(key) -> T?` | P1 |

## Layer contracts

### Domain

- `DemoRepository`: `get(String id) -> Future<Result<Demo, AppFailure>>`

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | returns the demo | FR-001 | PENDING |
''');

    final rows = await TestListReader(featureDir).read();

    expect(rows, hasLength(2));
    expect(rows.first.id, 'A1');
    expect(rows.first.kind.name, 'acceptance');
    expect(rows.last.id, 'U1');
    expect(rows.last.kind.name, 'unit');
  });

  test('read() on an artifact WITHOUT the declarative sections is unchanged '
      '(regression guard)', () async {
    await writeTestList('''
# Test List: 001-demo

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the app responds | AC-1 | DONE |
''');

    final rows = await TestListReader(featureDir).read();

    expect(rows, hasLength(1));
    expect(rows.first.id, 'A1');
    expect(rows.first.state.name, 'done');
  });
}
