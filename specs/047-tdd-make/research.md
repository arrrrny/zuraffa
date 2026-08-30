# Research: `zfa tdd make`

Phase 0 findings, resolved against master@`62aed5c9` (046 merged). No NEEDS
CLARIFICATION remain.

## Decision 1: Mirror `verify_red_command.dart` for all shared concerns

- **Decision**: Target resolution, `--feature` handling, profile loading,
  `SingleTestRunner` use, `CycleLog` append, summary-line printing
  (`print()`, not `stdout.writeln`), `exitCode` assignment (not thrown
  exceptions), misfire-stop try/catch flow, and the read-only tree snapshot
  (`_ReadOnlyTreeSnapshot`) all follow the 046 implementation verbatim in
  shape.
- **Rationale**: One convention for the whole loop; `zfa tdd run` will chain
  these commands and needs uniform contracts.
- **Alternatives considered**: a shared base class — rejected for this spec;
  refactor belongs to the `refactor` precondition spec, on a green suite.

## Decision 2: Pipeline steps run as `zfa` CLI sub-processes

- **Decision**: `pipeline_runner.dart` executes each generation step with
  `Process.run(dartVm, [zfaEntrypoint, ...args], workingDirectory: target)`
  and captures a `GenerationStep(command, exitCode, output)`.
- **Rationale**: `EntityCommand` is not a `Command<void>` and calls `exit()`
  internally; `BuildCommand` also calls `exit()`. In-process invocation is
  impossible without refactoring those commands — out of scope.
- **Entrypoint resolution**: `--zfa-bin` flag override; default resolves the
  running CLI's own entrypoint (`Platform.script` when running from source,
  else `zfa` on PATH). A resolution failure is a misfire-stop.
- **Alternatives considered**: `CliRunner` in-process — rejected (exit()
  calls); `runZfaSource` test helper — test-only, not usable from lib/.

## Decision 3: Generation planner maps behavior → minimal plan, else misfire

- **Decision**: `generation_planner.dart` produces a `GenerationPlan`: an
  ordered list of pipeline steps derived from the behavior row (target,
  classification, description). Expressible mappings in v1: entity-bearing
  behaviors → `entity create`; CRUD/use-case behaviors → `make` with the
  appropriate preset/methods; always terminating in `zfa build`. Anything the
  planner cannot map (bespoke logic, UI behavior, external integrations) →
  `unexpressible` misfire with the capability named in behavior terms.
- **Rationale**: spec FR-005 demands minimal generation and an honest
  misfire when the pipeline can't satisfy the behavior; the general planner
  grows with the corpus run (epic 045 gap protocol).
- **Alternatives considered**: always generating a full CRUD stack —
  rejected; violates "minimal" and buries gaps.

## Decision 4: Regression guard diffs failing-test identity, not exit codes

- **Decision**: `suite_guard.dart` runs the profile `suite` command before
  generation (baseline) and after the target test goes green (guard), parses
  failing test names from runner output, and fails only on failures present
  after but not before (NEW failures), naming them.
- **Rationale**: spec US3.AC3 — pre-existing red suites (e.g. the flaky
  `route_perf_test.dart` timing failure at planning time) must not block the
  loop, but any new regression must. Exit-code comparison cannot distinguish
  the two.
- **Alternatives considered**: exit-code-only guard — rejected (fails on any
  pre-existing red); count-only diff — rejected (a fixed test + a regressed
  test nets zero).

## Decision 5: Extend `SingleTestRunner` and `CycleLogEntry` minimally

- **Decision**: `runner.dart` gains `loadSuiteTemplate()` (same parsing as
  `loadSingleTemplate`, key `suite`). `CycleLogEntry` gains
  `generationSteps` (list of recorded pipeline invocations, empty for red
  entries); `toMarkdown()` renders them inside green entries.
- **Rationale**: smallest changes that satisfy spec FR-006/FR-008 without
  breaking the 046 contracts.
- **Alternatives considered**: stuffing generation commands into
  `capturedOutput` — rejected; unstructured, breaks auditability (SC-001).

## Decision 6: Pre-generation drift check re-runs the target test

- **Decision**: Before any generation, `make` runs the target test once via
  the profile `single` command; a pass means drift (already green) →
  non-zero stop per spec FR-003. A compile/load error here is also a stop
  (broken fixture, return to `gen`).
- **Rationale**: vacuous greens launder hand-written code into the loop.
- **Alternatives considered**: trusting the red evidence alone — rejected;
  evidence can be stale.

## Testing approach

- Fast unit tier: `generation_planner_test.dart`, `pipeline_runner_test.dart`
  (fake step executor), `suite_guard_test.dart` (canned runner outputs),
  `cycle_entry_test.dart` extensions.
- Slow tier (`@Tags(['slow'])`, mirroring `verify_red_command_test.dart`):
  `make_command_test.dart` + scenarios sc_005–sc_008 driving the real CLI
  against `TddFixture` projects.
- Baseline at planning: full suite has one pre-existing flaky failure
  (`test/dda/route_perf_test.dart`, timing threshold). Scoped loop work uses
  `dart test test/plugins/tdd/`; the flake is recorded in the cycle log
  baseline and motivates Decision 4's NEW-failure semantics.
