// Bug #835 (tdd-ffi-ocr-harness): the reader must accept the
// native-boundary kind — declared by hand in the 6-column dialect's kind
// cell (dialect 1) or via a `## Native loop` section header — without
// loosening the malformed-row contract for genuinely unknown kinds.
//
// Pre-fix RED (real CLI, scripts/red_835.sh): an ffi kind cell was
// rejected as "expected 4 columns (id/behavior/traces/state), found 6"
// and a 4-column row under `## Native loop` as "table row outside an
// outer/inner loop behavior section" — the ffi behavior was
// unrepresentable and `zfa tdd gen` exited 1 before writing anything.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('test_list_reader_835_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<String> seed(String content) async {
    final dir = p.join(tmp.path, 'specs', '090-fixture');
    await Directory(p.join(dir, 'tdd')).create(recursive: true);
    await File(p.join(dir, 'tdd', 'test-list.md')).writeAsString(content);
    return dir;
  }

  group('bug 835: the native-boundary kind is representable', () {
    test(
      'a 6-column row with kind cell `ffi` parses as BehaviorKind.ffi',
      () async {
        final dir = await seed('''
# Test List: 090-fixture

## Native loop: ffi behaviors

| id | behavior | traces | kind | state | target |
| -- | -------- | ------ | ---- | ----- | ------ |
| U1 | the pdf-to-markdown ffi binding converts a sample pdf | FR-001 | ffi | PENDING | |
''');
        final rows = await TestListReader(dir).read();
        expect(rows, hasLength(1));
        expect(rows.single.kind, BehaviorKind.ffi);
        expect(rows.single.id, 'U1');
        expect(rows.single.target, 'subject_u1');
      },
    );

    test(
      'a canonical 4-column row under `## Native loop` parses as ffi',
      () async {
        final dir = await seed('''
# Test List: 090-fixture

## Native loop: ffi behaviors

One per native-boundary requirement.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U2 | the ocr ffi binding extracts invoice fields within tolerance | FR-002 | PENDING |
''');
        final rows = await TestListReader(dir).read();
        expect(rows, hasLength(1));
        expect(
          rows.single.kind,
          BehaviorKind.ffi,
          reason: 'the native loop section header carries the kind',
        );
        expect(rows.single.target, 'subject_u2');
      },
    );

    test(
      'a `## Native loop` row MAY override via the dialect-1 kind cell',
      () async {
        final dir = await seed('''
# Test List: 090-fixture

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | target |
| -- | -------- | ------ | ---- | ----- | ------ |
| U3 | binding contract for the native converter | FR-003 | ffi | PENDING | |
''');
        final rows = await TestListReader(dir).read();
        expect(rows, hasLength(1));
        expect(
          rows.single.kind,
          BehaviorKind.ffi,
          reason: 'the kind cell wins over the section header (dialect 1)',
        );
      },
    );

    test('the three loop kinds coexist in one list, in file order', () async {
      final dir = await seed('''
# Test List: 090-fixture

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | converts a golden sample | AC-1 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | plain unit behavior | FR-001 | PENDING |

## Native loop: ffi behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U2 | native-boundary behavior | FR-002 | PENDING |
''');
      final rows = await TestListReader(dir).read();
      expect(rows.map((r) => r.kind).toList(), [
        BehaviorKind.acceptance,
        BehaviorKind.unit,
        BehaviorKind.ffi,
      ]);
    });

    test(
      'an unknown kind cell is still malformed (fail-closed preserved)',
      () async {
        final dir = await seed('''
# Test List: 090-fixture

## Inner loop: unit behaviors

| id | behavior | traces | kind | state | target |
| -- | -------- | ------ | ---- | ----- | ------ |
| U4 | mystery behavior | FR-004 | quantum | PENDING | |
''');
        await expectLater(
          TestListReader(dir).read(),
          throwsA(isA<TestListReadException>()),
          reason: 'the honest misfire-stop for unknown dialects is unchanged',
        );
      },
    );

    test(
      'a 4-column row outside any loop section is still malformed',
      () async {
        final dir = await seed('''
# Test List: 090-fixture

## Unrelated section

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U5 | orphan row | FR-005 | PENDING |
''');
        await expectLater(
          TestListReader(dir).read(),
          throwsA(isA<TestListReadException>()),
        );
      },
    );
  });
}
