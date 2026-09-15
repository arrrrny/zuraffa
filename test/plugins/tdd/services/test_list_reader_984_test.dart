// Bug 984: `zfa tdd run` aborted on bare ` |` separator lines between
// test-list table sections, treating them as malformed rows ("expected 4
// columns ... found 0"). A line whose only table cells are empty is
// whitespace between table groups — the reader skips it instead of
// rejecting it, so committed test-lists with this spacing keep running.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('test_list_reader_984_');
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

  // The exact trigger shape from the bug report: a bare " |" line
  // (whitespace, then a pipe) sitting between a `###` sub-heading and the
  // next table group.
  test('984: a bare " |" separator line between sections is skipped', () async {
    final dir = await seed('''
# Test List: 090-fixture

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | first acceptance behavior | US1.AC1 | PENDING |

### `lib/src/inner.dart`

 |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | first unit behavior | FR-001 | PENDING |
''');

    final rows = await TestListReader(dir).read();

    expect(rows.map((r) => r.id), ['A1', 'U1']);
    expect(rows[0].kind, BehaviorKind.acceptance);
    // The row after the separator still resolves the new section's kind.
    expect(rows[1].kind, BehaviorKind.unit);
    expect(rows[1].state, BehaviorState.pending);
  });

  test('984: every pipes-and-whitespace-only shape is skipped', () async {
    final dir = await seed(
      [
        '## Inner loop: unit behaviors',
        '',
        '| id | behavior | traces | state |',
        '| -- | -------- | ------ | ----- |',
        '| U1 | bare pipe row | FR-001 | PENDING |',
        '|',
        '| ',
        '|   |',
        '| |',
        '|  |  |  |  |',
        '| U2 | after separator soup | FR-002 | PENDING |',
        '',
      ].join('\n'),
    );

    final rows = await TestListReader(dir).read();

    expect(rows.map((r) => r.id), ['U1', 'U2']);
    expect(rows[1].kind, BehaviorKind.unit);
  });

  test('984: a separator line does not reset the enclosing kind', () async {
    // The bare ` |` sits INSIDE a section (between two rows of the same
    // table group); the following row must keep the section's kind.
    final dir = await seed('''
## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | before the gap | US1.AC1 | PENDING |
 |

| A2 | after the gap | US1.AC2 | PENDING |
''');

    final rows = await TestListReader(dir).read();

    expect(rows.map((r) => r.id), ['A1', 'A2']);
    expect(rows[1].kind, BehaviorKind.acceptance);
  });

  test('984: genuine malformed rows still stop the reader honestly', () async {
    // Tolerating empty separator rows must not paper over format drift:
    // a row with a real id-shaped cell but the wrong column count still
    // stops with the line-naming error (FR-011 misfire-stop).
    final dir = await seed('''
## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | fine | FR-001 | PENDING |
| U2 | six column row | FR-002 | banana | PENDING |  |
''');

    await expectLater(
      TestListReader(dir).read(),
      throwsA(
        isA<TestListReadException>().having(
          (e) => e.message,
          'message',
          // Exact wording pinned: the error names the line, the 4-column
          // contract, the found count, and the offending raw line.
          'test-list.md line 6: expected 4 columns '
              '(id/behavior/traces/state), found 6: '
              '"| U2 | six column row | FR-002 | banana | PENDING |  |"',
        ),
      ),
    );
  });

  // -------------------------------------------------------------------
  // Verification remediation (zfa tdd verify pass 2): strengthen the
  // reader's coverage so the mutation audit's survivors shrink to the
  // provably-equivalent mutants. Same file keeps the bug's evidence in
  // one place.
  // -------------------------------------------------------------------

  test('remediation: PersistenceMarker.extract collapses whitespace runs '
      'around the stripped tag', () {
    final (description, marked) = PersistenceMarker.extract(
      'failing   [persistence]  cache',
    );
    expect(marked, isTrue);
    expect(description, 'failing cache');
  });

  test(
    'remediation: a 2-cell Key entities row yields no fields, no crash',
    () async {
      final dir = await seed('''
## Key entities

| entity | fields |
| ------ | ------ |
| Role | 
''');

      final entities = await TestListReader(dir).readEntities();

      expect(entities, hasLength(1));
      expect(entities[0].name, 'Role');
      expect(entities[0].fields, isEmpty);
    },
  );

  test(
    'remediation: a * bullet in Layer contracts parses like - bullets',
    () async {
      final dir = await seed('''
## Layer contracts

### domain

* `IRepo`: `sig1`, `sig2`
- `IOther`: `sig3`
''');

      final contracts = await TestListReader(dir).readLayerContracts();

      expect(contracts.map((c) => c.interfaceName), ['IRepo', 'IOther']);
      expect(contracts[0].methods, ['sig1', 'sig2']);
    },
  );

  test('remediation: a pipe-prefixed line ending in a stray backslash '
      'reports malformed, not a crash', () async {
    final dir = await seed('''
## Inner loop: unit behaviors

|oops\\
''');

    await expectLater(
      TestListReader(dir).read(),
      throwsA(
        isA<TestListReadException>().having(
          (e) => e.message,
          'message',
          contains('expected 4 columns (id/behavior/traces/state)'),
        ),
      ),
    );
  });

  test('remediation: the deprecated gen-legacy dialect warns ONCE with the '
      'migration message, on stderr', () async {
    // The warning goes to the process-global stderr, which an in-process
    // test cannot intercept — the assertion runs a minimal child that
    // reads a seeded gen-legacy fixture and lets the parent inspect
    // stderr. Two legacy rows: the warning fires exactly once.
    final fixture = await seed('''
## Inner loop: unit behaviors

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| B-001 | legacy row one | FR-001 | unit | PENDING | |
| B-002 | legacy row two | FR-002 | acceptance | PENDING | x |
''');

    final repoRoot = _findRepoRoot();
    final child = File(p.join(tmp.path, 'stderr_probe.dart'))
      ..writeAsStringSync('''
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

Future<void> main(List<String> args) async {
  await TestListReader(args[0]).read();
}
''');

    final result = await Process.run('dart', [
      '--packages=${p.join(repoRoot, '.dart_tool', 'package_config.json')}',
      child.path,
      fixture,
    ], workingDirectory: repoRoot);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final stderrText = result.stderr.toString();
    expect(
      'deprecated 6-column test-list rows detected'.allMatches(stderrText),
      hasLength(1),
      reason: 'the deprecated-dialect warning fires once per file',
    );
    expect(stderrText, contains('deprecated 6-column test-list rows detected'));
    expect(stderrText, contains('(id/behavior/traces/kind/state/target)'));
    expect(
      stderrText,
      contains('converting tdd/test-list.md to the canonical 4-column shape'),
    );
    expect(
      stderrText,
      contains('(id/behavior/traces/state); the 6-column dialect is accepted'),
    );
  });
}

/// Walk up from the CWD to the repo root (the pubspec named `zuraffa`).
String _findRepoRoot() {
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
