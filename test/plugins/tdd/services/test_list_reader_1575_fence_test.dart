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
}
