# Implementation Plan: Platform-typed acceptance scenarios are first-class SKIN lane rows

**Branch**: `1432-platform-lane-skin-plan` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1432-platform-lane-skin-plan/spec.md`

## Summary

The lane-split planner routes a scenario typed `platform` to the SKIN lane in
its route log while the emitted lane plan tables omit the row (no renderer
section carries the platform kind), so the lane reports green with
spec-derived acceptance behaviors silently untested. The fix renders
platform-kind rows in the acceptance outer-loop section of the lane plan they
are classified to (the shape the issue's own hand-edit workaround proved
end-to-end: gen → red → re-certify → run-skin green), and refuses —
errors-are-an-API — any routed behavior kind no lane section can render, so
the route log and the artifacts can never disagree again.

## Technical Context

**Language/Version**: Dart 3.x (repo SDK constraint)

**Primary Dependencies**: repo-local TDD plugin services (`plan_command`,
`lane_split`, `routing_resolver`, `spec_parser`, `test_list_reader`); `package:test`

**Storage**: N/A (the planner emits markdown plan artifacts under `specs/<feature>/tdd/`)

**Testing**: `dart test` (fast tier default; single-file `--preset=all` for
slow-tagged CLI regression rows). New tests:
`test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart` (CLI
surface, hermetic temp project) + renderer rows in the lane-split service
tests.

**Target Platform**: CLI (macOS/Linux/Windows dev machines; CI on POSIX)

**Project Type**: library/cli

**Performance Goals**: plan latency unchanged (same parse + render pass)

**Constraints**: no artifact on refusal ("an incomplete split never leaves a
half-written lane plan"); zero regression to acceptance/widget/unit/ffi
rendering (issue #830/#835 shapes pinned by existing suites)

**Scale/Scope**: one renderer filter pair + one refusal guard + tests; the
contract-kind row path is open issue #1419's scope and is deliberately
untouched

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Test-first (non-negotiable): RED rows recorded against the unfixed tree
  before the fix lands, same commit series. ✓
- Errors-are-an-API: the drop becomes either a rendered row or a refusal
  naming id/kind/criterion; never a silent omission. ✓
- No hand-written seams: the fix lives in the planner's own renderers; the
  documented hand-edit seam (04-SKIN.md rows) stays available but is no
  longer required for platform scenarios. ✓

## Project Structure

### Documentation (this feature)

```text
specs/1432-platform-lane-skin-plan/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (CLI + artifact contract)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/services/lane_split.dart      # renderEnginePlan/renderSkinPlan kind sections
lib/src/plugins/tdd/commands/plan_command.dart    # split refusal guard (kind-without-home)
test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart  # new regression suite
```

**Structure Decision**: The renderer fix lives in `lane_split.dart` (the
shared emission for `zfa tdd plan` and `zfa tdd split`); the refusal guard
lives in `plan_command.dart`'s split refusal loop (where provenance —
criterion, declared lines — is available and the refusal gate runs before any
artifact write). `zfa tdd split` inherits the rendering half through the
shared renderer; its kind heuristic keeps routing widget/theme → SKIN and is
not extended to platform (lane declaration stays the author's word).
