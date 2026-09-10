// Issue #1485: `zfa tdd plan` reads `specs/<feature>/contracts/*.md` as a
// declared-row source. The planning phase writes structured contract
// documents (operation/method tables, method signature lists) that the
// declared-row source ignored — the author had to restate the same
// contract a second time in spec.md's grammar, with the two copies free
// to drift.
//
// These tests pin the PURE contract-file grammar
// (`SpecParser.parseContractFileRows`) and the merge helper
// (`SpecParser.declaredContractRows`): contract-file rows supplement
// spec.md rows (never replace), the contract-file version wins a name
// collision, and every contract row is additionally registered under its
// `<file-stem>.<row>` alias so `traces: <ContractFile>.<Row>` resolves.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/routing.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_parser.dart';

void main() {
  group('U-1485-1: operations/method pipe tables', () {
    test('an operations table yields one row per data row', () {
      const md = '''
# Contract: TaskStore

| Operation | Input                   | Behaviour                          |
|-----------|-------------------------|------------------------------------|
| Read all  | —                       | Returns tasks in file order        |
| Create    | a Task + placeholder id | Assigns fresh id, appends          |
| Update    | a Task                  | Replaces the stored task           |
| Delete    | an id                   | Removes the task                   |
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows, hasLength(4), reason: 'one declared row per data row');
      expect(rows.map((r) => r.name), [
        'Read all',
        'Create',
        'Update',
        'Delete',
      ]);
      expect(
        rows.every((r) => r.kind == ContractRowKind.function),
        isTrue,
        reason: 'contract-file operations declare callable operations',
      );
      expect(rows.first.specLine, 5, reason: '1-based line within the file');
    });

    test('a `| Method |` header shape works the same', () {
      const md = '''
| Method | Notes              |
|--------|--------------------|
| save   | Persists the entry |
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows, hasLength(1));
      expect(rows.single.name, 'save');
    });

    test('a methods table with a Signature column binds parsed signatures', () {
      const md = '''
| Method | Signature                    | Notes   |
|--------|------------------------------|---------|
| save   | `save(Task) -> void`         | writes  |
| find   | `find(Id) -> Task?`          | reads   |
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows, hasLength(2));
      expect(rows[0].name, 'save');
      expect(rows[0].signatures.single.toString(), 'save(Task) -> void');
      expect(rows[1].signatures.single.toString(), 'find(Id) -> Task?');
    });

    test('a signature-first table names rows by the parsed method', () {
      const md = '''
| Signature                  | Notes     |
|----------------------------|-----------|
| `getAll() -> List<Task>`   | file order |
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows, hasLength(1));
      expect(rows.single.name, 'getAll');
      expect(
        rows.single.signatures.single.toString(),
        'getAll() -> List<Task>',
      );
    });

    test('prose in a signature column is dropped, malformed signature-shaped '
        'cells carry raw', () {
      const md = '''
| Method | Signature                  |
|--------|----------------------------|
| ok     | `ok(int) -> bool`          |
| prose  | just writes the thing      |
| broken | `(int) ->`                 |
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows, hasLength(3));
      expect(rows[0].signatures, hasLength(1));
      expect(rows[0].rawSignatures, isEmpty);
      expect(
        rows[1].signatures,
        isEmpty,
        reason: 'plain prose is not a signature',
      );
      expect(rows[1].rawSignatures, isEmpty);
      expect(
        rows[2].rawSignatures,
        hasLength(1),
        reason:
            'signature-shaped but unparseable: carried raw so the '
            'resolver names it when consulted',
      );
    });
  });

  group('U-1485-3: signature lists and section scoping', () {
    test('interface bullets declare a row with all parsed signatures', () {
      const md = '''
## Methods

- `TaskStore`: `create(Task) -> Task`, `getAll() -> List<Task>`
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows, hasLength(1));
      expect(rows.single.name, 'TaskStore');
      expect(rows.single.signatures.map((s) => s.toString()), [
        'create(Task) -> Task',
        'getAll() -> List<Task>',
      ]);
    });

    test('a pure signature bullet declares a row named by the method', () {
      const md = '''
## Operations

- `completeAll() -> int`
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows, hasLength(1));
      expect(rows.single.name, 'completeAll');
      expect(rows.single.signatures.single.toString(), 'completeAll() -> int');
    });

    test('within an Operations/Methods section a signature bullet may carry '
        'trailing prose', () {
      const md = '''
## Methods

- `count() -> int` — the number of stored tasks
- `--flag` — not a method at all
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows, hasLength(1));
      expect(rows.single.name, 'count');
    });

    test('outside a Methods section only PURE signature bullets count', () {
      const md = '''
- `count() -> int` — trailing prose outside scope is not a declaration
- `pure() -> bool`
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows.map((r) => r.name), ['pure']);
    });

    test('fenced code blocks are documentation and declare nothing', () {
      const md = '''
# Contract

```markdown
| Operation | Behaviour      |
|-----------|----------------|
| Fenced    | declares nada  |

- `fenced() -> void`
```

| Operation | Behaviour     |
|-----------|---------------|
| Real      | declares one  |
''';
      final rows = const SpecParser().parseContractFileRows(md);
      expect(rows.map((r) => r.name), [
        'Real',
      ], reason: 'the fenced example is docs; line numbers stay accurate');
    });

    test('a document with no operations/methods/signatures yields nothing', () {
      const md = '''
# Contract: CLI

Some CLI flags:

- `--target` — the corpus target being walked
- `--project` — the driven app's root

| Path | Written by | Role |
|------|-----------|------|
| `x.json` | catalog | the walk's input contract |
''';
      expect(const SpecParser().parseContractFileRows(md), isEmpty);
    });
  });

  group('U-1485-4: declaredContractRows merge + collision policy', () {
    const specMd = '''
**Template Version**: `zuraffa-1.0`

## Layer Contracts

**Domain**:
- `TaskStore`: `specOnly() -> bool`

## Key Entities

| Entity | Fields | Purpose |
| ------ | ------ | ------- |
| Task   | `id: String`, `title: String` | the stored unit |
''';

    test('spec.md-only input equals the legacy map', () {
      final legacy = {
        for (final r in const SpecParser().parseContractRows(specMd)) r.name: r,
      };
      final merged = SpecParser.declaredContractRows(specMd);
      expect(merged.rows.keys, legacy.keys);
      expect(merged.perFile, isEmpty);
      expect(
        merged.rows['TaskStore']!.signatures.single.toString(),
        legacy['TaskStore']!.signatures.single.toString(),
        reason: 'the same declared rows feed the resolver',
      );
    });

    test('contract-file rows supplement spec.md rows under both keys', () {
      const contract = '''
| Operation | Behaviour |
|-----------|-----------|
| Create    | appends   |
''';
      final merged = SpecParser.declaredContractRows(
        specMd,
        contractFiles: [(file: 'task-store.md', md: contract)],
      );
      expect(merged.perFile, {'task-store.md': 1});
      expect(
        merged.rows.containsKey('Create'),
        isTrue,
        reason: 'the bare row name resolves',
      );
      expect(
        merged.rows.containsKey('task-store.Create'),
        isTrue,
        reason: 'the <ContractFile>.<Row> alias resolves',
      );
      expect(
        identical(merged.rows['Create'], merged.rows['task-store.Create']),
        isTrue,
      );
      expect(
        merged.rows['TaskStore']!.signatures.single.toString(),
        'specOnly() -> bool',
        reason: 'the spec.md row is untouched (supplement, not replacement)',
      );
    });

    test('a colliding name resolves to the contract-file row', () {
      const contract = '''
## Methods

- `TaskStore`: `contractFileOnly() -> int`
''';
      final merged = SpecParser.declaredContractRows(
        specMd,
        contractFiles: [(file: 'task-store.md', md: contract)],
      );
      final winner = merged.rows['TaskStore']!;
      expect(
        winner.signatures.single.toString(),
        'contractFileOnly() -> int',
        reason:
            'the contract-file version wins: more structured, produced '
            'by the planning workflow',
      );
    });
  });

  group('U-1485-7: deterministic multi-file merge', () {
    test('two files declaring the same name: the sorted-later file wins', () {
      const a = '''
| Operation | Behaviour |
|-----------|-----------|
| Create    | from a    |
''';
      const b = '''
| Operation | Behaviour |
|-----------|-----------|
| Create    | from b    |
''';
      final merged = SpecParser.declaredContractRows(
        '',
        contractFiles: [
          (file: 'b-later.md', md: b),
          (file: 'a-first.md', md: a),
        ],
      );
      // The enumeration is the caller's (sorted) responsibility; given both
      // documents, the LAST one in the list wins — deterministic last-wins.
      expect(merged.perFile, {'b-later.md': 1, 'a-first.md': 1});
      expect(merged.rows['Create'], isNotNull);
      expect(
        merged.rows['a-first.Create']!.name,
        'Create',
        reason: 'each file keeps its own alias binding',
      );
    });
  });
}
