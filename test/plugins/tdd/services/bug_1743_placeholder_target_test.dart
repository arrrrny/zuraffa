// Issue #1743 — a markdown placeholder in the test-reference (last) column
// of a spec-kit-shaped `tdd/test-list.md` row must never reach the generator
// as a subject function name.
//
// `TestListReader.resolveDefaultTarget` used the cell verbatim unless it was
// empty or path-like (`/`, `::`, `$`), so a placeholder cell like `` `-` ``
// (the universal markdown "empty" cell) was emitted as
// ``void `-`() => throw UnimplementedError(...)`` — a non-compiling stub
// that `zfa tdd status` had already reported as a valid list. The pair died
// at compile on the FIRST loop step (`verify-red classification=compile-error`)
// instead of surfacing a named format error.
//
// The row shape under test is the tdd extension's 6-column dialect
// (`| id | behavior | traces | kind | state | test |`, spec 050 FR-007) —
// the shape the issue's repro table uses.
//
// ZURAFFA MISFIRE RULE: this suite is the regression guard for the misfire
// reported in arrrrny/zuraffa#1743.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  group('resolveDefaultTarget — issue #1743', () {
    test('a backticked dash placeholder resolves to the snake-id default', () {
      expect(
        TestListReader.resolveDefaultTarget('A1', cell: '`-`'),
        'subject_a1',
      );
    });

    test('a bare dash placeholder resolves to the snake-id default', () {
      expect(
        TestListReader.resolveDefaultTarget('A1', cell: '-'),
        'subject_a1',
      );
    });

    test('every placeholder spelling resolves to the snake-id default', () {
      for (final cell in ['--', '–', '—', 'n/a', 'N/A', '`N/A`']) {
        expect(
          TestListReader.resolveDefaultTarget('A1', cell: cell),
          'subject_a1',
          reason: 'placeholder cell "$cell"',
        );
      }
    });

    test('an explicit identifier cell still wins', () {
      expect(
        TestListReader.resolveDefaultTarget('A1', cell: 'subjectUnderTest'),
        'subjectUnderTest',
      );
    });

    test('a path-like cell still resolves to the snake-id default', () {
      expect(
        TestListReader.resolveDefaultTarget(
          'A1',
          cell: 'test/a1_test.dart::the scenario',
        ),
        'subject_a1',
      );
    });
  });

  group('reader — issue #1743', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('bug1743_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Future<String> seed(String testList) async {
      final dir = p.join(tmp.path, 'specs', '091-demo');
      await Directory(p.join(dir, 'tdd')).create(recursive: true);
      await File(p.join(dir, 'tdd', 'test-list.md')).writeAsString(testList);
      return dir;
    }

    const placeholderList = '''
# Test List: 091-demo

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | five tab slots are present, the deals tab reports selected, and no other tab does. | AC-1 | approval | PENDING | `-` |
''';

    test('a placeholder cell reads back as the default target', () async {
      final dir = await seed(placeholderList);

      final rows = await TestListReader(dir).read();

      expect(rows, hasLength(1));
      expect(rows.single.target, 'subject_a1');
    });

    test('the rendered subject declares a legal Dart function name', () async {
      final dir = await seed(placeholderList);

      final row = (await TestListReader(dir).read()).single;
      final source = const SubjectWriter().render(
        Behavior(
          id: row.id,
          feature: '091-demo',
          kind: row.kind,
          description: row.description,
          sourceCriterion: row.traces,
          target: row.target,
        ),
      );

      expect(source, contains('void subject_a1()'));
      expect(
        source,
        isNot(contains('void `-`()')),
        reason: 'the placeholder must never reach the emitted identifier',
      );
    });

    test('an illegal identifier cell is a named format error', () async {
      final dir = await seed('''
# Test List: 091-demo

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | the deals tab reports selected | AC-1 | approval | PENDING | `not a name` |
''');

      await expectLater(
        TestListReader(dir).read(),
        throwsA(
          isA<TestListReadException>().having(
            (e) => e.message,
            'message',
            allOf(contains('line 7'), contains('not a name')),
          ),
        ),
      );
    });
  });
}
