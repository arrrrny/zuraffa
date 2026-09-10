// Issue #1381 — `SpecParser.parseKeyEntities` matched ONLY the
// zuraffa-1.0 3-column header (`| Entity | Fields | Purpose |`); a
// pre-#919 2-column table (`| Entity | Fields |`) extracted ZERO
// entities silently, `zfa tdd plan` wrote a test list with no
// `## Key entities` section, and the run-engine cert gate passed
// trivially (core-entities=0) — the #1014 exit criterion was
// unreachable with no signal anywhere.
//
// Fix under test (spec 1381-entity-table-2col):
//   B1 — the parser extracts entities from the 2-column grammar.
//   B2 — the 3-column grammar is unchanged (guard).
//   B3 — a spec whose Key Entities section yields zero entities makes
//        plan print a warning naming the section (no more silent loss).

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

const twoColumnSpec = '''
**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields |
| ------ | ------ |
| Login | `id: String`, `username: String`, `token: String` |
''';

const threeColumnSpec = '''
**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Login | `id: String`, `username: String` | the session identity |
''';

void main() {
  test('B1: the pre-#919 2-column Key Entities table extracts entities',
      () {
    final entities = const SpecParser().parseKeyEntities(twoColumnSpec);
    expect(entities, hasLength(1), reason: entities.toString());
    expect(entities.single.name, 'Login');
    expect(
      entities.single.fields.map((f) => f.name),
      containsAll(['id', 'username', 'token']),
    );
  });

  test('B2: the 3-column grammar is unchanged (guard)', () {
    final entities = const SpecParser().parseKeyEntities(threeColumnSpec);
    expect(entities, hasLength(1));
    expect(entities.single.name, 'Login');
    expect(entities.single.purpose, 'the session identity');
  });

  test('B3: a declared-but-unparseable Key Entities section makes plan '
      'warn', () async {
    // Covered at the plan level in
    // test/plugins/tdd/commands/bug_1381_plan_warns_on_unparsed_entities_test.dart
    // (the warning is emitted by plan_command).
  });
}
