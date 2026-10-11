# Implementation Plan: zfa tdd plan reads contracts/*.md as a declared-row source — declare once, resolve everywhere

**Branch**: `feat/1485-read-contracts-directory` | **Date**: 2026-09-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1485-tdd-plan-read-contracts-directory/spec.md`

## Summary

`zfa tdd plan` ignores `specs/<feature>/contracts/*.md` — the structured
contract documents the spec-kit planning phase writes. Declared rows are
sourced only from spec.md sections (`## Layer Contracts`, `## Key
Entities`, `## External Dependencies & Contracts`), so the author must
restate the same contract a second time in a different grammar, with the
two copies free to drift (issue #1485; `corpus_catalog.dart:183` merely
recognizes `contracts` as a subdirectory name without reading it). Fix
shape: a new PURE contract-file parser (`SpecParser.parseContractFileRows`)
extracts declared rows from operation/method tables and signature lists; a
pure merge helper (`SpecParser.declaredContractRows`) builds the
declared-row map from spec.md + the contract files with the collision
policy contract-file-wins; the enumeration helper lives beside the
existing file-reading declaration plumbing (`DeclaredRouting.contractFiles`)
and the three declaration builders (plan, make `_declarationsFor`,
`DeclaredRouting.declaredSignatureFor`) feed the merged map to the
UNCHANGED `RoutingResolver`. Plan reports what it read
(`declared rows: 4 from contracts/task-store.md`) and warns when the
directory exists but yields nothing.

## Technical Context

**Language/Version**: Dart 3.13 stable (pubspec `sdk: ^3.11.0`), pure-Dart root package

**Primary Dependencies**: `package:test`, `package:path` — the TDD plugin lives under `lib/src/plugins/tdd/`; `SpecParser` stays pure (string-in, rows-out)

**Storage**: none new — reads `specs/<feature>/contracts/*.md` at plan/gen time; all existing evidence artifacts unchanged

**Testing**: `dart test` (per `.specify/memory/tdd-profile.md`); feature scope `dart test test/plugins/tdd/`; analysis `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`

**Target Platform**: CLI (macOS/Linux/Windows dev machines)

**Project Type**: CLI code generator (zuraffa) with a spec-kit TDD extension

**Performance Goals**: one directory listing + one read per contract file per plan/gen — sub-50ms for the documented corpus

**Constraints**: routing resolver API unchanged; run/verify/make/loop semantics unchanged (make's `_declarationsFor` and `declaredSignatureFor` only widen their INPUT map — the declared rows the issue requires resolvable everywhere); spec.md parsing untouched

**Scale/Scope**: 3 source files touched (`spec_parser.dart`, `declared_routing.dart`, `plan_command.dart`, `make_command.dart` — parser + plumbing + two wiring sites) + tests; no CLI surface change beyond plan's new report/warning lines

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`.specify/memory/constitution.md`) is the unfilled
spec-kit template — no project-specific gates are declared. The repo's
operative contracts this plan must honor (from AGENTS.md and the code's own
documented invariants):

- **Test-first**: every behavior lands red-first (the test list below drives a red→green loop).
- **Errors-are-an-API**: a contracts/ directory that yields nothing is named loudly (the warning), never silently skipped — the issue names silence as the defect.
- **Pure parser**: `SpecParser` methods take strings and return rows; the filesystem enumeration stays in the command-side plumbing (`DeclaredRouting`), the seam the codebase already drew for declared-intent routing.
- **Supplement, not replacement**: spec.md rows keep winning nothing they had; the only override is the documented collision policy (contract-file wins).

**Verdict**: PASS (no violations).

## Project Structure

### Documentation (this feature)

```text
specs/1485-tdd-plan-read-contracts-directory/
├── plan.md              # This file
├── spec.md              # Feature specification (measurable success criteria)
├── tasks.md             # Phase 2 output (/speckit.tasks)
└── tdd/
    └── test-list.md     # /speckit.tdd.plan output — one behavior per line
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── services/
│   ├── spec_parser.dart          # + parseContractFileRows, declaredContractRows (PURE)
│   └── declared_routing.dart     # + contractFiles() enumeration; declaredSignatureFor widened
└── commands/
    ├── plan_command.dart         # declarations build merged + report/warning lines
    └── make_command.dart         # _declarationsFor merged (gen-time resolution)

test/plugins/tdd/
├── services/
│   └── spec_parser_contract_files_1485_test.dart   # parser + merge + enumeration behaviors
└── commands/
    └── plan_command_contracts_1485_test.dart       # plan report/warning/collision e2e
```

**Selectors** (the exact seams, verified on the current tree):
- `plan_command.dart:593-600` — `declarations = SpecDeclarations(contractRows: {for (final r in const SpecParser().parseContractRows(specMd)) r.name: r, ...})`
- `make_command.dart:1684-1697` — `_declarationsFor(featureDir)` builds the same map for gen
- `declared_routing.dart:66-70` — `declaredSignatureFor` rebuilds the same map per call
- `routing_resolver.dart:405-417` — `_resolveToken`: exact name, then `<row>.<method>` prefix (unchanged; the alias keys make `<file-stem>.<row>` hit the exact branch)

## Decision Log

- **D1 — contract-file rows carry the `function` kind.** An operations contract declares callable operations; `function` routes the unit lane with the plain-function surface and the full signature-resolution ladder (#1259 made domain/data rows carry subject signatures; function rows have it natively). Name-only rows still bind their trace (declared unit) — the #1485 repro's 42 fallback-routing behaviors become declared. Escape hatches (`**Type**` markers, spec.md rows) stay untouched for other lanes.
- **D2 — `<file-stem>.<row>` alias keys.** The resolver's first-dot prefix form resolves `<row>.<method>`; for `<contract-file>.<method>` traces (the issue's `traces: <ContractFile>.<Method>` form) each contract-file row is ALSO registered under `<file-stem>.<row>` so the exact-match branch hits. Aliases are resolution keys, not extra rows — the report counts extracted rows only.
- **D3 — lenient signature cells, loud when consulted.** A signature-column cell or bullet span that parses (`name(Params) -> Return`) becomes a declared signature; a span shaped like a signature but failing to parse is carried raw (the resolver's malformed-declaration refusal names it when the row is consulted); plain prose is dropped. Spec.md FUNCTION rows keep their stricter parse-time refusal — contract files are planning-phase artifacts, the author already moved on by the time plan reads them.
- **D4 — the warning keys on the directory, not per file.** `contracts/` absent → silent (FR-007, byte-identical output). Directory present but zero extracted rows across all files → ONE warning naming the directory and the expected grammar. Files that yield rows report individually.
- **D5 — corpus_catalog.dart needs no change.** Its `contracts` token (line 183) is a CORE/SKIN classifier word-signal over spec.md content, not a directory reader; the issue's citation points at the symptom, the fix is the declared-row source.

## Gate Review

| Gate | Verdict |
|------|---------|
| Routing resolver API unchanged | PASS — rows in, decisions out; no signature change |
| run/verify/make/loop semantics unchanged | PASS — only the declared-row INPUT map widens; no command flow, exit-code, or artifact-shape change |
| Zero-contracts features byte-identical | PASS — enumeration returns empty for a missing directory; merge is a no-op; no output lines without the directory |
| Pure parser seam preserved | PASS — `parseContractFileRows(String) -> List<ContractRowDecl>`; I/O stays in `DeclaredRouting` |
