# Plan: `tdd make` — first-class hand-step run state (issue #1568)

- **Slug**: 1568-tdd-make-hand-step-first-class
- **Branch**: `feat/1568-tdd-make-hand-step-first-class`
- **Spec**: ./spec.md

## Technical Context

- **Language/toolchain**: Dart 3.13+ (SDK constraint `^3.11.0`), pure-Dart CLI
  (`bin/zuraffa.dart` → `zfa`); no Flutter dependency in `lib/src`. Tests run
  with `dart test`; formatting is `dart format` (CI format gate).
- **Command surface**: `zfa tdd make [<id>]` (`make_command.dart`, ~3700
  lines) is the red→green driver for one behavior; `zfa tdd run` /
  `run-engine` / `run-skin` (`run_driver_core.dart`, ~3300 lines) drive every
  behavior through gen → verify-red → make → refactor, two phases.
- **Machine contracts**: each step child prints a final `<step>: k=v ...`
  summary line; `StepRunner._parseSummaryLine` (step_runner.dart) extracts
  `outcome` and computes `success` from the make green-family tokens. The
  outcome token vocabulary lives in `MakeOutcome`
  (`lib/src/plugins/tdd/models/generation_plan.dart`).
- **Run state**: `RunState` (`lib/src/plugins/tdd/models/run_state.json` at
  `tdd/run-state.json` via `RunStateStore`) — per-behavior `BehaviorState`
  (`pending, blocked, red, green, mocked, done`) + in-flight marker. Resume
  semantics: reconcile against cycle-log evidence (evidence beats state,
  FR-003), then `_stepsFor(state)` re-enters the loop.

## Hand-step classification (the make side)

The planner's seam class (SPEC 1489) = a unit behavior whose declared
contract return is an entity-shaped type. The make-side classifier must be
STABLE against mid-run entity creation (phase-0 may create the entity between
the forecast and the make), so it keys on the TYPE SHAPE, not the registry:
the resolved declared signature (`DeclaredRouting.declaredSignatureFor` — the
same resolver the forecast uses) whose `returnType` is NOT a renderable
scalar (`UnitContractShape.isRenderableScalarType` — scalars, void,
dynamic/Object/Never and scalar generics excluded; `ScanSession`,
`List<Task>`, `Map<String, Task>` included). This is existence-independent
and byte-for-byte matches the forecast's announced class
("will hand-step because return is an entity") for every fresh-project shape:
- entity missing at make time → the degraded `Object?` subject; func rewrites
  with the honest throw → red → classify hand-step.
- entity on disk → the #1565 build-only plan; the verbatim subject throws →
  red → classify hand-step.
Scalars/void keep every existing surface (func serves scalars mechanically;
void lands at the #1308 vacuous-green stop when its guard goes green).

## Run-state propagation (the driver side)

Mirror the #1544 park-and-continue shape:
- **Park + continue**: the make `outcome=hand-step` arm in `_driveBehavior`
  clears the in-flight marker, keeps the behavior's state (PENDING — the
  honest red evidence stands), records the id, and returns `stop: null` —
  the loop continues with the remaining behaviors.
- **Persistence for resume (AC4)**: `RunState` gains `handSteps`
  (`hand_steps` in `tdd/run-state.json`; absent → empty — backward and
  forward compatible). The drive consults the set BEFORE spawning steps: a
  known hand-step whose state is not green/done/mocked is parked with a
  named line, never re-driven.
- **Report (AC2)**: `RunDriverCore.summaryLine` gains `hand_steps=N` (when
  N > 0, the `skipped-widget=` precedent); the end-of-run terminal block
  names the ids + the deliberate-implementation remedy.

## Files touched (and ONLY these)

| File | Change |
| ---- | ------ |
| `lib/src/plugins/tdd/models/generation_plan.dart` | add `MakeOutcome.handStep('hand-step')` (non-fatal verdict docs) |
| `lib/src/plugins/tdd/commands/make_command.dart` | classify the post-generation red stop as `handStep` when the declared contract return is entity-shaped; the named hand-step stop message; subject restore (#1036) preserved |
| `lib/src/plugins/tdd/models/run_state.dart` | `handSteps` field + `markHandStep` + JSON round-trip |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | the `hand-step` park arm; the resume/phase-2 skip; `handStepIds` through `RunDriverOutcome`/`_finish`/`_outcome`; `summaryLine` `hand_steps=N`; the end-of-run block |

## Untouched (hard constraint)

- `generation_planner.dart` / `unit_contract_shape.dart` (the planner, the
  forecast) — read-only consumers.
- `wire_command.dart` (the entity pipeline), the analyze gate (#942/#1407).
- The #1308 vacuous-green stop, the #1323 hand-delta stop, the #1411
  born-green transition — every existing named seam keeps its surface.
- `BehaviorState` enum — hand-steps stay PENDING (the issue's own wording);
  no new state value, no state-machine change.

## Test strategy (TDD)

Fast-tier unit/integration tests around the four touched files (mirroring
`test/plugins/tdd/services/generation_planner_1565_test.dart` and the
run_command harnesses):
1. `MakeOutcome.handStep` label + non-green classification (model test).
2. make classification: entity-shaped declared return + post-generation red
   → `outcome=hand-step` (never `generation-error`); scalar/undeclared
   → honest `generation-error` unchanged (SC-7 guards).
3. `RunState` handSteps round-trip (toJson/fromJson, absent-field
   compatibility, markHandStep immutability).
4. Driver: the park arm continues the run (SC-3/SC-6), the resume skip never
   re-drives (SC-4), `summaryLine` carries `hand_steps=N` (SC-5).
Red evidence recorded BEFORE the implementation lands (the TDD extension's
cycle log discipline); mutation-checked in tdd.verify.
