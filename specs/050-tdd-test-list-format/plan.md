# Implementation Plan: TDD plan↔gen test-list format contract

**Branch**: `050-tdd-test-list-format` | **Date**: 2026-08-31 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/050-tdd-test-list-format/spec.md`
(seed: GitHub issue #617)

## Summary

Make the 4-column `zfa tdd plan` test-list format THE contract for the whole
TDD loop, and finish the migration path for hand-written 6-column fixtures.
The core unification — `zfa tdd gen` consuming the shared `TestListReader`,
plan's 4-column shape canonical, a one-release compat shim for 6-column rows
whose kind cell is `acceptance`/`unit`, and the slow-tier plan→run loop e2e —
landed on master as commit `74c132db` (bug #617 remediation via the
`.specify/bugs/` path). What this feature adds is what that commit left open
and the issue explicitly flags: the repo's OWN hand-written 6-column lists
(specs/044–049, kind cell = the extension's test shapes `example`, …) are
still rejected as malformed — `zfa tdd run 049-tdd-run` exits
`result=runner-error` on list-reading today. This feature completes the shim
(extension-dialect rows accepted for one release, kind from the section
header, test-reference cell → default target, one-time deprecation note),
keeps the misfire-stop for genuinely unknown shapes, and pins the whole
contract — canonical round trip, both 6-column dialects, and the exact
plan→run repro — in the fast and slow test tiers.

## Technical Context

**Language/Version**: Dart 3.13+ (repo pins `sdk: ^3.11.0`; installed toolchain
Dart 3.13.2 stable). The repo is a pure-Dart root package — a Flutter 3.47+
toolchain is NOT required to build, test, or run it; Flutter appears only as
the upper companion toolchain the zuraffa project templates target.

**Primary Dependencies**: existing internals — `zfa tdd plan` /
`zfa tdd gen` / `zfa tdd run` commands (`lib/src/plugins/tdd/commands/`),
the shared `TestListReader`
(`lib/src/plugins/tdd/services/test_list_reader.dart`), `BehaviorRow` /
`Behavior` models, the generation pipeline (`BehaviorTestWriter`,
`SubjectWriter`, `GenerationPlanner`), and the `CliRunner` in-process test
entry point. No new pub dependencies.

**Storage**: `specs/<feature>/tdd/test-list.md` (read-only for every loop
consumer), `tdd/cycle-log.md` (evidence), `tdd/run-state.json` (run state).

**Testing**: `dart test` fast tier for reader/contract units
(`test/plugins/tdd/services/`, `test/plugins/tdd/commands/`);
`@Tags(['slow', 'integration'])` loop e2e in
`test/plugins/tdd/scenarios/` (real temp project + real pipeline via the
pure-exec forwarder to `bin/zfa.dart`).

**Target Platform**: macOS/Linux CLI (pure Dart).

**Project Type**: CLI plugin command + shared service (format contract).

**Performance Goals**: parse cost is negligible (one file, line scan);
no added constraints.

**Constraints**: the reader stays read-only (FR-010 — no file rewriting or
auto-migration); malformed rows stop the caller with the named line
(FR-005/FR-011 misfire-stop — format drift is surfaced, never silently
skipped, per specs/049-tdd-run research Decision 5); the shim is time-boxed
to one release; `dart analyze` and `dart format` must stay clean.

**Scale/Scope**: one service extension (`TestListReader._parseDataRow` —
one new accepted 6-column shape + kind-from-section rule), one existing
unit-test file updated to the new contract, new reader/gen/run coverage
(~250 test LOC, ~30 source LOC).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unfilled template — no ratified
gates. AGENTS.md constraints respected: no new dependencies, no new layers,
test-first, honest stops.

**Post-design re-check**: no violations — one parser gains one accepted
input shape; nothing else changes shape.

## Project Structure

### Documentation (this feature)

```text
specs/050-tdd-test-list-format/
├── plan.md              # This file
├── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
├── checklists/
│   └── requirements.md  # spec quality checklist (/speckit-specify output)
└── tdd/
    ├── test-list.md     # /speckit-tdd-plan output (behaviors + traces)
    ├── cycle-log.md     # append-only red/green evidence (/speckit-tdd-run)
    └── verification.md  # cold-context audit (/speckit-tdd-verify)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── commands/
│   ├── plan_command.dart            # UNCHANGED — 4-col writer stays canonical
│   ├── gen_command.dart             # UNCHANGED — already consumes the reader
│   └── run_command.dart             # UNCHANGED — already consumes the reader
└── services/
    └── test_list_reader.dart        # EXTEND — accept extension-dialect 6-col
                                     #   rows (kind from section header, test
                                     #   cell → default target, deprecation
                                     #   note); keep named-line misfire-stop

test/plugins/tdd/
├── services/
│   └── test_list_reader_test.dart   # EXTEND — new shim coverage; re-point the
                                     #   U3 malformed case at a truly unknown
                                     #   shape
├── commands/
│   └── plan_gen_contract_test.dart  # EXTEND — gen round trip on a hand-written
                                     #   extension-dialect list
└── scenarios/
    └── sc_018_plan_run_loop_e2e_test.dart
                                     # UNCHANGED — the plan→run front door (already
                                     #   pins the canonical contract; slow tier)
```

**Structure Decision**: single-project layout (repo default). The change is
confined to the one shared service and its tests — the contract's point is
that no other file may grow a parser again.

## Complexity Tracking

> No constitution violations to justify — table left empty by design.
