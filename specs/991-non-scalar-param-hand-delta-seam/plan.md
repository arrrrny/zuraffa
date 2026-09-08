**Template Version**: `zuraffa-1.0`

# Plan: 991-non-scalar-param-hand-delta-seam

## Technical Context

- **Language/stack**: Dart 3.13 (SDK ^3.11.0), pure-Dart package (no
  Flutter needed for these paths); test runner `dart test`.
- **Command surface**: `zfa tdd make <behavior-id>`
  (`lib/src/plugins/tdd/commands/make_command.dart`), the run driver
  (`lib/src/plugins/tdd/commands/run_driver_core.dart`), and the gen-time
  behavior test writer
  (`lib/src/plugins/tdd/services/behavior_test_writer.dart`).
- **Machine contracts**: make's summary line
  `make: behavior=<id> outcome=<label> feature=<f>` is parsed by
  `StepRunner` (`lib/src/plugins/tdd/services/step_runner.dart`); a new
  outcome label must be carried end-to-end (enum → summary → driver arm).
- **Precedent**: issue #1308 added the named hand step
  (`stopped_at=<id>:hand`) for the vacuous-green stop; this feature
  follows the same shape for the `_argN()` placeholder stop.

## Design Decisions

1. **Detection is two-signal and lives in one service** (the red
   classifier lesson: never scatter output-grammar regexes across call
   sites). New service `lib/src/plugins/tdd/services/arg_placeholder.dart`
   exports:
   - `argPlaceholderHitOf({required String testContent, required String
     runOutput})` → `ArgPlaceholderHit?` with the placeholder index,
     target name, and declared type. Signal (a): the test content carries
     the generated helper `_argN() => throw UnimplementedError('provide a
     representative argument for <target> (declared param N: <type>)')`.
     Signal (b): the failing transcript carries the message token
     "provide a representative argument for". Both must agree (FR-001).
2. **New outcome, not an overloaded one**: `MakeOutcome.handDeltaRequired`
   with label `hand-delta-required` in
   `lib/src/plugins/tdd/models/generation_plan.dart`. In make's step 8
   (target test still fails after generation), the diagnosis is attempted
   BEFORE the generic `generation-error` stop; on a hit make prints the
   exact edit (placeholder, project-relative test path, declared type,
   re-run command), restores the subject (#1036 contract), and stops
   exit 1 with no green entry. All other still-failing reds keep the
   honest generic `generation-error`.
3. **`_scalarLiteral` covers `Object`** (FR-004, the preferred path):
   `case 'Object': return 'Object();'` — the returned string is the
   ARGUMENT EXPRESSION at the capture site, so the literal is `Object()`.
   Entity-typed params (degraded to `Object?`) and all other non-scalar
   types keep the `_argN()` seam (FR-003).
4. **Driver arm for the new outcome** (FR-006): in
   `run_driver_core.dart`'s step-failure handling, an arm before the
   generic honest stop keys on `step == 'make' && outcome ==
   'hand-delta-required'`, advances state generically, prints the exact
   edit, and reports `stopped_at=<id>:hand` (the #1308 hand-step
   contract). The lane journal's hand-step violation uses the shared
   remedy vocabulary from `arg_placeholder.dart`.
5. **Re-certification after the hand-edit** (FR-005) is the make drift
   check (step 4): it re-runs the target test before generation on every
   make invocation — a certified-red entry never short-circuits it. The
   fix proves this with a test that hand-edits the generated test between
   two make invocations (red → hand-edit → green); no production change
   is needed for this requirement, the test pins it.

## File Structure

```
lib/src/plugins/tdd/services/arg_placeholder.dart     # NEW: detection + remedy vocabulary
lib/src/plugins/tdd/models/generation_plan.dart        # MakeOutcome.handDeltaRequired
lib/src/plugins/tdd/commands/make_command.dart         # step-8 diagnosis arm
lib/src/plugins/tdd/commands/run_driver_core.dart      # hand-delta-required driver arm
lib/src/plugins/tdd/services/behavior_test_writer.dart # _scalarLiteral covers Object
test/plugins/tdd/arg_placeholder_test.dart             # NEW: fast-tier detection unit tests
test/plugins/tdd/issue_1323_hand_delta_seam_test.dart  # NEW: make + writer integration (slow tier)
test/plugins/tdd/issue_1323_hand_delta_driver_test.dart# NEW: driver stop arm (slow tier)
```

## Verification Strategy

- Fast tier: pure unit tests on `argPlaceholderHitOf` (marker present +
  transcript token → hit; marker absent → null; token absent → null) and
  on the writer's `_scalarLiteral` coverage via the generated-content
  assertions (Object → `Object()`, scalars unchanged).
- Slow tier: `CliRunner` end-to-end over a `TddFixture` — a certified-red
  `Object`-param behavior, a fake `zfa` pipeline that does not fix the
  test, make → `hand-delta-required` + exact remedy; then the hand-edit
  and a second make → green (re-certification, SC-2). Driver-level: a
  scripted fake zfa stop asserting `stopped_at=<id>:hand` and the remedy
  line.
