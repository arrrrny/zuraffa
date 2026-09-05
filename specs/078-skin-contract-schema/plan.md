# Implementation Plan: skin-contract.v1 — Typed Model, Parser, JSON Schema Emitter

**Branch**: `078-skin-contract-schema` | **Date**: 2026-09-05 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/078-skin-contract-schema/spec.md` (issue #1164, stage 1/4 of #1111)

## Summary

Give the skin contract a typed, machine-parseable existence: a strict `SkinContract` model
in `lib/src/skin/contract/`, a parser that fails naming the offending key, a round-trip
guarantee, and a JSON Schema artifact generated FROM the model and emitted by
`zfa tdd plan` only for specs carrying `## Skin Contract:` — plus a standing test that
validates every contract-bearing spec in the repo.

## Technical Context

**Language/Version**: Dart 3.13 (stable), pure-Dart package; no Flutter in this stage

**Primary Dependencies**: existing skin module (`lib/src/skin/`: `SkinContractRow`, `TreeFacts`, `SkinTargetPlatform`); `package:test`; the tdd plan command (`lib/src/plugins/tdd/commands/plan_command.dart`, lane-split machinery, issue #1000)

**Storage**: Filesystem — schema written to `specs/<feature>/tdd/04-skin-contract.schema.json`

**Testing**: `dart test` scoped to `test/plugins/skin_contract/` and `test/plugins/tdd/`

**Target Platform**: CLI (dev machines, CI)

**Performance Goals**: parse + validate a contract in milliseconds (pure Dart, no IO in the model layer)

**Constraints**: strict parsing (unknown fields fail); schema generated from the model, never hand-edited; zero Flutter imports in this stage's code

**Scale/Scope**: one new module (~3-4 files), one plan-command hook, two test suites; emitter's first real customer is the `006-login-skin` spec

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- AGENTS.md gates: v5 fixed layout respected (new code under `lib/src/skin/` and `lib/src/plugins/tdd/`); receipts/proof conventions respected (schema is a generated artifact, deterministic regeneration like the receipts); `dart format lib test` at commit time.
- **Post-design re-check**: no violations.

## Project Structure

### Documentation (this feature)

```text
specs/078-skin-contract-schema/
├── plan.md | research.md | data-model.md | quickstart.md | contracts/ | tasks.md
```

### Source Code (repository root)

```text
lib/src/skin/contract/
├── skin_contract.dart          # typed model: routes, states, platformRows, stateRows, schemaVersion
├── skin_contract_parser.dart  # strict fromJson — errors name the offending section/key
└── skin_contract_schema.dart  # JSON Schema emitted FROM the model's shape
lib/src/plugins/tdd/commands/plan_command.dart   # emit hook: spec has `## Skin Contract:` → write schema
test/plugins/skin_contract/
├── skin_contract_parser_test.dart   # valid parse, malformed input, unknown fields, round-trip
└── schema_test.dart                 # walks every contract-bearing spec; schema-conformance + drift pins
test/plugins/tdd/plan_skin_contract_test.dart     # emitter behavioral tests (write/overwrite/no-op)
```

**Structure Decision**: extend the existing skin module (where the runtime kit already lives) rather than a new top-level surface; the plan-command hook stays inside the tdd plugin's lane-resolution flow.

## Gap Analysis (research summary — full detail in research.md)

| Question | Finding (verified in source) | Decision |
|---|---|---|
| Reuse existing skin types? | `SkinContractRow` (runtime audit row) and `SkinTargetPlatform` already exist | The contract's row/state models reference these names, not duplicate them |
| Where does the emitter hook in? | `plan_command.dart` lane resolution (issue #1000) already reads the spec and writes `tdd/04-*.md` files | Emit the schema beside the lane plan when the spec section is present |
| What does the contract JSON look like? | #1074 lineage (closed without merge) + #1111 name the sections | Define v1: `schemaVersion`, `routes`, `states`, `platformRows`, `stateRows` |
| Strict or lenient parsing? | #1111 says "asserts every required key is present"; contract drift is the enemy | Strict: unknown fields fail naming the key |

## Complexity Tracking

> No constitution violations to justify.
