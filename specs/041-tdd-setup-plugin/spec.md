# Feature Specification: TDD-ready `zfa setup` baseline + `zfa tdd` plugin

**Feature Branch**: `575-tdd-setup-tdd-plugin`

**Created**: 2026-08-29

**Status**: Draft

**Input**: User description: "TDD-ready `zfa setup` + a `zfa tdd` plugin that runs the whole red-green-refactor cycle"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Day-zero TDD baseline from `zfa setup` (Priority: P1)

A developer runs `zfa setup myapp` to scaffold a new project. The moment the scaffold finishes, the developer wants to type `flutter test` and get a real, green baseline — a single passing smoke test that proves the generated app module and dependency-injection container can be constructed — instead of the current behavior where `flutter test` errors out with `Test directory "test" not found.` and reports zero tests. The freshly scaffolded project must include a `test/` directory containing at least one runnable smoke test, a `dart_test.yaml` at the project root, the testing `dev_dependencies` (a runner, a mocking library, code-generation tooling, a coverage helper, and a mutation-testing helper), and a machine-readable `.specify/memory/tdd-profile.md` command map that downstream tools can read to know exactly how to invoke the test runner for a single test, a file, the whole suite, and coverage. Optionally, the developer may pass `--tdd-example` to also receive a generated failing example test that demonstrates the red→green transition.

**Why this priority**: This story blocks every other story in this spec — without a day-zero test directory and a green baseline, TDD cannot start, and the `zfa tdd` plugin has nothing to drive. It is also the smallest unit of value and the cheapest to ship.

**Independent Test**: Run `zfa setup myapp`, then `cd myapp && flutter test` and observe exit code 0 with at least one test reported. Then run `flutter test test/bootstrap_smoke_test.dart` and observe that exactly the smoke test file runs. Then read `.specify/memory/tdd-profile.md` and confirm it contains `runner`, `single`, `file`, `suite`, and `coverage` keys whose values are valid invocation templates.

**Acceptance Scenarios**:

1. **Given** a clean working directory and `zfa` is on PATH, **When** the developer runs `zfa setup myapp`, **Then** the scaffolded `myapp/` contains a `test/` directory with a `bootstrap_smoke_test.dart` file, a `dart_test.yaml` at the project root, testing `dev_dependencies` present in `pubspec.yaml`, and a `.specify/memory/tdd-profile.md` file.
2. **Given** a freshly scaffolded `myapp/` from scenario 1, **When** the developer runs `flutter test` from inside `myapp/`, **Then** the command exits 0 and the runner reports at least one passing test.
3. **Given** a freshly scaffolded `myapp/` from scenario 1, **When** the developer runs `flutter test test/bootstrap_smoke_test.dart`, **Then** the runner executes exactly that file (no other test files) and the smoke test passes.
4. **Given** a freshly scaffolded `myapp/` from scenario 1, **When** a downstream tool reads `.specify/memory/tdd-profile.md`, **Then** it can resolve `runner`, `single` (with `{file}` and `{name}` placeholders), `file` (with `{file}`), `suite`, and `coverage` into runnable shell commands.
5. **Given** the developer passes `--tdd-example` to `zfa setup`, **When** the scaffold finishes, **Then** `test/` contains an additional failing example test whose failure is an assertion failure (not a compile error), demonstrating the red half of the red→green loop.

---

### User Story 2 - `zfa tdd init` idempotently ensures the TDD environment (Priority: P2)

A developer who already has a project scaffolded (either before this spec landed, or from a non-`zfa` scaffold) wants to bring it up to the same TDD baseline as User Story 1 without re-running `zfa setup`. The developer runs `zfa tdd init` and the tool idempotently ensures every artifact from User Story 1 exists: `test/` with a smoke test, testing `dev_dependencies`, `dart_test.yaml`, and `.specify/memory/tdd-profile.md`. Running `zfa tdd init` again on a project that already meets the baseline is a no-op and exits 0; running it on a project that is partially complete fills in the missing pieces without clobbering existing user content.

**Why this priority**: It is the on-ramp for the rest of the `zfa tdd` subcommands. Without `init`, the plan/gen/run/verify subcommands have no target environment and would have to re-implement the same environment checks each time.

**Independent Test**: Take a project that has no `test/` directory and run `zfa tdd init`; afterwards `flutter test` must succeed and report at least one test. Run `zfa tdd init` a second time and confirm it exits 0 without modifying any existing files.

**Acceptance Scenarios**:

1. **Given** a project directory with no `test/`, no `dart_test.yaml`, no `tdd-profile.md`, and no testing `dev_dependencies`, **When** the developer runs `zfa tdd init`, **Then** every missing artifact from User Story 1 is created and `flutter test` exits 0 with at least one test reported.
2. **Given** a project directory that already satisfies the User Story 1 baseline, **When** the developer runs `zfa tdd init`, **Then** the command exits 0 and no existing file is modified (no byte-level changes to `pubspec.yaml`, `dart_test.yaml`, the smoke test, or `tdd-profile.md`).
3. **Given** a project directory that has a partial baseline (for example, `test/` exists with a custom test file but `dart_test.yaml` is missing), **When** the developer runs `zfa tdd init`, **Then** the missing artifacts are created and the pre-existing custom test file is left untouched.

---

### User Story 3 - `zfa tdd plan <feature>` produces a behavior test list (Priority: P2)

A developer has a `spec.md` for a new feature and wants a single document that decomposes the spec's acceptance scenarios and functional requirements into individual, runnable test behaviors, each traced back to the criterion that motivated it. The developer runs `zfa tdd plan <feature>` and the tool reads the spec, emits `tdd/test-list.md`, and gives each behavior a stable identifier. Acceptance behaviors are derived from the spec's `Given/When/Then` scenarios; unit behaviors are derived from each functional requirement. Every behavior row in the list is mapped to the criterion it verifies.

**Why this priority**: The plan is the contract between the spec and the loop driver. Without `plan`, `gen` would have nothing to generate from and `run` would have nothing to iterate over.

**Acceptance Scenarios**:

1. **Given** a `spec.md` containing two `Given/When/Then` scenarios and three functional requirements, **When** the developer runs `zfa tdd plan <feature>`, **Then** `tdd/test-list.md` contains exactly two acceptance behaviors (one per scenario), exactly three unit behaviors (one per requirement), and each behavior row records its source criterion.
2. **Given** a `tdd/test-list.md` that already exists from a previous `plan` run, **When** the developer runs `zfa tdd plan <feature>` again after editing the spec, **Then** the existing behavior identifiers are preserved for unchanged behaviors, removed behaviors are dropped, and new behaviors receive fresh identifiers without renumbering the existing ones.
3. **Given** a spec with no `Given/When/Then` scenarios, **When** the developer runs `zfa tdd plan <feature>`, **Then** the tool stops with a non-zero exit code and a clear message that the spec contains no acceptance scenarios, rather than silently emitting an empty test list.

---

### User Story 4 - `zfa tdd gen <behavior-id>` writes a failing test and a compiling stub (Priority: P2)

A developer has a behavior identifier from `tdd/test-list.md` and wants to materialize it as a failing test alongside the minimal source stub needed to make the test compile (but fail for the right reason — an assertion failure, not a compile error or a missing-symbol load error). The developer runs `zfa tdd gen <behavior-id>` and the tool delegates test generation to the existing `lib/src/plugins/test` machinery, then synthesizes a minimal stub for the production code under test. The result of `gen` is a project that compiles cleanly and a test that fails with an assertion failure when run.

**Acceptance Scenarios**:

1. **Given** a behavior identifier `B-003` in `tdd/test-list.md` whose source criterion is an acceptance scenario, **When** the developer runs `zfa tdd gen B-003`, **Then** a test file is created under `test/` (via the existing `test` plugin) and a minimal source stub is created under `lib/` that compiles but does not satisfy the behavior.
2. **Given** the artifacts produced by scenario 1, **When** the developer runs `flutter test <generated-test-file>`, **Then** the runner reports a failure whose cause is an assertion failure (not a compile error, not a missing-symbol load error, not a missing file).
3. **Given** a behavior identifier that does not exist in `tdd/test-list.md`, **When** the developer runs `zfa tdd gen <behavior-id>`, **Then** the tool stops with a non-zero exit code and a message naming the unknown identifier, rather than silently generating files for a non-existent behavior.

---

### User Story 5 - `zfa tdd verify-red` asserts the test fails for the right reason (Priority: P2)

A developer who has just run `gen` wants to confirm that the generated test is "honestly red" — failing because the production stub does not yet implement the behavior, not because of a typo, a missing import, or a compile error. The developer runs `zfa tdd verify-red` and the tool executes the target test, parses the runner output, asserts that the failure is an assertion failure (not a load or compile error), appends the failure output to `tdd/cycle-log.md`, and exits non-zero if the test goes green or fails to compile.

**Acceptance Scenarios**:

1. **Given** a freshly generated test+stub from `zfa tdd gen B-003` that fails with an assertion failure, **When** the developer runs `zfa tdd verify-red`, **Then** the tool runs the target test, classifies the failure as an assertion failure, appends a red-evidence entry to `tdd/cycle-log.md`, and exits 0.
2. **Given** a generated test+stub where the developer has accidentally introduced a compile error, **When** the developer runs `zfa tdd verify-red`, **Then** the tool exits non-zero, reports that the failure was a compile/load error rather than an assertion failure, and does not append a green-evidence entry to the cycle log.
3. **Given** a generated test that the developer has already made green (for example by implementing the behavior prematurely), **When** the developer runs `zfa tdd verify-red`, **Then** the tool exits non-zero and reports that the test is unexpectedly green, so the red half cannot be honestly recorded.

---

### User Story 6 - `zfa tdd make <behavior-id>` drives the test green via generated implementation (Priority: P2)

A developer has an honestly-red test from `verify-red` and wants to flip it to green by generating the minimal implementation through the existing `zfa make`/`zfa entity create`/`zfa build` machinery — never by hand-writing source. The developer runs `zfa tdd make <behavior-id>` and the tool generates the implementation, runs the target test, asserts it now passes, and appends a green-evidence entry to `tdd/cycle-log.md`. If the test does not go green, the tool stops and reports the failure rather than patching the test.

**Acceptance Scenarios**:

1. **Given** an honestly-red test from `verify-red` for behavior `B-003`, **When** the developer runs `zfa tdd make B-003`, **Then** the tool generates the minimal implementation via the existing `zfa make`/`zfa entity create`/`zfa build` pipeline, runs the target test, asserts it passes, and appends a green-evidence entry to `tdd/cycle-log.md`.
2. **Given** an honestly-red test whose required implementation cannot be produced by the existing generation pipeline, **When** the developer runs `zfa tdd make <behavior-id>`, **Then** the tool stops with a non-zero exit code and a clear message naming what it could not generate, and does not modify the test to make it pass.
3. **Given** a behavior whose generated implementation passes the target test but breaks a previously-green sibling test, **When** the developer runs `zfa tdd make <behavior-id>`, **Then** the tool runs the full suite, detects the regression, and exits non-zero with a report naming the regressed test, rather than declaring the behavior green.

---

### User Story 7 - `zfa tdd refactor` runs only on a green suite and never edits tests (Priority: P3)

A developer has a green suite and wants to refactor safely. The developer runs `zfa tdd refactor` and the tool first asserts that the suite is currently green; only then does it offer the existing `zfa make`/`zfa build` refactor hooks. After any source change, the suite is re-run. The tool never modifies a test file in the same step — refactoring is a production-code-only operation.

**Acceptance Scenarios**:

1. **Given** a fully green suite, **When** the developer runs `zfa tdd refactor`, **Then** the tool confirms the suite is green before offering any refactor hooks, applies the refactor through the existing `zfa make`/`zfa build` machinery, re-runs the suite afterwards, and never modifies a test file during the step.
2. **Given** a suite with at least one failing test, **When** the developer runs `zfa tdd refactor`, **Then** the tool exits non-zero before any refactor is applied, names the failing test, and instructs the developer to return to `make`.
3. **Given** a green suite that the developer refactored, **When** the post-refactor re-run reports a regression, **Then** the tool exits non-zero, names the regressed test, and does not write any green-evidence entry to `tdd/cycle-log.md`.

---

### User Story 8 - `zfa tdd run <feature>` drives the full loop with state transitions (Priority: P2)

A developer wants the cycle automated: given a feature with a `tdd/test-list.md`, the loop driver iterates over each behavior and advances it through `PENDING → RED → GREEN → DONE`, calling `gen → verify-red → make → refactor` for each. The driver records state per behavior in a small state file under `tdd/`, so that an interrupted run can resume from the last incomplete behavior rather than restarting from scratch. If any step in the cycle cannot complete as specified, the driver stops immediately and reports the failure with no hand-written workaround.

**Acceptance Scenarios**:

1. **Given** a feature with three behaviors in `tdd/test-list.md` and a clean working tree, **When** the developer runs `zfa tdd run <feature>`, **Then** each behavior is advanced through `PENDING → RED → GREEN → DONE` in order, `tdd/cycle-log.md` accumulates one red and one green entry per behavior, and the final suite is green.
2. **Given** an interrupted `zfa tdd run <feature>` that stopped at behavior `B-002` in state `RED`, **When** the developer re-runs `zfa tdd run <feature>`, **Then** the driver resumes from `B-002` (does not re-do `B-001`) and continues until all behaviors are `DONE`.
3. **Given** a behavior whose `make` step cannot be completed by the existing generation pipeline, **When** the developer runs `zfa tdd run <feature>`, **Then** the driver stops at that behavior with a non-zero exit code, leaves the behavior in state `RED`, and reports that the make step could not be completed — no test is modified to fake a pass.

---

### User Story 9 - `zfa tdd verify` audits coverage and mutation strength (Priority: P3)

A developer has completed a feature through `zfa tdd run` and wants an honest audit of how strong the resulting tests actually are. The developer runs `zfa tdd verify` and the tool runs `flutter test --coverage`, captures the coverage number, and — when a mutation-testing tool is present in the project's `dev_dependencies` — runs mutation testing on the changed files. When no mutation tool is present, the tool falls back to a deliberate-mutant spot check on the changed files and reports what it did. The result is written to `tdd/verification.md`.

**Acceptance Scenarios**:

1. **Given** a completed feature whose suite is green and a mutation tool present in `dev_dependencies`, **When** the developer runs `zfa tdd verify`, **Then** `tdd/verification.md` contains a coverage section with the measured percentage, a mutation section with the mutation score, and an acceptance-criteria coverage matrix mapping each criterion to its verification status.
2. **Given** a completed feature whose suite is green and no mutation tool present in `dev_dependencies`, **When** the developer runs `zfa tdd verify`, **Then** the tool falls back to a deliberate-mutant spot check on the changed files, runs the spot check, records what it mutated and what survived, and writes the result to `tdd/verification.md` alongside the coverage section and the acceptance-criteria coverage matrix.
3. **Given** a feature whose suite is not green, **When** the developer runs `zfa tdd verify`, **Then** the tool exits non-zero before running coverage or mutation, names the failing test, and instructs the developer to return to `zfa tdd run`.

---

### Edge Cases

- What happens when `zfa setup` is run inside an existing non-empty project directory? The smoke test must not overwrite an existing `test/bootstrap_smoke_test.dart`; the existing file is preserved.
- What happens when the testing `dev_dependencies` are already present in the user's `pubspec.yaml`? `zfa setup` and `zfa tdd init` must not duplicate entries.
- What happens when `zfa tdd plan` is invoked against a spec that has acceptance scenarios but no functional requirements? The plan emits acceptance behaviors only.
- What happens when `zfa tdd gen` is invoked for a behavior whose source criterion is an acceptance scenario that depends on multiple use cases? The generated test must still be a single file with a single failing assertion that targets the behavior identifier.
- What happens when the mutation tool produces a score of zero (all mutants survived)? `zfa tdd verify` must report the score honestly.
- What happens when `zfa tdd run` is interrupted mid-step? The state file must reflect the in-flight behavior's last fully-completed state, and a re-run must resume from that state.
- What happens when the `tdd-profile.md` command map disagrees with what the project actually supports? `zfa tdd verify` must report the discrepancy and fall back gracefully.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa setup <name>` MUST emit a `test/` directory containing at least one runnable smoke test that asserts the generated app module and dependency-injection container can be constructed.
- **FR-002**: `zfa setup <name>` MUST add testing `dev_dependencies` to the generated `pubspec.yaml`: a test runner, a mocking library, code-generation tooling, a coverage helper, and a mutation-testing helper.
- **FR-003**: `zfa setup <name>` MUST emit a `dart_test.yaml` at the generated project root configuring the test runner.
- **FR-004**: `zfa setup <name>` MUST emit a `.specify/memory/tdd-profile.md` file in the generated project with a machine-readable command map containing the keys `runner`, `single` (with `{file}` and `{name}` placeholders), `file` (with `{file}`), `suite`, and `coverage`.
- **FR-005**: `zfa setup <name>` MUST accept an optional `--tdd-example` flag that, when present, additionally emits a generated failing example test whose failure is an assertion failure (not a compile error).
- **FR-006**: After `zfa setup <name>` finishes, `flutter test` invoked from inside the generated project MUST exit 0 and report at least one test.
- **FR-007**: After `zfa setup <name>` finishes, `flutter test test/bootstrap_smoke_test.dart` invoked from inside the generated project MUST execute exactly the smoke test file and no other test files.
- **FR-008**: `zfa tdd init` MUST idempotently ensure every artifact from FR-001 through FR-004 exists in the current project, creating only what is missing and never modifying existing user content.
- **FR-009**: `zfa tdd init` MUST be safe to re-run on a project that already satisfies the baseline: it exits 0 and modifies no files.
- **FR-010**: `zfa tdd plan <feature>` MUST read the feature's `spec.md` and emit `tdd/test-list.md` containing one acceptance behavior per `Given/When/Then` scenario and one unit behavior per functional requirement, each with a stable identifier and a back-reference to its source criterion.
- **FR-011**: `zfa tdd plan <feature>` MUST preserve existing behavior identifiers for unchanged behaviors when re-run after a spec edit, and MUST assign fresh identifiers to new behaviors without renumbering the existing ones.
- **FR-012**: `zfa tdd plan <feature>` MUST exit non-zero with a clear message when the spec contains no acceptance scenarios, rather than emitting an empty test list.
- **FR-013**: `zfa tdd gen <behavior-id>` MUST delegate test generation to the existing `lib/src/plugins/test` machinery and MUST synthesize a minimal source stub that compiles cleanly but fails the generated test with an assertion failure.
- **FR-014**: `zfa tdd gen <behavior-id>` MUST exit non-zero with a clear message when the supplied behavior identifier does not exist in `tdd/test-list.md`.
- **FR-015**: `zfa tdd verify-red` MUST run the target test, parse the runner output, and assert that the failure is an assertion failure (not a compile or load error).
- **FR-016**: `zfa tdd verify-red` MUST append a red-evidence entry to `tdd/cycle-log.md` containing the behavior identifier, the runner command, the exit code, and the captured failure output, classified as an assertion failure.
- **FR-017**: `zfa tdd verify-red` MUST exit non-zero and refuse to write a red-evidence entry when the target test goes green or fails to compile.
- **FR-018**: `zfa tdd make <behavior-id>` MUST generate the minimal implementation through `zfa make`/`zfa entity create`/`zfa build` only — it MUST NOT hand-write source to satisfy the test.
- **FR-019**: `zfa tdd make <behavior-id>` MUST run the target test, assert it passes, and append a green-evidence entry to `tdd/cycle-log.md`.
- **FR-020**: `zfa tdd make <behavior-id>` MUST run the full suite and exit non-zero if a previously-green sibling test regresses, even if the target test passes.
- **FR-021**: `zfa tdd refactor` MUST refuse to start when the suite is not fully green, naming the failing test.
- **FR-022**: `zfa tdd refactor` MUST never modify a test file during the refactor step; it MUST re-run the suite after any production-code change and exit non-zero on regression.
- **FR-023**: `zfa tdd run <feature>` MUST iterate over every behavior in `tdd/test-list.md` and advance each through the states `PENDING → RED → GREEN → DONE` by invoking `gen → verify-red → make → refactor`.
- **FR-024**: `zfa tdd run <feature>` MUST persist per-behavior state in a file under `tdd/` so that an interrupted run resumes from the last incomplete behavior.
- **FR-025**: `zfa tdd run <feature>` MUST stop immediately with a non-zero exit code when any step cannot be completed as specified, and MUST NOT modify a test to fake a pass.
- **FR-026**: `zfa tdd verify` MUST run `flutter test --coverage`, capture the coverage number, and write it to `tdd/verification.md`.
- **FR-027**: `zfa tdd verify` MUST run mutation testing on the changed files when a mutation tool is present in `dev_dependencies`, and MUST fall back to a deliberate-mutant spot check on the changed files when no mutation tool is present, recording what was mutated and what survived.
- **FR-028**: `zfa tdd verify` MUST write an acceptance-criteria coverage matrix to `tdd/verification.md` mapping each criterion from `tdd/test-list.md` to its verification status.
- **FR-029**: `zfa tdd verify` MUST exit non-zero before running coverage or mutation when the suite is not green.
- **FR-030**: Every `zfa tdd` subcommand MUST consult `.specify/memory/tdd-profile.md` as the single source of truth for runner commands; no subcommand MUST hard-code a runner invocation that disagrees with the profile.
- **FR-031**: Every `zfa tdd` subcommand MUST implement the misfire-stop policy: if any step cannot complete as specified, the subcommand stops immediately, exits non-zero, and reports the failure with no hand-written workaround.

### Key Entities

- **TDD Profile**: A machine-readable command map stored at `.specify/memory/tdd-profile.md`.
- **Behavior**: A single, independently runnable test target derived from a `spec.md` criterion.
- **Test List**: `tdd/test-list.md`.
- **Cycle Log**: `tdd/cycle-log.md`.
- **Cycle State**: `tdd/run-state.json`.
- **Verification Report**: `tdd/verification.md`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After `zfa setup myapp`, a developer can run `flutter test` from inside `myapp/` and receive a green baseline with at least one reported test on the first attempt, with no manual setup required.
- **SC-002**: A developer can drive a feature from spec to green suite by invoking `zfa tdd run <feature>` as a single command, with each behavior advancing through `PENDING → RED → GREEN → DONE` in order, and the entire cycle completing without any hand-written source outside the generated code pipeline.
- **SC-003**: An interrupted `zfa tdd run` can be resumed by re-running the same command, and the resumed run completes strictly less work than a fresh run.
- **SC-004**: After a feature completes, `zfa tdd verify` reports a coverage number, a mutation score (or an honest spot-check fallback), and an acceptance-criteria coverage matrix in which every criterion from `tdd/test-list.md` is accounted for.
- **SC-005**: A developer reading `tdd/cycle-log.md` can reconstruct, for every behavior, the exact runner command that produced the red and green evidence and the captured output of each.
- **SC-006**: A downstream tool reading `.specify/memory/tdd-profile.md` can resolve the `single`, `file`, `suite`, and `coverage` keys into runnable shell commands and execute them without further configuration.

## Assumptions

- The developer using `zfa` has the Flutter toolchain installed on PATH for projects generated by `zfa setup`.
- The existing `lib/src/plugins/test` machinery is the canonical entry point for test generation.
- The existing `zfa make`/`zfa entity create`/`zfa build` pipeline is the canonical entry point for production-code generation.
- The mutation-testing helper (when present) is invoked via a documented CLI; the exact tool name is not pinned.
- The developer running `zfa tdd` against a feature has already run `/speckit.specify`.
- The smoke test is small and does not depend on Flutter bindings beyond what the generated app shell already imports.
- Existing specs in this repository are not modified by this proposal; this proposal adds a new spec under `specs/041-tdd-setup-plugin/`.
