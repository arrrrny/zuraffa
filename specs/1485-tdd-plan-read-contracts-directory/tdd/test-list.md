# Test List: 1485-tdd-plan-read-contracts-directory

Derived from spec.md + plan.md (speckit.tdd.plan). Every behavior gets a
failing test BEFORE its implementation lands (red-green-refactor).

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-1485-1 | plan on a feature whose `contracts/` holds `task-store.md` (an operations table with 4 rows) and `data-layer.md` (a method signature list with 3 rows) prints `declared rows: 4 from contracts/task-store.md` and `declared rows: 3 from contracts/data-layer.md` — plan reports what it read, no silence (FR-001, FR-003; SC-001) | FR-001, FR-003 | GREEN |
| A-1485-2 | an FR whose block carries `traces: task-store.Create` routes DECLARED on a feature whose only declaration of that row is the contract file — the resolver binds the contract-file row (unit lane, no fallback provenance) (FR-002; SC-002) | FR-002 | GREEN |
| A-1485-3 | plan on a feature with NO `contracts/` directory emits none of the new lines (no report, no warning) — output contract unchanged (FR-007; SC-003) | FR-007 | GREEN |
| A-1485-4 | plan on a feature whose `contracts/` directory exists but holds no parseable rows (empty dir / prose-only docs) emits a warning naming the directory and the expected grammar (FR-003; SC-003) | FR-003 | GREEN |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1485-1 | `parseContractFileRows` extracts a row per data row of a pipe table whose header's first cell is `Operation` or `Method` (case-insensitive), name = first cell, kind = function (FR-008) | FR-008 | GREEN |
| U-1485-2 | a table with a `Signature` column binds each cell's parseable `name(Params) -> Return` spans as the row's declared signatures; a signature-first table (`| Signature | … |`) names rows by the parsed signature's method; plain prose cells are dropped; signature-shaped-but-unparseable cells carry raw (FR-008) | FR-008 | GREEN |
| U-1485-3 | interface bullets (`` - `Name`: `sig`, `sig` ``) declare a row per bullet with all parsed signatures; pure signature bullets (`` - `sig` ``) declare a row named by the method; bullets inside `## Operations`/`## Methods` sections tolerate trailing prose; fenced code blocks declare nothing (FR-008) | FR-008 | GREEN |
| U-1485-4 | `declaredContractRows` merges spec.md rows + contract-file rows: a colliding name resolves to the CONTRACT-FILE row; every contract row is additionally registered under `<file-stem>.<row>`; spec.md-only input equals today's map byte-for-byte (FR-004, FR-005; SC-004) | FR-004, FR-005 | GREEN |
| U-1485-5 | `DeclaredRouting.contractFiles` enumerates only `contracts/*.md`, sorted by name, as `(file, md)` records; a missing `contracts/` directory yields an empty list and no error (FR-001, FR-007) | FR-001, FR-007 | GREEN |
| U-1485-6 | `DeclaredRouting.declaredSignatureFor` resolves a `task-store.getAll` trace against the contract-file row's declared signature — declare once, resolve everywhere at gen time (FR-006; SC-002) | FR-006 | GREEN |
| U-1485-7 | two contract files declaring the same row name: the sorted-later file wins (deterministic last-wins, mirroring the collision policy) (FR-005) | FR-005 | GREEN |

## Layer contracts

```yaml
# fr: FR-008, FR-004, FR-005
spec_parser.dart: parseContractFileRows (pure contract-file grammar) + declaredContractRows (merge + collision + aliases)
# fr: FR-001, FR-006, FR-007
declared_routing.dart: contractFiles() enumeration + declaredSignatureFor merged-source resolution
# fr: FR-001, FR-003
plan_command.dart: declarations build consumes the merged map; per-file `declared rows:` report + zero-rows warning
# fr: FR-006
make_command.dart: _declarationsFor consumes the merged map (gen-time resolution)
```

## Key entities

```yaml
ContractFileSource: (file, md) record — one enumerated contracts/*.md document
ContractRowDecl: reused unchanged (name, kind=function, signatures, rawSignatures, specLine)
```

## Suite entry points

- `test/plugins/tdd/services/spec_parser_contract_files_1485_test.dart`
  (new — U-1485-1..4, U-1485-7; pure parser behaviors)
- `test/plugins/tdd/services/declared_routing_contracts_1485_test.dart`
  (new — U-1485-5, U-1485-6; hermetic temp-dir fixtures)
- `test/plugins/tdd/commands/plan_command_contracts_1485_test.dart`
  (new — A-1485-1..4; runCapturing plan-command e2e per the plugin suite
  conventions)
