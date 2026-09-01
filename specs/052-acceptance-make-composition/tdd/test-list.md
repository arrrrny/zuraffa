---
feature: 052-acceptance-make-composition
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 15
planned_at: acdb3722
updated_at: acdb3722
suite_baseline: green
---

# Test List: `zfa tdd compose` — phase-2 acceptance make composition

Baseline: `dart test test/plugins/tdd/` at `acdb3722` → 295 passed, 0 failed
(fast tier). The real-pipeline scenario suite (SC-021) runs in the
`slow` tier with a pure exec forwarder to the real `bin/zfa.dart`
(SC-017/SC-018 provisioning); driver deferral suites (sc_013–sc_016) remain
the authoritative slow-tier guards for the #625/#635 contracts.

## Outer loop: acceptance behaviors

The 15 A-rows trace all 15 criteria in `spec.md`; the `traces` column names
the criterion covered by each row, while a criterion may have evidence from
more than one test. A12 credits the existing SC-018 suite for US3.AC4.
Fast-tier acceptance behaviors drive the real CLI entry point in-process
(`CliRunner`, the sc_001–sc_012 pattern); A1/A2 drive the real pipeline end
to end (the sc_018 pattern).

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | A prose acceptance behavior + a unit behavior, driven through the REAL pipeline, completes all-DONE with the phase-2 make flipped green via composition (no fake-zfa scripting of the flip) | US1.AC1 | example | DONE | `test/plugins/tdd/scenarios/sc_021_acceptance_composition_e2e_test.dart::A1: phase-2 composition flips the deferred acceptance make green through the real pipeline` |
| A2  | The composed behavior's green cycle-log entry records the compose invocation among its captured generation steps | US1.AC2 | example | DONE | `test/plugins/tdd/scenarios/sc_021_acceptance_composition_e2e_test.dart::A2: the green evidence names the compose step` |
| A3  | The composed subject file carries the GENERATED compose stamp, imports and references the green unit subjects, and the paired test file is byte-identical | US1.AC3 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::A3: composed subject is stamped, anchored, and leaves the test file untouched` |
| A4  | `zfa tdd compose <id>` replaces the stub with the composed implementation and prints the summary line as the final stdout line, exit 0 | US2.AC1 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::A4: compose wires the acceptance subject against green unit subjects` |
| A5  | A second compose on a composed subject reports `already-composed` and exits 0 | US2.AC2 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::A5: re-compose is idempotent (already-composed, exit 0)` |
| A6  | Compose with zero green unit subjects misfire-stops `no-green-units`, non-zero, naming the precondition | US2.AC3 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::A6: no green units -> no-green-units, non-zero` |
| A7  | A green unit whose subject file is missing misfire-stops `runner-error` naming the missing artifact | US2.AC4 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::A7: missing anchor subject file -> runner-error naming the artifact` |
| A8  | The paired test file is byte-identical after ANY compose outcome | US2.AC5 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::A8: the paired test file is byte-identical on every outcome` |
| A9  | `GenerationPlanner.plan()` outputs are byte-identical to its pinned entity/CRUD/prose plans after the feature lands | US3.AC1 | example | DONE | `test/plugins/tdd/services/composition_planner_test.dart::A9: the primary planner's plans are byte-identical (purity pin)` + `test/plugins/tdd/services/generation_planner_test.dart` (existing suite, unchanged and passing) |
| A10 | An acceptance make with zero composable anchors reports `unexpressible` and the run honest-stops non-zero with the units green | US3.AC2 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::A10: acceptance make with no anchors honest-stops unexpressible` |
| A11 | A unit-kind unexpressible make never attempts the composition fallback | US3.AC3 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::A11: unit-kind unexpressible never composes` |
| A12 | An entity-bearing acceptance behavior completes all-DONE through the real pipeline in phase 1 exactly as before (no regression) | US3.AC4 | example | DONE | `test/plugins/tdd/scenarios/sc_018_plan_run_loop_e2e_test.dart` (existing suite, unchanged and passing; SC-021's entity fixture re-verifies) |
| A13 | The make fallback executes `compose` → `build` through the pipeline and records both steps in the green entry | US4.AC1 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::A13: the fallback plan runs compose then build with captured steps` |
| A14 | A failed compose step stops the make with `generation-error` and no green entry, naming the failed step | US4.AC2 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::A14: a failed compose step is a generation misfire` |
| A15 | A failed build after a successful compose stops the make with `generation-error` and no green entry | US4.AC3 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::A15: a failed build after compose is a generation misfire` |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/composition_targets.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | Anchors = unit-kind test-list rows ∩ green cycle-log evidence ∩ existing subject files, in test-list order | FR-003 | example | DONE | `test/plugins/tdd/services/composition_targets_test.dart::U1: anchors are green unit subjects with existing files` |
| U2  | Zero composable anchors yields the typed no-green-units result (not an exception) | FR-003 | example | DONE | `test/plugins/tdd/services/composition_targets_test.dart::U2: zero anchors is a typed no-green-units result` |
| U3  | A green unit whose subject file is missing yields a typed failure naming the artifact | FR-003 | example | DONE | `test/plugins/tdd/services/composition_targets_test.dart::U3: a missing anchor subject file is a typed failure naming it` |
| U4  | The compose target's own behavior id is never an anchor | FR-003 | example | DONE | `test/plugins/tdd/services/composition_targets_test.dart::U4: the target never anchors against itself` |
| U5  | A malformed test list yields a typed failure (fail-closed — the make fallback must not guess kinds) | FR-007 | example | DONE | `test/plugins/tdd/services/composition_targets_test.dart::U5: a malformed test list fails closed, naming the file` |

### `lib/src/plugins/tdd/services/composition_planner.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U6  | Acceptance summary + ≥1 anchor yields the plan `tdd compose <id>` → `build` (terminal build step; purposes name behavior and anchor count) | FR-007 | example | DONE | `test/plugins/tdd/services/composition_planner_test.dart::U6: the fallback plan is compose then build` |
| U7  | Purity: the returned plan depends only on (summary, anchors) — same inputs, same steps, no I/O | FR-008 | example | DONE | `test/plugins/tdd/services/composition_planner_test.dart::U7: the fallback planner is pure` |
| U8  | The primary planner's mapping rules are byte-identical to its pinned outputs (entity / CRUD / prose) | FR-008, SC-006 | example | DONE | `test/plugins/tdd/services/generation_planner_test.dart` (existing suite, credited unchanged) |

### `lib/src/plugins/tdd/commands/compose_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U9  | Unknown behavior id → named error with the `zfa tdd gen` remediation | FR-001 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::U9: unknown id names the gen remediation` |
| U10 | Ambiguous id registered in multiple features → named error demanding `--feature` | FR-001 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::U10: ambiguity demands --feature` |
| U11 | No certified-red evidence → `not-certified-red`, exit 1, no writes | FR-002 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::U11: compose requires certified red` |
| U12 | Missing subject artifact → named misfire-stop (no rewrite) | FR-001 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::U12: a missing subject artifact stops before any write` |
| U13 | The rendered composed body carries the GENERATED stamp, anchor imports, and the anchor reference list | FR-004 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::U13: the composed body is stamped and anchored` |
| U14 | A subject with no `UnimplementedError` re-runs as `already-composed`, exit 0, byte-identical file | FR-005 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::U14: already-composed is idempotent` |
| U15 | An `UnimplementedError` in an unrecognized shape → refusal, exit 1, byte-identical file | FR-005 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::U15: an unrecognized stub shape is refused, not rewritten` |
| U16 | The summary line `compose: behavior=<id> outcome=<label> feature=<f>` is the final stdout line on every code path | FR-006 | example | DONE | `test/plugins/tdd/commands/compose_command_test.dart::U16: the summary line is final on every outcome` |

### `lib/src/plugins/tdd/commands/make_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U17 | The fallback engages only when the test-list row is acceptance-kind (kind read via the shared `TestListReader`) | FR-007 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::U17: the fallback is gated on the acceptance kind` |
| U18 | A malformed test list in make → fail-closed `unexpressible` (no fallback attempt) | FR-007 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::U18: a malformed test list fails the fallback closed` |
| U19 | Fallback steps execute through `PipelineRunner` and are recorded in the green entry's generation steps | FR-010 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::U19: fallback invocations are captured in the green evidence` |
| U20 | A failed fallback step → `generation-error`, exit 1, no green entry, failed step named | FR-010 | example | DONE | `test/plugins/tdd/commands/make_command_test.dart::U20: a failed fallback step misfires the make` |

## Invariants and edge cases still to place

- An acceptance behavior whose description ALSO carries entity/CRUD
  keywords never reaches the fallback (the planner's plan wins) — covered
  by A12/U8's pinned planner behavior; no separate test needed.
- A resumed phase-2 run re-invoking compose on an already-composed subject
  stays green — covered by A5/U14 (idempotence) and the driver's existing
  resume suites (sc_014).

## Out of scope

- Composition for unit-kind behaviors: a unit subject implements its own
  logic (spec Out of Scope; A11 pins the refusal).
- Composing against non-zuraffa implementations: anchors are the feature's
  own green unit subjects only (spec Out of Scope).
- Driver contract changes (new step, relaxed deferral): spec FR-011/FR-012;
  the sc_013–sc_016 suites pin the contracts unchanged.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md`:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Full suite (repo, cloud-safe): `tools/run_tests_chunked.sh`
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
- Static analysis (full repo): `dart analyze`
- Slow tier (scenario): `dart test test/plugins/tdd/scenarios/sc_021_acceptance_composition_e2e_test.dart --preset=slow-verify` (or `dart test <file> --tags slow` on a full-local baseline only)
