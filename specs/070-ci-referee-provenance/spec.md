# Feature Specification: CI Referee + Provenance Dashboards

**Feature Branch**: `070-ci-referee-provenance`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "[ROADMAP P2] CI referee + provenance dashboards for the corpus run — request from issue #918 (https://github.com/arrrrny/zuraffa/issues/918). Absorbs old #847 and the SBOM rollup ask. Required: (1) golden workflow — zfa setup -> tdd corpus --stream -> per-feature verify gate -> gap ledger + coverage matrix, with a verdict comment per PR showing the feature x {mocked, real, hand-delta receipts} table with the exit-protocol legend; (2) provenance rollup — per-feature and corpus-wide generated/mock/hand-delta ratios, all receipt-verified (synergy with #812); (3) publishing gate — complete(real) everywhere = releasable, complete(mocked) publishes simulation/demo builds labeled as such; (4) failure artifacts — cycle-log excerpts + fix lines, never log walls."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - PR verdict comment shows the feature provenance table (Priority: P1)

A developer opens a pull request. The CI referee runs the golden workflow (setup, corpus verify, per-feature gates, gap ledger). It posts a structured comment on the PR showing a table of every feature's status: whether it is in mocked or real state, how many hand-delta receipts exist, and the generated/mock/hand-delta ratio. An exit-protocol legend at the bottom explains each status symbol. The reviewer can immediately see which features are fully realized, which are still mocked, and where manual code exists.

**Why this priority**: The PR verdict comment is the primary interface between the CI referee and the human reviewers. Without it, the referee's work is invisible and untrusted. A clear, structured table turns opaque CI pass/fail into actionable provenance information.

**Independent Test**: Can be tested by running the golden workflow on a repository with a mix of mocked, real, and hand-delta features and verifying the PR comment contains the correct table with accurate data for every feature.

**Acceptance Scenarios**:

1. **Given** a PR that modifies code in 3 features (1 mocked, 1 real, 1 with hand-delta receipts), **When** the CI referee completes, **Then** a comment is posted on the PR with a table showing each feature's state (mocked/real), receipt count, and generated/mock/hand-delta ratio, plus an exit-protocol legend.

2. **Given** the PR verdict comment exists, **When** a reviewer reads the table, **Then** they can determine at a glance which features are releasable (real everywhere) vs. which are simulation-only (mocked), without inspecting individual receipt files.

3. **Given** a PR with no feature changes (e.g., documentation only), **When** the CI referee runs, **Then** it posts a minimal verdict indicating no feature provenance was affected, rather than failing or posting an empty table.

---

### User Story 2 - Provenance rollup shows corpus-wide generated vs. hand-delta ratios (Priority: P1)

A product owner or tech lead opens the provenance dashboard. They see a corpus-wide summary: what percentage of the codebase is generated, what percentage is mock, and what percentage is hand-delta (manually written). These ratios are verified against the receipt ledger — every ratio is backed by actual receipt data, not heuristics. Per-feature breakdowns are also available, showing the same ratios for individual features.

**Why this priority**: The provenance rollup answers the fundamental question of the mock-first architecture: how much of the codebase is generated vs. hand-written? Without receipt-verified ratios, this is a guess; with them, it is an auditable fact. This is essential for release decisions and architectural governance.

**Independent Test**: Can be tested by generating a provenance rollup for a repository with known receipt data and verifying the ratios match the expected values (counted from the actual receipts).

**Acceptance Scenarios**:

1. **Given** a corpus with 10 features (8 fully generated, 1 with hand-delta, 1 fully hand-written), **When** the provenance rollup is generated, **Then** it reports 80% generated, 10% hand-delta, 10% hand-written, with per-feature breakdowns.

2. **Given** a provenance rollup is displayed, **When** a reviewer clicks on a per-feature ratio, **Then** they can see the individual receipts that back the ratio, with receipt IDs and verification status.

3. **Given** a receipt is added or modified, **When** the provenance rollup is regenerated, **Then** the ratios update to reflect the new receipt data, and the previous ratios are archived for historical comparison.

---

### User Story 3 - Publishing gate enforces real-only for production releases (Priority: P1)

A release manager triggers a production build. The publishing gate checks every feature's state: if all features are `complete(real)`, the build proceeds as a production release. If any feature is `complete(mocked)`, the gate blocks the production release and instead offers to publish a simulation/demo build with an explicit label. The gate never allows a mixed state (some real, some mocked) to be labeled as production.

**Why this priority**: The publishing gate is the enforcement point that prevents mock-only features from being shipped as production. Without it, the mock-first workflow's promise of "honest 90/10" breaks down at release time — someone could accidentally ship simulation code as real.

**Independent Test**: Can be tested by attempting a production release with all-real features (should succeed) and with one mocked feature (should block and offer simulation build).

**Acceptance Scenarios**:

1. **Given** all features in the corpus are in `complete(real)` state, **When** a production release is triggered, **Then** the publishing gate passes and the build is labeled as a production release.

2. **Given** one feature in the corpus is in `complete(mocked)` state, **When** a production release is triggered, **Then** the publishing gate blocks the release and offers a simulation/demo build labeled as such.

3. **Given** a simulation/demo build is published, **When** the build artifact is inspected, **Then** it carries an explicit simulation label that distinguishes it from production builds.

4. **Given** a feature transitions from `complete(mocked)` to `complete(real)` via `zfa tdd realize`, **When** the publishing gate runs next, **Then** the feature's state is reflected correctly and the gate outcome updates accordingly.

---

### User Story 4 - Failure artifacts show concise cycle-log excerpts, not log walls (Priority: P2)

A developer's PR has a failing test. The CI referee posts a failure comment that includes a concise excerpt from the cycle-log showing the specific failure, the failing line, and a suggested fix direction. It does not paste the entire test output or a wall of log text. The developer can immediately understand what failed and where to look, without scrolling through hundreds of lines of irrelevant output.

**Why this priority**: Failure diagnostics are the most frequent interaction with the CI referee. If failures produce walls of log text, developers stop reading them and start guessing. Concise, actionable failure artifacts are essential for maintaining developer trust in the CI system.

**Independent Test**: Can be tested by triggering a known test failure and verifying the failure comment contains a cycle-log excerpt (not a full log), the failing line, and a suggested fix direction.

**Acceptance Scenarios**:

1. **Given** a PR with a failing test, **When** the CI referee runs, **Then** it posts a failure comment containing: the failing test name, a concise excerpt from the cycle-log (max 20 lines), the specific failing assertion or line, and a suggested fix direction.

2. **Given** a PR with multiple failing tests, **When** the CI referee runs, **Then** it groups failures by feature and posts one excerpt per failure (not a concatenated wall), with a summary count at the top.

3. **Given** a failure comment exists, **When** a developer reads it, **Then** they can identify the root cause and the relevant file without needing to click through to the full CI log.

---

### Edge Cases

- What happens when a PR touches code that is not part of any feature (e.g., shared utilities)? The verdict table must include a "infrastructure" or "shared" row and not treat unfeatureized code as a gap.
- What happens when the receipt ledger is corrupt or missing for some features? The provenance rollup must mark those features as "receipt-unknown" rather than guessing or crashing.
- What happens when the publishing gate encounters a feature in an intermediate state (e.g., `realizing`)? The gate must treat intermediate states as non-releasable and not allow production builds.
- What happens when two PRs are merged in quick succession and both modify the same feature's receipts? The verdict must reflect the latest state; the system must handle concurrent receipt writes safely.
- What happens when the provenance dashboard is accessed but no receipts exist yet? The dashboard must show an empty state with a message indicating no features have been realized yet.
- What happens when a failure artifact exceeds the PR comment character limit? The system must truncate gracefully with a link to the full failure report, never silently dropping the failure.
- What happens when the golden workflow is interrupted mid-run (e.g., CI timeout)? The partial results must be preserved and the next run must resume from where it left off, not restart from scratch.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST execute a golden workflow: setup → corpus verify → per-feature verify gate → gap ledger + coverage matrix, as a single orchestrated CI pipeline.
- **FR-002**: System MUST post a structured verdict comment on every pull request showing a feature × state table (mocked, real, hand-delta receipts) with an exit-protocol legend.
- **FR-003**: System MUST generate a provenance rollup showing per-feature and corpus-wide generated/mock/hand-delta ratios, all verified against the receipt ledger.
- **FR-004**: System MUST enforce a publishing gate that allows production releases only when all features are `complete(real)`.
- **FR-005**: System MUST offer simulation/demo builds (labeled as such) when any feature is `complete(mocked)` and block unlabeled production builds.
- **FR-006**: System MUST produce failure artifacts as concise cycle-log excerpts with failing lines and suggested fix directions, never as full log dumps.
- **FR-007**: System MUST group multiple failures by feature in failure artifacts, with a summary count at the top.
- **FR-008**: System MUST handle PRs that do not touch any feature code by posting a minimal verdict with no feature table.
- **FR-009**: System MUST mark features with missing or corrupt receipts as "receipt-unknown" in the rollup and verdict.
- **FR-010**: System MUST preserve partial golden workflow results when interrupted, allowing the next run to resume rather than restart.
- **FR-011**: System MUST truncate failure artifacts that exceed the PR comment character limit, linking to the full report.
- **FR-012**: System MUST archive previous provenance ratios for historical comparison when new ratios are generated.
- **FR-013**: System MUST include a gap ledger in the golden workflow output listing any features that are not yet at their target state.
- **FR-014**: System MUST include a coverage matrix in the golden workflow output showing which features have been verified against which test tiers.
- **FR-015**: System MUST treat intermediate feature states (e.g., `realizing`) as non-releasable in the publishing gate.

### Key Entities

- **CI Referee**: The orchestrator of the golden workflow, responsible for running verification, generating verdicts, posting PR comments, and enforcing gates.
- **Golden Workflow**: The end-to-end CI pipeline: setup → corpus verify → per-feature gates → gap ledger + coverage matrix. The single authoritative verification sequence.
- **PR Verdict Comment**: A structured comment posted on pull requests showing the feature × state table with an exit-protocol legend, providing immediate provenance visibility.
- **Provenance Rollup**: A summary view (dashboard or report) showing per-feature and corpus-wide generated/mock/hand-delta ratios, receipt-verified and auditable.
- **Publishing Gate**: The enforcement point that decides whether a build can be released as production or must be labeled as simulation/demo.
- **Gap Ledger**: A list of features that are not yet at their target state (e.g., still mocked when the goal is real), generated as part of the golden workflow.
- **Coverage Matrix**: A table showing which features have been verified against which test tiers (unit, integration, contract, mutation), generated as part of the golden workflow.
- **Failure Artifact**: A concise, actionable excerpt from the cycle-log attached to failing tests, including the failing line and suggested fix direction.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every pull request receives a verdict comment within 2 minutes of the CI pipeline completing, containing an accurate feature × state table.
- **SC-002**: The provenance rollup ratios are 100% receipt-verified — every ratio can be traced to specific receipt files in the ledger.
- **SC-003**: The publishing gate correctly blocks production releases when any feature is in a non-real state, with zero false positives (never blocks a valid release).
- **SC-004**: Failure artifacts are under 50 lines per failure and contain the failing test name, cycle-log excerpt, failing line, and a suggested fix direction.
- **SC-005**: The golden workflow completes within the same time budget as the underlying corpus verify (no more than 10% overhead for referee operations).
- **SC-006**: Partial golden workflow results are preserved on interruption, and the next run resumes from the last completed step without repeating finished work.

## Assumptions

- The receipt ledger (#807) is the authoritative source of provenance data; the referee reads from it but does not modify it.
- The CI platform supports posting structured comments on pull requests and can handle the comment character limit gracefully.
- The publishing gate operates at build-time, not at merge-time, and has access to the feature state data.
- The gap ledger and coverage matrix are machine-readable outputs (JSON) that are also rendered as human-readable summaries in PR comments.
- Historical provenance ratios are stored in a persistent location (e.g., a file in the repository or a CI artifact) and are not ephemeral.
- The golden workflow is idempotent — running it twice on the same PR state produces the same verdict.
- The cycle-log excerpts are extracted from the existing cycle-log infrastructure, not generated separately; the referee formats them for brevity.
- The feature state model (mocked, real, realizing, etc.) is maintained by the existing state tracking infrastructure; the referee reads state but does not mutate it.
