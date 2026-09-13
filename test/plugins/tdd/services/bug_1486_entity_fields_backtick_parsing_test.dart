// Issue #1486 — `SpecParser.parseKeyEntities` parsed ONLY backticked
// `` `name: Type` `` pairs (`_fieldPair`, spec_parser.dart). A Key
// Entities row declaring fields in perfectly readable prose —
// `| Task | id: String, title: String, isCompleted: bool, createdAt:
// String | purpose |` — parsed into a `SpecEntity` with ZERO fields,
// silently. Phase-0 then generated a field-less entity and the first
// signal was a vacuous-green 28 minutes into the run.
//
// Fix under test (bug 1486-entity-fields-backtick-parsing):
//   B1 — a 3-column table row with plain `name: Type` pairs parses all
//        its fields (the issue's exact repro).
//   B2 — the 2-column table (#1381) accepts plain pairs too.
//   B3 — a mixed cell (backticked + plain) parses both, in source order.
//   B4 — guard: the backticked grammar is unchanged (backwards compat).
//   B5 — generic types with top-level commas (`Map<String, int>`,
//        `List<List<int>>`) survive the plain-pair split.
//   B6 — nullable types (`String?`) parse as plain pairs.
//   B7 — positive-evidence-empty: a fields cell that SHOWS pair
//        evidence (a backtick span or an `identifier:` shape) but still
//        parses to zero fields is reported, never silent.
//   B8 — guard: bullet prose keeps the strict backticked-only grammar
//        (plain prose must NOT invent fields).

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

const threeColumnPlainSpec = '''
**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Task | id: String, title: String, isCompleted: bool, createdAt: String | the unit of work |
''';

const twoColumnPlainSpec = '''
## Key Entities

| Entity | Fields |
| ------ | ------ |
| Login | id: String, username: String, token: String |
''';

const mixedCellSpec = '''
## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Session | `id: String`, token: String, refreshedAt: DateTime | the session identity |
''';

const backtickedGuardSpec = '''
## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Login | `id: String`, `username: String` | the session identity |
''';

const genericsPlainSpec = '''
## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Report | meta: Map<String, int>, rows: List<List<int>>, owner: String | aggregates |
''';

const nullablePlainSpec = '''
## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Profile | nickname: String?, bio: String | the user profile |
''';

const evidenceEmptySpec = '''
## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Task | 1id: String | the unit of work |
| Note | — | free-form |
| Config | `host: String` | runtime knobs |
| Ping | `see the docs` | prose in a backtick |
''';

const bulletGuardSpec = '''
## Key Entities

- **Task**: carries the work item with `id: String`, `title: String`
- **Note**: free prose about the note entity, see docs for details
''';

void main() {
  test('B1: a 3-column row with plain pairs parses all fields (#1486)', () {
    final entities = const SpecParser().parseKeyEntities(threeColumnPlainSpec);
    expect(entities, hasLength(1), reason: entities.toString());
    expect(entities.single.name, 'Task');
    expect(entities.single.fields.map((f) => f.name), [
      'id',
      'title',
      'isCompleted',
      'createdAt',
    ], reason: 'plain prose pairs must not be silently dropped');
    expect(entities.single.fields.map((f) => f.type), [
      'String',
      'String',
      'bool',
      'String',
    ]);
    expect(entities.single.purpose, 'the unit of work');
  });

  test('B2: the 2-column table accepts plain pairs (#1486 + #1381)', () {
    final entities = const SpecParser().parseKeyEntities(twoColumnPlainSpec);
    expect(entities, hasLength(1), reason: entities.toString());
    expect(entities.single.name, 'Login');
    expect(entities.single.fields.map((f) => f.name), [
      'id',
      'username',
      'token',
    ], reason: 'the 2-col grammar must not lose plain pairs');
  });

  test('B3: a mixed cell parses backticked and plain pairs in order', () {
    final entities = const SpecParser().parseKeyEntities(mixedCellSpec);
    expect(entities, hasLength(1), reason: entities.toString());
    expect(entities.single.name, 'Session');
    expect(entities.single.fields.map((f) => f.name), [
      'id',
      'token',
      'refreshedAt',
    ], reason: 'mixed grammar keeps source order');
    expect(entities.single.fields.first.type, 'String');
    expect(entities.single.fields[2].type, 'DateTime');
  });

  test('B4: guard — the backticked grammar is unchanged', () {
    final entities = const SpecParser().parseKeyEntities(backtickedGuardSpec);
    expect(entities, hasLength(1));
    expect(entities.single.name, 'Login');
    expect(entities.single.fields.map((f) => f.name), [
      'id',
      'username',
    ], reason: 'backwards compatibility: backticks keep working');
    expect(entities.single.purpose, 'the session identity');
  });

  test('B5: generic types with commas survive the plain-pair split', () {
    final entities = const SpecParser().parseKeyEntities(genericsPlainSpec);
    expect(entities, hasLength(1), reason: entities.toString());
    expect(entities.single.fields.map((f) => f.name), [
      'meta',
      'rows',
      'owner',
    ], reason: 'commas nested in <...> are not pair separators');
    expect(entities.single.fields.map((f) => f.type), [
      'Map<String, int>',
      'List<List<int>>',
      'String',
    ]);
  });

  test('B6: nullable types parse as plain pairs', () {
    final entities = const SpecParser().parseKeyEntities(nullablePlainSpec);
    expect(entities, hasLength(1), reason: entities.toString());
    expect(entities.single.fields.map((f) => f.name), ['nickname', 'bio']);
    expect(entities.single.fields.first.type, 'String?');
  });

  test('B7: evidence-but-zero-fields cells are reported, never silent', () {
    final anomalies = <SpecEntityFieldAnomaly>[];
    final entities = const SpecParser().parseKeyEntities(
      evidenceEmptySpec,
      anomalies: anomalies,
    );
    expect(entities, hasLength(4), reason: entities.toString());
    expect(
      anomalies.map((a) => a.entity),
      ['Task', 'Ping'],
      reason:
          '`1id: String` shows an identifier: shape; `see the docs` shows a '
          'backtick span — both are positive evidence of declared pairs '
          'that strict parsing dropped. `Note` (—) carries no evidence and '
          '`Config` parsed 1 field, so neither is anomalous.',
    );
    expect(anomalies[0].cell, '1id: String');
    expect(anomalies[0].line, 5, reason: '1-based spec line of the row');
    expect(
      anomalies[1].cell,
      '`see the docs`',
      reason: 'the anomaly quotes the cell verbatim',
    );
    expect(anomalies[1].line, 8);
  });

  test('B9: entityFieldNamesFromDartSource reads the on-disk entity shape', () {
    const source = '''
class Task {
  final String id;
  final Map<String, int> counters;
  late final String lazy;

  const Task({required this.id});

  void touch() {
    final local = 'not a field';
  }
}
''';
    expect(
      SpecParser.entityFieldNamesFromDartSource(source),
      ['id', 'counters', 'lazy'],
      reason:
          'final members are the entity shape; constructor params and '
          'method locals (assignment-initialised) are not fields',
    );
  });

  test('B8: guard — bullet prose keeps the strict backticked-only grammar', () {
    final entities = const SpecParser().parseKeyEntities(bulletGuardSpec);
    expect(entities, hasLength(2), reason: entities.toString());
    expect(entities[0].fields.map((f) => f.name), [
      'id',
      'title',
    ], reason: 'backticked bullet pairs keep parsing');
    expect(
      entities[1].fields,
      isEmpty,
      reason:
          'plain bullet prose must NOT invent fields (false-positive guard '
          '— only table cells carry the pair evidence covenant)',
    );
  });
}
