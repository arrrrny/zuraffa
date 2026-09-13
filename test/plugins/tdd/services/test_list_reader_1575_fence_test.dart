// Bug 1575: four `startsWith('## ')` line-scanners in `test_list_reader.dart`
// stay fence-blind — a `## ` line inside a fenced code block (a markdown
// banner inside a fenced example) flips their section state exactly like a
// real header: post-fence rows vanish silently (in-fence declarative marker)
// or parse under the wrong kind (in-fence loop marker). Same defect class as
// #1467/#1549, different input files. The readers must route their `## `
// header detection through the shared fence-aware splitter
// (`splitCycleLogSections()`), and the per-reader state machines stay
// unchanged.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/test_list_reader.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('test_list_reader_1575_');
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

  // -------------------------------------------------------------------
  // _parseRows — the section-kind scanner (line 346).
  // -------------------------------------------------------------------

  test('1575: an in-fence loop marker does not re-kind the section', () async {
    final dir = await seed('''
## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | before the fence | US1.AC1 | PENDING |

```dart
// usage example — the fenced banner is body, never a header
## Inner loop: unit behaviors
```

| A2 | after the fence | US1.AC2 | PENDING |
''');

    final rows = await TestListReader(dir).read();

    expect(rows.map((r) => r.id), ['A1', 'A2']);
    // The fenced `## Inner loop:` banner must not flip the enclosing kind:
    // A2 stays an acceptance row of the outer-loop section.
    expect(rows[1].kind, BehaviorKind.acceptance);
  });

  test(
    '1575: an in-fence declarative marker does not swallow real rows',
    () async {
      final dir = await seed('''
## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | before the fence | FR-001 | PENDING |

```bash
zfa make example
## Key entities
```

| U2 | after the fence | FR-002 | PENDING |
''');

      final rows = await TestListReader(dir).read();

      // The in-fence `## Key entities` banner must not switch the walk into
      // the declarative section — U2 is a real behavior row, not a Key
      // entities declaration.
      expect(rows.map((r) => r.id), ['U1', 'U2']);
      expect(rows[1].kind, BehaviorKind.unit);
    },
  );

  // -------------------------------------------------------------------
  // readEntities — the Key entities scanner (line 485).
  // -------------------------------------------------------------------

  test(
    '1575: readEntities — an in-fence header does not close the section',
    () async {
      final dir = await seed('''
## Key entities

| entity | fields |
| ------ | ------ |
| Role | name:String |

```dart
final r = Role();
## External dependencies
```

| Widget | child:Widget |
''');

      final entities = await TestListReader(dir).readEntities();

      expect(entities.map((e) => e.name), ['Role', 'Widget']);
      expect(entities[1].fields, ['child:Widget']);
    },
  );

  // -------------------------------------------------------------------
  // readDependencies — the External dependencies scanner (line 533).
  // -------------------------------------------------------------------

  test(
    '1575: readDependencies — an in-fence header does not close the section',
    () async {
      final dir = await seed('''
## External dependencies

| dependency | type | contract | mock priority |
| ---------- | ---- | -------- | ------------- |
| AuthApi | remote | AuthContract | high |

```yaml
deploy:
## Key entities
```

| Clock | system | ClockContract | low |
''');

      final dependencies = await TestListReader(dir).readDependencies();

      expect(dependencies.map((d) => d.dependency), ['AuthApi', 'Clock']);
      expect(dependencies[1].type, 'system');
      expect(dependencies[1].contract, 'ClockContract');
      expect(dependencies[1].mockPriority, 'low');
    },
  );

  // -------------------------------------------------------------------
  // readLayerContracts — the Layer contracts scanner (line 571).
  // -------------------------------------------------------------------

  test(
    '1575: readLayerContracts — an in-fence header does not close the section',
    () async {
      final dir = await seed('''
## Layer contracts

### domain

- `IRepo`: `sig1`, `sig2`

```dart
abstract class Fake {
## Key entities
}
```

- `IStore`: `sig3`
''');

      final contracts = await TestListReader(dir).readLayerContracts();

      expect(contracts.map((c) => c.interfaceName), ['IRepo', 'IStore']);
      expect(contracts[0].layer, 'domain');
      expect(contracts[1].layer, 'domain');
      expect(contracts[1].methods, ['sig3']);
    },
  );

  // -------------------------------------------------------------------
  // Well-formed inputs must parse exactly as before (hard constraint).
  // -------------------------------------------------------------------

  test('1575: a well-formed list without fences parses unchanged', () async {
    final dir = await seed('''
# Test List: 090-fixture

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | acceptance row | US1.AC1 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | unit row | FR-001 | DONE |
''');

    final rows = await TestListReader(dir).read();

    expect(rows.map((r) => r.id), ['A1', 'U1']);
    expect(rows[0].kind, BehaviorKind.acceptance);
    expect(rows[1].kind, BehaviorKind.unit);
    expect(rows[1].state, BehaviorState.done);
  });

  test('1575: the committed 004 corpus shape (in-fence Baseline banner) '
      'parses identically', () async {
    // The one committed file whose fence carries a `## ` line
    // (specs/004-fix-zuraffa-gen/tdd/test-list.md:83): the banner is an
    // unrecognized marker in a section that is already off — benign under
    // the legacy walk, and it must stay benign (no phantom sections, no
    // changed rows) under the fence-aware one.
    final dir = await seed('''
## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | unit row | FR-001 | PENDING |

## Baseline Cycle Log Entry

```
## Baseline (2026-08-26, commit 614e648)
- Fast suite: 1552 pass, 1 fail
- PENDING: A1-A12, U3-U11
```
''');

    final rows = await TestListReader(dir).read();

    expect(rows.map((r) => r.id), ['U1']);
    expect(rows.single.kind, BehaviorKind.unit);
  });

  test(
    '1575: a malformed row after a fence reports its honest line number',
    () async {
      // Line accounting parity: the fence-aware walk reconstructs the
      // original line sequence (the splitter consumes the `## ` boundary
      // separators), so the line-naming error contract (bug #984) stays
      // byte-identical for rows that sit after a fenced example.
      final dir = await seed(
        [
          '## Inner loop: unit behaviors',
          '',
          '```dart',
          '## Inner loop: unit behaviors',
          '```',
          '',
          '| U2 | six column row | FR-002 | banana | PENDING |  |',
          '',
        ].join('\n'),
      );

      await expectLater(
        TestListReader(dir).read(),
        throwsA(
          isA<TestListReadException>().having(
            (e) => e.message,
            'message',
            // Exact wording pinned: line 7 of the fixture above.
            'test-list.md line 7: expected 4 columns '
                '(id/behavior/traces/state), found 6: '
                '"| U2 | six column row | FR-002 | banana | PENDING |  |"',
          ),
        ),
      );
    },
  );

  test(
    '1575: a multi-section file re-anchors the absolute line numbers',
    () async {
      // The single-section fixture above pins the trivial reconstruction
      // path. A file whose splitter cuts at more than one real header must
      // re-anchor the absolute numbering after EVERY cut, so the #984
      // contract is only pinned once that shape is covered too. Both
      // fixtures report the malformed row's literal line — byte-identical
      // to the legacy `split('\n')` walk.
      Future<String> messageOf(List<String> lines) async {
        final dir = await seed(lines.join('\n'));
        try {
          await TestListReader(dir).read();
        } on TestListReadException catch (e) {
          return e.message;
        }
        fail('expected a TestListReadException');
      }

      // Header (1) / fence (3-6) / header (8) — the malformed row is on 9.
      expect(
        await messageOf([
          '## Inner loop: unit behaviors',
          '',
          '```dart',
          '// usage example — the fenced banner is body, never a header',
          '## Inner loop: unit behaviors',
          '```',
          '',
          '## Outer loop: acceptance behaviors',
          '| A1 | six column row | US1.AC1 | banana | PENDING |  |',
          '',
        ]),
        'test-list.md line 9: expected 4 columns '
        '(id/behavior/traces/state), found 6: '
        '"| A1 | six column row | US1.AC1 | banana | PENDING |  |"',
      );

      // Title (1) / header (3) / fence (5-7) / header (9) — the malformed
      // row is on 11.
      expect(
        await messageOf([
          '# Test List: 090-fixture',
          '',
          '## Inner loop: unit behaviors',
          '',
          '```dart',
          '## Inner loop: unit behaviors',
          '```',
          '',
          '## Outer loop: acceptance behaviors',
          '',
          '| A1 | six column row | US1.AC1 | banana | PENDING |  |',
          '',
        ]),
        'test-list.md line 11: expected 4 columns '
        '(id/behavior/traces/state), found 6: '
        '"| A1 | six column row | US1.AC1 | banana | PENDING |  |"',
      );
    },
  );

  // -------------------------------------------------------------------
  // Disclosed delta: only a `## ` line at column 0 opens a section.
  // -------------------------------------------------------------------

  test('1575: a non-column-0 header stays body', () async {
    // The legacy walk trimmed the line before matching, so a 1–3-space- or
    // tab-indented `## Key entities` opened a section; the splitter only
    // cuts at column 0, so those lines are body now. Corpus audit: 0 of 161
    // committed test-lists write either shape — pinned here so the delta is
    // locked rather than implicit.
    final dir = await seed(
      [
        '## Inner loop: unit behaviors',
        '',
        '| U1 | before the indented header | FR-001 | PENDING |',
        '',
        '  ## Key entities',
        '',
        '| U2 | after the indented header | FR-002 | PENDING |',
        '',
        '\t## Key entities',
        '',
        '| U3 | after the tab-indented header | FR-003 | PENDING |',
        '',
      ].join('\n'),
    );

    final reader = TestListReader(dir);

    // Neither indented line opened the declarative section, so all three
    // rows stay real unit behaviors instead of being swallowed as entity
    // declarations.
    final rows = await reader.read();
    expect(rows.map((r) => r.id), ['U1', 'U2', 'U3']);
    expect(rows.every((r) => r.kind == BehaviorKind.unit), isTrue);

    // The same delta seen through the entity reader: no section was opened,
    // so no behaviour row is mis-read as a declared entity.
    expect(await reader.readEntities(), isEmpty);
  });

  test(
    '1575: a byte-0 tab-indented header still resolves (legacy parity)',
    () async {
      // The chunk-0 first line keeps the legacy `trim()` semantics, so a
      // tab-indented header at byte 0 still resolves — the delta above only
      // covers non-column-0 headers after it.
      final dir = await seed(
        [
          '\t## Inner loop: unit behaviors',
          '',
          '| U1 | row under a byte-0 tab-indented header | FR-001 | PENDING |',
          '',
        ].join('\n'),
      );

      final rows = await TestListReader(dir).read();

      expect(rows.single.id, 'U1');
      expect(rows.single.kind, BehaviorKind.unit);
    },
  );
}
