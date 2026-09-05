# Feature Specification: Test Plugin A+ Upgrade — Self-Certify Generated Tests

**Feature Branch**: `980-test-aplus-upgrade`

**Created**: 2026-09-05

**Status**: Approved

**Input**: User description: "test plugin A+ upgrade — self-certify generated tests (compile verdict), per-method receipts, dedicated suite, kill regex parsing (GitHub issue #980)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Self-certifying generation (Priority: P1)

A developer runs `zfa test create --name Product` (or `zfa make Product --test`). The test plugin writes the generated test file, then immediately runs a scoped `dart analyze` on that file. The CLI emits a machine verdict line `test: entity=Product tests=2 compile=pass|fail --> fix: <first error>` and, with `--json` on the direct grammar, a single JSON envelope `{entity, tests, compile, errors[], schema:1}`. When the generated output does not compile, the command exits 1 — never silently pretending the generation succeeded.

**Why this priority**: a test generator that can emit non-compiling tests without noticing undermines the entire TDD-vision product. This is the core "A+ vs B" gap (plugin graded 3.40/5).

**Independent Test**: generating a deliberately non-compiling test fixture fails with the verdict line and a non-zero exit; a compiling fixture certifies `compile=pass`.

**Acceptance Scenarios**:

1. **Given** a workspace whose generated test does not compile, **When** the test plugin generates, **Then** a verdict line `test: entity=<X> tests=<N> compile=fail --> fix: <first error>` is printed and the command exits non-zero.
2. **Given** a workspace whose generated tests compile, **When** the test plugin generates, **Then** the verdict line reads `compile=pass` and generation succeeds.
3. **Given** `--json` on the direct test command grammar, **When** generation finishes, **Then** stdout ends with a parseable envelope `{entity, tests, compile, errors[], schema:1}`.

### User Story 2 - Per-method test receipts with drift detection (Priority: P1)

Every generation writes `.zfa/receipts/test-<entity>.json` mapping each generated test to its usecase method and covered acceptance path (success/failure). `zfa proof check` re-derives the recorded digests: if the usecase source drifted after the tests were generated, the check fails with a precise finding naming the drifted pair.

**Why this priority**: extends the existing proof-carrying generation system (#807) to the test plugin; drift detection is what makes regeneration trustworthy.

**Independent Test**: write a receipt, mutate the usecase file, run `zfa proof check` → red finding naming the usecase/test pair; unchanged pair stays green.

**Acceptance Scenarios**:

1. **Given** a successful generation, **When** it finishes, **Then** `.zfa/receipts/test-<entity>.json` exists and maps every generated test to `{method, acceptance path, usecase, digests}`.
2. **Given** a written receipt, **When** the usecase source file changes afterwards and `zfa proof check` runs, **Then** the check fails with a drift finding naming the usecase/test pair.
3. **Given** a written receipt and unchanged sources, **When** `zfa proof check` runs, **Then** no findings are reported for the test receipt.

### User Story 3 - Dedicated, consolidated test suite (Priority: P2)

All test-plugin coverage lives under `test/plugins/test/` instead of three scattered files, and a direct `TestPlugin.generate` dispatch suite covers the orchestrator and polymorphic paths that are currently unexercised.

**Why this priority**: the plugin's own orchestration (entity vs orchestrator vs polymorphic vs custom dispatch) is untested; scattered coverage hides gaps.

**Independent Test**: `dart test test/plugins/test/` runs the consolidated suite green, including direct dispatch tests for orchestrator and polymorphic configs.

**Acceptance Scenarios**:

1. **Given** the repo, **When** looking for test-plugin coverage, **Then** it lives under `test/plugins/test/` (the three scattered files are moved, not duplicated).
2. **Given** an orchestrator config, **When** `TestPlugin.generate` runs, **Then** the orchestrator builder path produces its file.
3. **Given** a polymorphic config, **When** `TestPlugin.generate` runs, **Then** the polymorphic builder path produces one file per variant.

### User Story 4 - Analyzer-based usecase parsing (Priority: P2)

`_parseUseCaseFile` uses the `analyzer` package AST (the established codebase pattern: `FileParser`/`AstHelper`) instead of three regexes. Behavior is neutral — proven by snapshot tests on the existing fixtures.

**Why this priority**: regex parsing is brittle and duplicates dead `di_command.dart` logic; AST parsing is the house pattern.

**Independent Test**: snapshot tests assert the same repos/services/usecases/useCaseType extraction for orchestrator, service, repository, and flavor fixtures as the regex behavior produced.

**Acceptance Scenarios**:

1. **Given** a usecase fixture, **When** `buildConfigFromUseCase` analyzes it, **Then** dependencies and flavor resolve identically to the pre-change (regex) behavior on every existing fixture.
2. **Given** the source tree, **When** searched, **Then** no regex-based usecase parsing remains in the test plugin.

### User Story 5 - Honest openwiki testing docs (Priority: P2)

`openwiki/testing.md` shows the real native-mock output (no mocktail) and documents the Flutter-vs-pure-Dart flavor detection (#354).

**Why this priority**: the current example actively misleads — it shows `mocktail` output while `test_builder_entity.dart` explicitly emits native mocks.

**Independent Test**: the documented example matches what the generator actually emits; a doc test asserts the markers.

**Acceptance Scenarios**:

1. **Given** openwiki/testing.md, **When** read, **Then** the generated-test example shows native mocks (`Throwing{Entity}DataSource`, `{Entity}MockDataSource`, `package:zuraffa/mock.dart`) and no `mocktail` import.
2. **Given** openwiki/testing.md, **When** read, **Then** the flavor detection rule (#354) is documented: pure-Dart projects import `package:test/test.dart`, Flutter projects `package:flutter_test/flutter_test.dart`, core always `package:zuraffa/mock.dart`.

## Requirements

**FR-001** Self-certification: after writing a test file, the test plugin MUST run a scoped `dart analyze` on that file and MUST emit the machine verdict line `test: entity=<X> tests=<N> compile=pass|fail --> fix: <first error>`. Non-compiling output MUST make the command exit 1 — never silent.

**FR-002** `--json` envelope: the direct test command grammar MUST support `--json`, printing `{entity, tests, compile, errors[], schema:1}` as a single parseable object.

**FR-003** Per-method receipt: every entity test generation MUST write `.zfa/receipts/test-<entity>.json` mapping each generated test to its usecase method and covered acceptance path, with SHA-256 digests of the test and its usecase source.

**FR-004** Drift detection: `zfa proof check` MUST flag a usecase/test pair whose usecase changed after the receipt was written, and MUST stay green when nothing drifted.

**FR-005** Suite consolidation: the three scattered test files MUST move under `test/plugins/test/`, and a direct `TestPlugin.generate` dispatch suite MUST cover orchestrator and polymorphic paths.

**FR-006** Analyzer parsing: `_parseUseCaseFile` MUST use the analyzer package AST instead of regexes, behavior-neutral on the existing fixtures (snapshot-tested).

**FR-007** Docs: openwiki/testing.md MUST show real native-mock generated output and document flavor detection (#354).

## Constraints

- Generated test semantics do NOT change — native mocks stay; no mocktail.
- Failing-first tests (red → green) for every new behavior.
- Validation: `dart analyze` + `dart test test/plugins/test/`.

## Change Guidance

- Do not alter the proof.v1 GenerationReceipt format; test receipts are a separate `test.v1` document kind in the same `.zfa/receipts/` directory.
- Do not change `TestBuilder` output content (the snapshot/parity bar applies to it too).
