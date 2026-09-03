# Implementation Plan: Declared-Intent Routing (eliminate keyword-based matching)

**Branch**: `071-declared-intent-routing` | **Date**: 2026-09-03 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/071-declared-intent-routing/spec.md`

## Summary

Route behavior classification and generation exclusively from **declarations in the
spec** (scenario-type markers, contract-row traces, declared signatures, persistence
declarations) instead of semantic keyword matching over prose. The five keyword
sniffers (UI-intent lane classifier, function-verb surface selector, persistence
keywords, entity-name extraction, signature inference) are demoted to **named
fallbacks** during a migration window and removed in **strict mode**; every routing
decision emits per-behavior provenance naming the declaration (or fallback + spec
line) it consulted. Deletes the #936/#950/#920/#696-#873/#833 defect class at the
root.

## Technical Context

**Language/Version**: Dart 3.13 (stable; SDK constraint ^3.11.0)

**Primary Dependencies**: package:test (dev), package:path, package:args (CLI parsing)

**Storage**: N/A (spec/test-list artifacts are files under the target project's `specs/<feature>/`)

**Testing**: `dart test` (fast tier default; slow tiers tagged, presets in dart_test.yaml). TDD profile: `.specify/memory/tdd-profile.md`

**Target Platform**: CLI (macOS/Linux/Windows developer machines)

**Project Type**: library + CLI (pure-Dart root package, Flutter-independent)

**Performance Goals**: routing decision per behavior < 1ms (pure in-process resolution); plan command output unchanged in latency

**Constraints**: no Flutter SDK dependency; must not change behavior for existing valid specs during the fallback window (SC-005); structural grammar parsing untouched (FR-012)

**Scale/Scope**: 5 sniffers replaced across 4 service files + 2 commands; template v1.1 declarations; new routing-resolver service; provenance output; strict flag

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`.specify/memory/constitution.md`) is an unfilled template
(no ratified principles), so no project-specific gates apply. The feature is checked
against the issue's own declared principles, which the spec encodes:

- **Declared structures, not prose mining** (issue #951 principle; #919 precedent): PASS — routing reads only declared spec structure; structural grammars preserved (FR-012).
- **Errors-are-an-API** (VISION §4): PASS — conflicts, dangling references, malformed rows, and strict-mode misses refuse naming the spec line (FR-011, FR-010).
- **Test-first (TDD profile)**: PASS — the delivery runs through the red-green loop (spec-whole pipeline); profile present.

## Project Structure

### Documentation (this feature)

```text
specs/071-declared-intent-routing/
├── plan.md              # This file
├── research.md          # Phase 0 output: routing-design decisions
├── data-model.md        # Phase 1 output: declarations, decisions, provenance
├── quickstart.md        # Phase 1 output: end-to-end validation guide
├── contracts/           # Phase 1 output: CLI + template + resolver contracts
│   ├── cli-routing.md
│   ├── template-declarations.md
│   └── routing-resolver.md
└── tasks.md             # Phase 2 output (/skill:speckit-tasks)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── models/
│   └── behavior.dart                      # BehaviorKind (exists), + routing provenance record
├── services/
│   ├── spec_parser.dart                   # uiAcceptanceIntent sniffer (demote); + scenario marker/trace parsing
│   ├── generation_planner.dart            # functionIntentVerbs + entity extractors (demote); consult resolver first
│   ├── test_list_reader.dart              # PersistenceMarker.keywords (demote); + persistence declarations
│   ├── subject_signature_deriver.dart     # prose signature inference (demote); declared signatures first
│   └── routing_resolver.dart              # NEW: declaration ladder -> RoutingDecision (+ provenance)
├── commands/
│   ├── plan_command.dart                  # emit per-behavior provenance; --strict-routing
│   ├── func_command.dart                  # declared signature first, deriver as fallback
│   └── make_command.dart                  # planner already consumes kind; wire resolver reason through

test/plugins/tdd/
├── services/
│   ├── routing_resolver_test.dart         # NEW: ladder, conflicts, dangling refs, provenance
│   ├── spec_parser_declarations_test.dart # marker + contract-trace parsing
│   └── ... (existing suites keep green)
└── commands/
    └── plan_routing_provenance_test.dart  # NEW: provenance lines + strict refusal
```

**Structure Decision**: Single-project layout (existing). All work lands in the tdd
plugin's existing service/command files plus one new resolver service and its tests —
no new packages, no new top-level trees.

## Complexity Tracking

> No constitution violations to justify — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | | |
