# Feature Specification: Build Real GYM Exercises for zuraffa, zorphy, zikzak_inappwebview, vendure-flutter-sdk

**Feature Branch**: `022-gym-real-exercises`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "Build real GYM exercises for zuraffa, zorphy, zikzak_inappwebview, vendure-flutter-sdk: This feature originates from GitHub issue #397 (https://github.com/arrrrny/zuraffa/issues/397). Build concrete, real-world GYM training exercises across the zuraffa, zorphy, zikzak_inappwebview, and vendure-flutter-sdk packages so agents can be evaluated on genuine tasks."

## Summary

The four core packages we develop daily — zuraffa, zorphy, zikzak_inappwebview, and vendure-flutter-sdk — currently lack a real-world GYM presence. Unit tests prove the source compiles; GYM exercises prove an operator can actually *use* the package under load. This feature stands up a `.gym/` directory in each of the four packages, with mandatory warmup reps and graded exercises that train and evaluate agents on genuine dev tasks, not re-skinned unit tests.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Warmup reps establish baseline reflexes across all four packages (Priority: P1)

As an agent operator, I want each of the four packages to carry mandatory warmup reps (resolve deps, build, smoke call) so that any graded exercise is gated behind proof the operator can drive the package at all.

**Why this priority**: Without warmup reps, graded exercises cannot be meaningfully evaluated. Warmups are the prerequisite for every other story.

**Independent Test**: Can be fully tested by running each package's warmup reps (`.gym/warmup/*`) in isolation and confirming exit 0. Delivers value immediately: a developer (human or agent) can verify the package is functional before attempting graded work.

**Acceptance Scenarios**:

1. **Given** the zuraffa package is cloned and `dart` is on PATH, **When** warmup reps `.gym/warmup/01-deps.dart`, `02-build.dart`, and `03-smoke.dart` are executed, **Then** all three exit 0 and produce structured success output.
2. **Given** the zorphy package is cloned, **When** its warmup reps resolve dependencies, build the package, and perform an authenticated smoke call, **Then** all reps exit 0.
3. **Given** the zikzak_inappwebview package is cloned, **When** its warmup reps resolve dependencies, build the example app, and perform a bridge smoke call, **Then** all reps exit 0.
4. **Given** the vendure-flutter-sdk package is cloned, **When** its warmup reps resolve dependencies, build the package, and perform a Vendure API smoke call, **Then** all reps exit 0.

---

### User Story 2 — Graded exercises prove real-world capability per package (Priority: P1)

As an agent operator, I want each package to carry at least one graded exercise that represents a genuine dev task — not a unit test — so that agents can be evaluated on real-world capability under load.

**Why this priority**: This is the core deliverable of issue #397. Warmup reps (Story 1) gate this; graded exercises are the actual training payload.

**Independent Test**: Can be fully tested by running each package's graded exercise via `dart run .gym/exercise-*.dart` and confirming exit 0 or structured exit non-zero with DROP CARD for mis-fires.

**Acceptance Scenarios**:

1. **Given** the zuraffa package, **When** the graded exercise runs `zuraffa generate` for a feature, builds the generated app, and hits a generated route, **Then** the response shape matches expectations and exit 0.
2. **Given** the zorphy package, **When** the graded exercise opens a store, dispatches a mutation, and asserts subscribers received it, **Then** state propagation is confirmed and exit 0.
3. **Given** the zikzak_inappwebview package, **When** the graded exercise boots the example, evaluates JS in the bridge, and asserts the message round-trips, **Then** the round-trip succeeds and exit 0.
4. **Given** the vendure-flutter-sdk package, **When** the graded exercise initializes the client, fetches a product by id, and asserts the returned fields exist and are typed, **Then** the shape assertion passes and exit 0.

---

### User Story 3 — gym.yaml is consumable by the miki GYM runner across all four packages (Priority: P2)

As a developer, I want each package's `.gym/gym.yaml` to match the artifact format consumed by the miki GYM runner so that exercises are runnable headless by CI and agent orchestration tools.

**Why this priority**: Integration with the GYM runner (miki) is essential for automated evaluation, but the exercises themselves (Stories 1–2) must exist before they can be registered.

**Independent Test**: Can be fully tested by running the miki GYM runner against each package and confirming all registered exercises execute and grade correctly.

**Acceptance Scenarios**:

1. **Given** a package with `.gym/gym.yaml`, **When** the miki GYM runner parses the YAML, **Then** it finds all canonical keys: `name`, `version`, `warmup`, `exercises`, and each exercise has `id`, `brief`, `setup`, `verifyCommand`, and `evaluate`.
2. **Given** the gym.yaml for each package, **When** the runner executes the warmup and exercise boards, **Then** each board completes with structured exit codes (0 = pass, non-zero = fail).
3. **Given** the zuraffa package's existing `.gym/gym.yaml`, **When** new exercises are added, **Then** the existing warmup and exercise entries remain valid and are not broken.

---

### User Story 4 — Mis-fires produce DROP CARDs with actionable diagnostics (Priority: P2)

As an agent operator, I want any unexpected outcome during exercise execution (not a clean fail) to produce a DROP CARD capturing Did / Expected / Happened / Where so that mis-fires are discoveries, not buried bugs.

**Why this priority**: Across four packages developed daily, mis-fires are expected and valuable. Without structured reporting, they become invisible regressions.

**Independent Test**: Can be fully tested by triggering a known mis-fire condition (e.g., an exercise producing unexpected output) and confirming a DROP CARD is generated with the required fields.

**Acceptance Scenarios**:

1. **Given** an exercise produces output that does not match the expected shape, **When** the exercise detects the mismatch, **Then** it emits a DROP CARD with fields: Did, Expected, Happened, Where.
2. **Given** a mis-fire occurs, **When** the DROP CARD is emitted, **Then** the exercise exits non-zero and the card is surfaced to the operator (not silently swallowed).

---

### Edge Cases

- What happens when a package's dependencies cannot be resolved (network failure, missing credentials)? The warmup rep should fail fast with a clear setup error, not a misleading grade.
- What happens when a graded exercise targets an API that is not available in the test environment (e.g., Vendure server down)? The exercise should fail with a clear "service unavailable" message and exit non-zero.
- What happens when the exercise sandbox cannot be created (permissions, disk full)? The exercise should fail fast before attempting any work.
- What happens when a warmup rep passes but the graded exercise depends on a different build state? Each exercise must explicitly re-verify its prerequisites rather than assuming warmup state persists.
- What happens when the miki GYM runner version is incompatible with the gym.yaml format? The exercise should detect and report the version mismatch rather than silently producing wrong output.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Each of the four packages (zuraffa, zorphy, zikzak_inappwebview, vendure-flutter-sdk) MUST have a `.gym/` directory containing warmup reps and graded exercises.
- **FR-002**: Each package's warmup MUST include at minimum: dependency resolution, build, and one authenticated smoke call — as mandatory reps that gate graded exercises.
- **FR-003**: Each package MUST have at least one graded exercise that represents a genuine dev task (not a re-skinned unit test) with a `verifyCommand` and `evaluate` rule.
- **FR-004**: Each package's `.gym/gym.yaml` MUST be consumable by the miki GYM runner without modification to the runner.
- **FR-005**: All exercises MUST run in isolated sandboxes and MUST NOT mutate the package source tree.
- **FR-006**: Mis-fires (unexpected outcomes, not clean failures) MUST produce DROP CARDs capturing Did / Expected / Happened / Where.
- **FR-007**: Exercise grading MUST be exit-code-based: exit 0 = pass, exit non-zero = fail.
- **FR-008**: zuraffa's existing `.gym/` exercises MUST remain valid after adding new exercises (no regressions to existing warmup or exercise entries).

### Key Entities

- **GYM Warmup Rep**: A mandatory, non-graded exercise step that proves the operator can drive the package (resolve deps, build, smoke). Each rep has an `id`, `name`, and `command`.
- **GYM Exercise**: A graded training unit with a `brief` (what it trains), `setup` (prerequisites), `verifyCommand` (what runs), and `evaluate` (how to grade). Exercises are identified by unique `id`.
- **GYM Manifest**: The `gym.yaml` file that registers all warmup reps and exercises for a package, consumable by the miki GYM runner.
- **DROP CARD**: A structured mis-fire report with fields Did, Expected, Happened, Where — produced when an exercise encounters an unexpected outcome.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All four packages have a `.gym/` directory with at least one warmup rep and one graded exercise that actually runs against the package.
- **SC-002**: Each package's `gym.yaml` is parseable and executable by the miki GYM runner without errors.
- **SC-003**: Zero existing exercises regress (all pre-existing warmup and exercise entries in zuraffa's `.gym/` continue to pass).
- **SC-004**: Mis-fires during exercise execution produce structured DROP CARDs with all four required fields.

## Assumptions

- The GYM artifact format (`.gym/gym.yaml` with `warmup` and `exercises` arrays) is the authoritative structure, as established by the existing zuraffa `.gym/` and the `gym` plugin.
- The miki GYM runner (github.com/arrrrny/miki) is the intended consumer of these exercises and does not need modifications to consume the new packages' `gym.yaml` files.
- Each target package is cloned or accessible at exercise-time; exercises do not install or clone packages themselves.
- The DROP CARD format (github.com/arrrrny/drop-card) is the established convention for mis-fire reporting in the GYM ecosystem.
- Warmup reps are mandatory prerequisites; graded exercises may assume warmup completion but should not depend on transient warmup state.
- This feature modifies only `.gym/` directories in each target package; no source code changes to `lib/` are required in the zuraffa repo itself (the other three packages are separate repositories).
