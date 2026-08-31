@Tags(['slow', 'integration'])
// SC-019 — spec 050 (bug #617 migration completion): the hand-written
// 6-column extension dialect through the REAL CLI, as a subprocess, so
// stderr is observable (the deprecation note is not capturable in-process
// through CliRunner's print zone).
//
//   U3: a mixed-dialect list read via the real `zfa tdd gen` prints the
//       deprecation note exactly once per file and leaves the list's
//       bytes untouched (FR-009 / FR-010).
//   A6: `zfa tdd run` re-reads the repo's own specs/049-tdd-run list
//       (copied verbatim into a temp project) without a malformed-list
//       runner-error — the loop's front door stays open for the repo's
//       own completed features (US2.AC3).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Absolute path to the zuraffa repo root (the real zfa CLI source).
String _findZuraffaRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir.path;
    }
    if (dir.path == dir.parent.path) {
      throw StateError('cannot locate the zuraffa repo root');
    }
    dir = dir.parent;
  }
}

Future<ProcessResult> _runRealZfa(
  String repoRoot,
  List<String> args, {
  required String workingDirectory,
}) {
  return Process.run(Platform.resolvedExecutable, [
    p.join(repoRoot, 'bin', 'zfa.dart'),
    ...args,
  ], workingDirectory: workingDirectory);
}

void main() {
  late Directory tmp;
  late String repoRoot;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sc_019_legacy_dialect_');
    repoRoot = _findZuraffaRoot();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('SC-019/U3: the real gen prints the deprecation note exactly once per '
      'file on a mixed-dialect list and never modifies the list', () async {
    const feature = '050-mixed';
    final featureDir = p.join(tmp.path, 'specs', feature, 'tdd');
    await Directory(featureDir).create(recursive: true);
    // Mixed dialects in one file: one canonical 4-column row, one
    // extension-shape 6-column row, one acceptance/unit-cell 6-column
    // row. The note must fire ONCE for the file, not once per row.
    const listContent =
        '''
# Test List: $feature

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | canonical plan-shaped row | US1.AC1 | PENDING |

## Inner loop: unit behaviors

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | extension-dialect row | FR-007 | example | PENDING | t.dart::U1 |
| U2 | gen-dialect row | FR-006 | unit | PENDING | sampleSubject |
''';
    final listFile = File(p.join(featureDir, 'test-list.md'));
    await listFile.writeAsString(listContent);
    final bytesBefore = await listFile.readAsBytes();

    final gen = await _runRealZfa(repoRoot, [
      'tdd',
      'gen',
      'U1',
      '--feature',
      feature,
      '--project',
      tmp.path,
    ], workingDirectory: tmp.path);

    expect(gen.exitCode, 0, reason: 'gen failed:\n${gen.stdout}${gen.stderr}');
    expect(gen.stdout, contains('behavior_id: U1'));
    expect(gen.stdout, contains('source_criterion: FR-007'));

    // The note: exactly once in this process's stderr, naming the
    // canonical format and the producing command (FR-009).
    final stderr = gen.stderr as String;
    expect(stderr, contains('deprecated 6-column test-list rows'));
    expect(
      RegExp('deprecated 6-column test-list rows').allMatches(stderr),
      hasLength(1),
      reason: 'the note must print once per file, not per row:\n$stderr',
    );
    expect(stderr, contains('zfa tdd plan'));

    // Reading is side-effect free (FR-010): the list's bytes are
    // unchanged by the read (gen wrote the test/subject pair, but not
    // into the list).
    final bytesAfter = await listFile.readAsBytes();
    expect(bytesAfter, bytesBefore, reason: 'the reader must not rewrite');
  });

  test('SC-019/A6: the real run re-reads the repo\'s own specs/049 list '
      'without a malformed runner-error (US2.AC3)', () async {
    const feature = '049-copy';
    final featureDir = p.join(tmp.path, 'specs', feature, 'tdd');
    await Directory(featureDir).create(recursive: true);

    // The repo's OWN hand-written list, verbatim bytes.
    final realList = File(
      p.join(repoRoot, 'specs', '049-tdd-run', 'tdd', 'test-list.md'),
    );
    expect(realList.existsSync(), isTrue, reason: 'fixture list missing');
    final listBytes = await realList.readAsBytes();
    await File(p.join(featureDir, 'test-list.md')).writeAsBytes(listBytes);

    // Every behavior DONE with evidence: the run must reconcile all
    // rows as complete and exit 0 without spawning a single step.
    final ids = RegExp(r'^\| (A\d+|U\d+) ', multiLine: true)
        .allMatches(String.fromCharCodes(listBytes))
        .map((m) => m.group(1)!)
        .toSet();
    expect(ids, isNotEmpty);
    final states = {for (final id in ids) id: 'done'};
    await File(p.join(featureDir, 'run-state.json')).writeAsString(
      jsonEncode({
        'feature': feature,
        'behavior_states': states,
        'in_flight_behavior_id': null,
        'in_flight_step': null,
        'in_flight_owner_pid': null,
      }),
    );
    final log = StringBuffer()..writeln('# Cycle Log');
    for (final id in ids) {
      log
        ..writeln('## Cycle: $id (red)')
        ..writeln('- behavior: $id')
        ..writeln('- kind: red')
        ..writeln()
        ..writeln('## Cycle: $id (green)')
        ..writeln('- behavior: $id')
        ..writeln('- kind: green')
        ..writeln();
    }
    await File(
      p.join(featureDir, 'cycle-log.md'),
    ).writeAsString(log.toString());

    final run = await _runRealZfa(repoRoot, [
      'tdd',
      'run',
      feature,
      '--project',
      tmp.path,
    ], workingDirectory: tmp.path);

    final out = '${run.stdout}${run.stderr}';
    // The loop's front door: the dialect no longer bricks list-reading.
    expect(out, isNot(contains('expected 4 columns')), reason: out);
    expect(out, isNot(contains('result=runner-error')), reason: out);
    // Every row resolved and was reconciled as done-with-evidence.
    expect(out, contains('${ids.length} behavior(s)'), reason: out);
    expect(out, contains('${ids.length} already done — skipping'), reason: out);
    expect(
      out,
      contains(
        'run: feature=$feature result=complete pending=0 red=0 green=0 '
        'done=${ids.length}',
      ),
      reason: out,
    );
    expect(run.exitCode, 0, reason: out);
  });
}
