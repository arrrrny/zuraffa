# Implementation Plan: `zfa tdd run`

**Branch**: `049-tdd-run` | **Date**: 2026-08-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/049-tdd-run/spec.md`

## Summary

Implement `zfa tdd run <feature>` — the resumable loop driver (epic 045
precondition 4/5; 041 Phase 10, T070-T076). The driver reads the feature's
`tdd/test-list.md`, walks each behavior through `gen → verify-red → make →
refactor` as CLI sub-processes consumed via their summary-line/exit-code
contracts, persists `RunState` to `tdd/run-state.json` after every step, and
stops honestly on any step failure. Evidence beats state: DONE requires
red+green entries in the cycle log, not a state-file claim.

## Technical Context

**Language/Version**: Dart 3 (repo SDK), CLI plugin architecture
(`package:args/command_runner.dart`).

**Primary Dependencies**: existing internals — `run_state.dart` (model
exists; add load/save), `behavior.dart`, `cycle_log.dart` (evidence reads),
`verify_red_command.dart`'s cycle-log parsing pattern, `bin/zfa.dart`
self-spawn pattern from `test/helpers/run_zfa_source.dart`. No new pub
dependencies.

**Storage**: `specs/<feature>/tdd/run-state.json` (read/write),
`cycle-log.md` (read evidence), `test-list.md` (read).

**Testing**: fast unit tier for services; `@Tags(['slow'])` subprocess
driver tests with `TddFixture` extensions (test-list seeding, run-state
seeding, green evidence).

**Target Platform**: macOS/Linux CLI.

**Project Type**: CLI plugin command.

**Performance Goals**: sequential execution; step subprocess startup
dominates. No added constraints.

**Constraints**: never edits test/source files itself; steps are
sub-processes (crash isolation); misfire-stop on any step failure; state
writes atomic (write-temp-then-rename).

**Scale/Scope**: one command + three new services + one model extension
(~550 LOC), tests included.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled template — no
ratified gates. AGENTS.md constraints respected.

**Post-design re-check**: no violations; no new dependencies or layers.

## Project Structure

### Documentation (this feature)

```text
specs/049-tdd-run/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/
├── commands/
│   └── run_command.dart             # IMPLEMENT (currently misfire-stop stub)
├── services/
│   ├── test_list_reader.dart        # NEW — parse test-list.md (4-col plan format)
│   ├── run_state_store.dart         # NEW — atomic load/save of run-state.json,
│   │                                #   corruption + concurrent-run detection
│   ├── step_runner.dart             # NEW — spawn step sub-processes, parse
│   │                                #   summary lines, map outcomes
│   └── cycle_evidence.dart          # NEW — red/green evidence sets from
│                                    #   cycle-log.md (generalizes verify_red's
│                                    #   parsing; verify_red keeps its copy)
└── models/
    └── run_state.dart               # EXTEND — file load/save (T074), DROPPED
                                     #   retention for spec-edited behaviors

test/plugins/tdd/
├── services/
│   ├── test_list_reader_test.dart   # NEW (fast)
│   ├── run_state_store_test.dart    # NEW (fast)
│   ├── step_runner_test.dart        # NEW (fast)
│   └── cycle_evidence_test.dart     # NEW (fast)
├── run_command_test.dart            # NEW (slow)
└── scenarios/
    ├── sc_013_run_drives_feature_test.dart
    ├── sc_014_run_resumes_test.dart
    ├── sc_015_run_stops_on_failure_test.dart
    └── sc_016_run_summary_contract_test.dart
```

**Structure Decision**: existing tdd-plugin layout; scenario numbering
continues from 046 (sc_001–004) / 047 (sc_005–009) / 048 (sc_010–012).

## Complexity Tracking

No constitution violations; nothing to justify.
