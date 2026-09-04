# Implementation Plan: Dependency-Table Mocks (072)

**Branch**: `072-dependency-mocks` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/072-dependency-mocks/spec.md` (issue #960)

## Summary

Consume the External Dependencies & Contracts table that mock-first currently ignores: parse each declared row's contract cell into typed signatures and its mock-priority cell into ordering, add `zfa mock dependency <Name>` (mock-plugin capability) that generates a deterministic, registry-recorded mock package (declared interface + certified scriptable fake + fixture lane) from the row alone, route behaviors tracing to a dependency row to the existing `GenerationSurface.dependencyMake` surface with the row's mock wired into the harness, order mock materialization by declared priority, and let `zfa tdd realize --adapter <Name>` arbitrate real-adapter parity against the declared contract through the existing gates.

## Technical Context

**Language/Version**: Dart 3.13 (repo pins `sdk: ^3.11.0`)
**Primary Dependencies**: package:args (CLI), core capability/plugin system (`ZuraffaCapability`), tdd plugin services
**Storage**: N/A (generated code + artifact registry JSON)
**Testing**: `dart test` (fast tier), scoped per file; `dart analyze` gate
**Target Platform**: CLI (developer machine / CI)
**Project Type**: library + CLI generator
**Performance Goals**: deterministic generation (byte-identical re-runs); no suite slowdown
**Constraints**: pure-Dart root package (generated mock content may target Flutter apps but the generator must not import Flutter)
**Scale/Scope**: 1 new capability, 1 signature-parsing extension to dependency rows, resolver + planner + loop wiring, realize parity source

## Constitution Check

- Test-first: every behavior lands red-first through `specs/072-dependency-mocks/tdd/` (loop-driven). ✅
- Errors-are-an-API: every refusal names the row/line and a `--> fix:` hint (RoutingFailureCode conventions). ✅
- Determinism: same row → byte-identical artifacts (SC-003). ✅
- Declared routing: routing decisions come from declarations only; prose never routes (FR-005 mirrors 071). ✅

## Project Structure

### Documentation (this feature)

```text
specs/072-dependency-mocks/
├── plan.md              # this file
├── research.md          # decisions + alternatives
├── data-model.md        # entities: DependencyContract, DependencyMockPlan, artifacts
├── contracts/
│   ├── cli-mock-dependency.md     # CLI surface contract
│   ├── dependency-mock-surface.md # generated artifact shape
│   └── loop-priority-order.md     # priority ordering contract
├── quickstart.md
└── tdd/                 # test-list, cycle-log, artifacts (loop-owned)
```

### Source Code (repository)

```text
lib/src/plugins/mock/capabilities/dependency_mock_capability.dart   # NEW capability
lib/src/plugins/mock/builders/dependency_mock_builder.dart          # NEW deterministic emitter
lib/src/plugins/mock/mock_plugin.dart                               # register capability
lib/src/plugins/tdd/models/routing.dart                             # ContractRowKind.service + priority
lib/src/plugins/tdd/services/spec_parser.dart                       # dependency rows: signatures + service kind + priority
lib/src/plugins/tdd/services/routing_resolver.dart                  # dependency row → dependencyMake surface + provenance
lib/src/plugins/tdd/services/generation_planner.dart                # dependencyMake planning + priority-ordered mock phase
lib/src/plugins/tdd/commands/make_command.dart                      # materialize dependency mocks in priority order
lib/src/plugins/tdd/commands/realize_command.dart                   # declared contract as parity source for dependency rows
test/plugins/mock/dependency_mock_capability_test.dart              # NEW
test/plugins/tdd/bug_960_*_test.dart                                # routing/loop/realize behaviors
```

## Key Design Decisions

1. **Rows become first-class declarations.** `spec_parser` currently maps only `storage*`/`channel*` dependency types into `ContractRowDecl` (no signatures). 072 adds `ContractRowKind.service`, parses the contract cell into `Signature`s (reusing the 071 `Signature.parse` grammar, comma-separated method list), and carries `mockPriority`. Unparseable contract cells → `malformedDeclaration` refusal naming the row (never a guessed mock).
2. **The capability generates from the declaration, not the entity.** `DependencyMockCapability` (mock plugin, name `dependency`) loads the plan/test-list declarations, resolves `<Name>`, and emits via a pure builder — the same capability/builder seam as `create`.
3. **Routing reuses 071.** A behavior's trace token matching a dependency contract row yields `surface = dependencyMake` (the surface name 071 already reserved) with provenance naming the row. No prose path exists.
4. **Priority is a declaration-driven ordering**, P1 < P2 < P3 < unprioritized, stable within tier by declaration order; the plan artifact's dependency section shows the order.
5. **Realize parity source = declared contract.** For dependency-row adapters, the contract gate loads the row's signatures and refuses drift naming the member + row.
