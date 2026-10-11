# Tasks: zfa tdd plan reads contracts/*.md as a declared-row source

**Feature**: 1485-tdd-plan-read-contracts-directory
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Dependency-ordered, MVP-first. T = traced to the spec's success criteria.

## Phase 1 — Parser (pure, no I/O) — MVP

- [ ] T001 (P1, T→SC-001/SC-002/SC-004) RED: `test/plugins/tdd/services/spec_parser_contract_files_1485_test.dart` — `SpecParser.parseContractFileRows` extracts rows from an operations table (`| Operation | Input | Behaviour |`), a methods table with a Signature column, a signature-first table, interface bullets, pure signature bullets, `## Operations`/`## Methods` scoped lists; fenced code blocks declare nothing; prose signature cells drop; signature-shaped-but-malformed cells carry raw; `.md`-only scope is the enumeration's job (parser takes a string).
- [ ] T002 (P1, T→SC-004) RED (same file): `SpecParser.declaredContractRows(specMd, contractFiles: …)` merges spec.md rows + contract-file rows; contract-file wins on name collision (both bare and `<stem>.<row>` alias keys); spec.md-only input is byte-identical to today's map; aliases registered for every contract row.
- [ ] T003 (P1) GREEN: implement `parseContractFileRows` + `declaredContractRows` in `spec_parser.dart` (pure; reuse `normalizeSpecText`, `_fencedCodeBlock`, `_splitCells`, `Signature.parse`, `ContractRowDecl`).

## Phase 2 — Enumeration + gen-time resolution

- [ ] T004 (P2, T→SC-002) RED: enumeration + resolution tests — `DeclaredRouting.contractFiles(featureDir)` enumerates `contracts/*.md` sorted, returns `({String file, String md})` records, empty for a missing directory; `DeclaredRouting.declaredSignatureFor` resolves a `task-store.getAll` trace to the contract-file signature (temp-dir fixture).
- [ ] T005 (P2) GREEN: implement `contractFiles()` in `declared_routing.dart`; widen `declaredSignatureFor`'s declarations build to the merged map.

## Phase 3 — Plan wiring (report + warning)

- [ ] T006 (P1, T→SC-001/SC-003) RED: `test/plugins/tdd/commands/plan_command_contracts_1485_test.dart` — plan on a feature with `contracts/task-store.md` (4 rows) + `contracts/data-layer.md` (3 rows) prints `declared rows: 4 from contracts/task-store.md` + `declared rows: 3 from contracts/data-layer.md`; a traced FR routes declared (provenance unit, not fallback); empty contracts/ dir → warning; prose-only contracts/ dir → warning; NO contracts/ dir → none of the new lines.
- [ ] T007 (P1) GREEN: wire `plan_command.dart` — merge the declared-row map, print per-file report lines after the declarations gate, print the zero-rows warning.

## Phase 4 — Make wiring (declare once, resolve everywhere)

- [ ] T008 (P2, T→SC-002) GREEN (covered by T004's resolution test): wire `make_command.dart` `_declarationsFor` to the merged map.

## Phase 5 — Verify + hardening

- [ ] T009 (P2, T→SC-005) `dart analyze` clean on touched files; targeted suites green: `spec_parser_declarations_test.dart`, `routing_resolver_test.dart`, plan/make command suites.
- [ ] T010 (P3, T→SC-003) Mutation check on the parser: flip the collision order / drop the alias registration — tests must fail (test strength evidence for verification.md).

## Parallelization

- Phase 1 (T001–T003) and the T004 test authoring are independent of each other's greens; T006–T008 depend on Phase 1+2 greens. No task touches run/verify/loop files.
