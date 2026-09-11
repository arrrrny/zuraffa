// Bug #1401: `zfa tdd plan` writes FR/AC prose containing `|` into
// markdown pipe-table cells UNESCAPED; `zfa tdd run` then refuses the
// very file plan wrote ("expected 4 columns, found 6"). Plan and run
// disagree on the validity of plan's own output.
//
// Fix contract proven here:
//
//   1. WRITER: plan escapes `|` as `\|` inside table cells so a piped
//      description can never change the row's column count.
//   2. READER (plan side): plan's meta-index reconcile splits rows on
//      UNESCAPED pipes only — the same escaped-pipe-aware semantics the
//      shared TestListReader row parser already applies run-side — so a
//      file plan wrote is a file plan can re-read.
//   3. ROUND-TRIP: the run-side reader (TestListReader) parses the
//      escaped list back with the ORIGINAL literal prose restored.
//      Plan and run agree on the table format for all FR text.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmpDir;
  const slug = 'pipe-escape-round-trip';

  const specMd =
      '''
# Spec for $slug

**Template Version**: zuraffa-1.0

## Acceptance Scenarios

1. **Given** a seeded spec with piped prose **When** the operator runs `todo filter <all|active|completed>` **Then** the visible list shows only the selected bucket

## Functional Requirements

- **FR-001**: The CLI MUST expose todo filter <all|active|completed> selection on the command line.
  traces: TodoFilter
''';

  setUp(() => tmpDir = Directory.systemTemp.createTempSync('bug_1401_'));

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedSpec() async {
    final dir = Directory(p.join(tmpDir.path, 'specs', slug));
    await Directory(p.join(dir.path, 'tdd')).create(recursive: true);
    await File(p.join(dir.path, 'spec.md')).writeAsString(specMd);
  }

  Future<int> plan() async {
    await CliRunner(
      exitOnCompletion: false,
    ).runCapturing(['tdd', 'plan', '--project', tmpDir.path, slug]);
    return CliRunner.lastDispatchedExitCode;
  }

  File listFile() =>
      File(p.join(tmpDir.path, 'specs', slug, 'tdd', 'test-list.md'));

  /// The behavior ids the CURRENT list carries (`[AU]\d+` shapes the
  /// reconcile reader keys on).
  Set<String> idsIn(String content) => RegExp(
    r'\b([AU]\d+)\b',
  ).allMatches(content).map((m) => m.group(1)!).toSet();

  group('Bug #1401 — plan escapes pipes in table cells; readers unescape', () {
    test(
      'plan writes escaped cells and the run-side reader round-trips the prose',
      () async {
        await seedSpec();
        expect(await plan(), 0, reason: 'plan succeeds on piped prose');

        final written = listFile().readAsStringSync();
        expect(
          written.contains(r'<all\|active\|completed>'),
          isTrue,
          reason:
              'the writer escapes `|` as `\\|` inside table cells — '
              'the row must keep its 4-column shape on disk',
        );

        // The run-side reader is the SAME parser `zfa tdd run` uses;
        // parsing the list plan just wrote is the run leg of the loop.
        final rows = await TestListReader(
          p.join(tmpDir.path, 'specs', slug),
        ).read();
        expect(rows, isNotEmpty, reason: 'the escaped list is readable');
        final unit = rows.where((r) => r.id.startsWith('U')).toList();
        expect(unit, isNotEmpty, reason: 'the FR-001 row is present');
        expect(
          unit.first.description,
          contains('todo filter <all|active|completed>'),
          reason:
              'the reader unescapes — run sees the ORIGINAL prose with '
              'literal pipes, never the escaped form',
        );
        expect(
          rows.any((r) => r.id.startsWith('A')),
          isTrue,
          reason: 'the acceptance row (piped prose too) survives the gate',
        );
      },
    );

    test(
      're-planning reconciles ids through the escaped file plan wrote',
      () async {
        await seedSpec();
        expect(await plan(), 0);
        final before = idsIn(listFile().readAsStringSync());
        expect(before, isNotEmpty);

        expect(
          await plan(),
          0,
          reason: 'the second plan reads its own escaped output',
        );
        final after = idsIn(listFile().readAsStringSync());

        expect(
          after.difference(before),
          isEmpty,
          reason:
              'reconcile must NOT re-number behaviors: the escaped rows are '
              'readable by plan itself (writer and plan-side reader agree)',
        );
        expect(
          writtenHasUnescapedPipeInsideCells(listFile().readAsStringSync()),
          isFalse,
          reason: 'the re-written list is still fully escaped',
        );
      },
    );
  });
}

/// True when a data row carries an UNESCAPED pipe that is not a cell
/// delimiter — i.e. the writer failed to escape a piped description.
/// Cheap structural probe: for the fixture's rows the only legitimate
/// unescaped pipes are the 4- or 5-cell delimiters.
bool writtenHasUnescapedPipeInsideCells(String content) {
  for (final line in content.split('\n')) {
    final t = line.trim();
    if (!t.startsWith('|') || !t.endsWith('|')) continue;
    if (RegExp(r'^\|[\s\-|]+\|$').hasMatch(t)) continue; // separator row
    // Split on unescaped pipes the way the fixed reader does.
    final cells = <String>[];
    final buf = StringBuffer();
    for (var i = 0; i < t.length; i++) {
      final ch = t[i];
      if (ch == r'\' && i + 1 < t.length && t[i + 1] == '|') {
        buf.write('|');
        i++;
      } else if (ch == '|') {
        cells.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    cells.add(buf.toString());
    final data = cells.where((c) => c.trim().isNotEmpty).length;
    if (data == 0) continue;
    // Header/separator shapes are 4 or 5 wide; a piped description
    // row balloons past both.
    if (data > 5) return true;
  }
  return false;
}
