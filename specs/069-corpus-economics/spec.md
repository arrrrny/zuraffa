# Feature Specification: Corpus Economics — Verify in Minutes

**Feature Branch**: `069-corpus-economics`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "[ROADMAP P2] Corpus economics: all-120 verify in minutes (measured data attached) — request from issue #916 (https://github.com/arrrrny/zuraffa/issues/916). Measured live on an Intel Mac with 4 features / 76 tests: zfa build takes 1m08s, full suite 2m21s, ONE refactor (2 suite runs + build) takes 9m30s — and the default 10m step timeout sits on a knife edge (killed at 10m00s; identical run passed manually at 9m30s). Required: (1) incremental verification — refactor re-proof scoped to pass-registry-changed files, full-suite proof once per feature completion + nightly, with the full gate still existing but its frequency engineered; (2) batched gen/verify-red (tdd gen --all lineage) to cut per-behavior dart test spawns; (3) sharding + concurrency for the corpus lane, with budget telemetry (wall-clock per step, suite seconds, mutant count) in JSON verdicts; (4) baseline cache reuse extended corpus-wide (builds on #741 machinery, live-verified). Acceptance: 120-spec corpus full verify <= 30 min on this hardware class; per-PR corpus lane <= 10 min via sharding."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Full corpus verification completes within 30 minutes (Priority: P1)

A developer runs the full 120-spec corpus verification suite. Today this takes unbounded time and frequently hits step timeouts on standard hardware. After this feature, the full corpus verify — all 120 specs, all test tiers, all mutation checks — completes within 30 minutes on the reference hardware class (Intel Mac). The developer receives a JSON verdict summarizing wall-clock time, per-step suite seconds, and mutant counts for every shard.

**Why this priority**: The full corpus verify is the quality gate that every PR must eventually pass. If it takes unbounded time or crashes from timeouts, it becomes a bottleneck that developers work around rather than trust. Making it finish in a predictable, bounded window is the foundation of everything else.

**Independent Test**: Can be fully tested by running the full corpus verify on the reference hardware and measuring total wall-clock time against the 30-minute target. The JSON verdict must be parseable and contain all required telemetry fields.

**Acceptance Scenarios**:

1. **Given** the full 120-spec corpus exists, **When** the developer runs the full corpus verify command, **Then** it completes within 30 minutes on reference hardware and produces a JSON verdict with per-step timing and mutant counts.

2. **Given** a full corpus verify is running, **When** the developer inspects the JSON verdict, **Then** it contains wall-clock total, per-shard breakdowns, per-step suite seconds, and mutant counts for every spec.

3. **Given** the full corpus verify completes, **When** any individual shard exceeds its allocated time budget, **Then** the verdict reports which shard went over budget and by how much, without killing the entire run.

---

### User Story 2 - Per-PR corpus lane completes within 10 minutes via sharding (Priority: P1)

A developer opens a pull request. The CI pipeline runs the corpus lane — a scoped subset of the full corpus relevant to the changed features — in parallel shards. Each shard runs concurrently, reusing cached build artifacts from previous runs. The entire per-PR corpus lane finishes within 10 minutes, providing fast feedback without waiting for the full 30-minute verify.

**Why this priority**: Developers get feedback from the per-PR lane much more frequently than from the full corpus. If the per-PR lane is slow, it delays every merge decision. Sharding and caching are the mechanisms that bring it under 10 minutes.

**Independent Test**: Can be tested by simulating a PR that touches a subset of features and running the per-PR corpus lane, measuring total wall-clock time against the 10-minute target. Each shard should run concurrently (measurable by comparing wall-clock vs. cumulative CPU time).

**Acceptance Scenarios**:

1. **Given** a PR that touches 20 of 120 specs, **When** the per-PR corpus lane runs, **Then** it completes within 10 minutes using concurrent sharding and cached build artifacts.

2. **Given** the per-PR corpus lane is running, **When** the developer inspects the shard status, **Then** each shard reports its progress, remaining time estimate, and whether it reused a cached build.

3. **Given** a per-PR lane completes, **When** the verdict is compared to a full corpus run covering the same specs, **Then** the per-PR lane produces identical pass/fail results for the overlapping specs.

---

### User Story 3 - Incremental verification scopes refactor re-proof to changed files (Priority: P1)

A developer refactors a single entity. Today, the refactor step requires running the full test suite twice (once to prove red, once to prove green) plus a build — totaling 9m30s and teetering on the 10m timeout. After this feature, the refactor re-proof is scoped to only the files affected by the change (determined by a pass-registry), reducing the re-proof to a fraction of the full suite. The full suite still runs once per feature completion and nightly, but its frequency is engineered rather than every refactor.

**Why this priority**: The refactor step is the most frequent operation in the TDD loop. Every refactor that takes 9m30s instead of under 2 minutes accumulates into hours of wasted developer time per day. Scoping the re-proof to changed files is the highest-leverage optimization.

**Independent Test**: Can be tested by refactoring a single entity's file and measuring the re-proof wall-clock time against the target (under 2 minutes on reference hardware). The re-proof must only run tests whose pass-registry entries reference the changed file.

**Acceptance Scenarios**:

1. **Given** a developer refactors one file in entity X, **When** the incremental re-proof runs, **Then** it executes only the tests registered against that file (or transitively dependent files) and completes in under 2 minutes.

2. **Given** an incremental re-proof passes, **When** the developer checks the pass-registry, **Then** only the affected test entries are refreshed; unchanged test entries are untouched.

3. **Given** a feature reaches `complete(mocked)` or `complete(real)`, **When** the full-suite gate triggers, **Then** it runs the complete test suite for that feature (not the incremental subset) and records a full-suite proof receipt.

4. **Given** it is midnight, **When** the nightly full-suite gate triggers, **Then** the full corpus runs against all specs and produces a nightly verification receipt.

---

### Edge Cases

- What happens when a changed file is transitively depended on by tests in many features? The incremental re-proof must include all transitively affected tests; the pass-registry dependency graph must be complete and accurate.
- What happens when the pass-registry is stale or missing entries for a file? The incremental re-proof must fall back to a full-suite run for that feature, logging a warning that the pass-registry was incomplete.
- What happens when a shard in the per-PR lane crashes or hangs? The shard must be killed after its time budget, marked as failed in the verdict, and other shards must continue. The overall lane verdict must report the failed shard.
- What happens when cached build artifacts are corrupt or from an incompatible version? The cache must detect staleness (e.g., via a content hash of the build inputs) and rebuild from scratch rather than using a stale cache.
- What happens when two PRs are open simultaneously and their per-PR lanes overlap? Each lane must operate independently; cache sharing between lanes is permitted but must not cause cross-contamination.
- What happens when the 120-spec corpus grows to more than 120? The 30-minute target must scale proportionally; the system must not have a hard ceiling at 120.
- What happens when the reference hardware class changes (e.g., team moves to Apple Silicon)? The timing targets are guidelines, not hard contracts; the verdict must report actual times so the targets can be adjusted.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a full corpus verify command that runs all specs in the corpus and completes within the configured time budget (default: 30 minutes on reference hardware).
- **FR-002**: System MUST produce a JSON verdict after every verify run containing: total wall-clock time, per-shard breakdowns, per-step suite seconds, and mutant counts.
- **FR-003**: System MUST shard the corpus into parallel lanes for the per-PR verify, with each shard running concurrently.
- **FR-004**: System MUST reuse cached build artifacts across verify runs, with staleness detection based on content hashing of build inputs.
- **FR-005**: System MUST scope incremental re-proofs to only the files affected by a change, as determined by a pass-registry dependency graph.
- **FR-006**: System MUST refresh pass-registry entries only for tests that are transitively affected by a changed file; unchanged entries must not be re-evaluated.
- **FR-007**: System MUST trigger a full-suite gate once per feature completion (when state reaches `complete(mocked)` or `complete(real)`) and once nightly.
- **FR-008**: System MUST batch generation and verification steps (gen/verify-red) to minimize per-behavior test spawns, reducing overhead from individual test invocations.
- **FR-009**: System MUST kill shards that exceed their allocated time budget, mark them as failed in the verdict, and allow other shards to continue.
- **FR-010**: System MUST fall back to a full-suite re-proof for a feature when the pass-registry is incomplete or missing entries for changed files.
- **FR-011**: System MUST detect stale or corrupt cached build artifacts and rebuild from scratch rather than using invalid cache.
- **FR-012**: System MUST record verification receipts in the feature's provenance ledger, linking incremental and full-suite results.
- **FR-013**: System MUST extend baseline cache reuse (from #741) across the entire corpus, not just individual features.
- **FR-014**: System MUST allow the time budget to be configurable per hardware class, with the 30-minute default applying to the reference Intel Mac configuration.
- **FR-015**: System MUST report per-PR lane results that are identical to full-corpus results for overlapping specs.

### Key Entities

- **Corpus Verify**: The top-level command that orchestrates the verification of all specs in the corpus, either as a full run or a scoped per-PR subset.
- **Shard**: A parallel unit of corpus work, running a subset of specs concurrently with other shards. Each shard has its own time budget and produces its own sub-verdict.
- **JSON Verdict**: The structured output of a verify run, containing timing telemetry, pass/fail status, mutant counts, and shard breakdowns. Machine-readable for CI integration.
- **Pass-Registry**: A dependency graph mapping source files to the tests that exercise them, used to scope incremental re-proofs to only the affected tests.
- **Incremental Re-Proof**: A scoped verification that runs only the tests transitively affected by a file change, significantly faster than a full-suite run.
- **Full-Suite Gate**: A periodic verification that runs the complete test suite for a feature or the entire corpus, triggered by feature completion or nightly schedule.
- **Build Cache**: Reusable build artifacts keyed by content hash of build inputs, shared across verify runs and shards to avoid redundant compilation.
- **Baseline Cache**: The cached build state from #741, extended corpus-wide to provide warm starts for all verify operations.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Full 120-spec corpus verify completes within 30 minutes on reference Intel Mac hardware.
- **SC-002**: Per-PR corpus lane completes within 10 minutes on reference hardware, using concurrent sharding.
- **SC-003**: Incremental re-proof for a single-file refactor completes in under 2 minutes on reference hardware.
- **SC-004**: JSON verdicts contain all required telemetry fields (wall-clock, per-shard, suite seconds, mutant counts) and are machine-parseable.
- **SC-005**: Build cache hit rate exceeds 80% for repeat verify runs on the same hardware with no code changes.
- **SC-006**: Per-PR lane results are bit-identical to full-corpus results for overlapping specs (no false positives or false negatives from sharding).
- **SC-007**: No verify step exceeds its configured time budget; shards that exceed budget are killed and reported as failed without killing the entire run.

## Assumptions

- The pass-registry dependency graph is maintained accurately by the generation toolchain and covers all transitively affected tests.
- The baseline cache infrastructure from #741 is landed and functional; this feature extends it corpus-wide rather than building it from scratch.
- The reference hardware class (Intel Mac) is representative of the development team's primary machines; Apple Silicon targets can be calibrated separately.
- The JSON verdict format is compatible with existing CI tooling and can be consumed by status checks on pull requests.
- Sharding granularity (number of shards, spec allocation per shard) is auto-tuned based on available parallelism and corpus size, with manual override available.
- The nightly full-suite gate runs in a dedicated CI environment, not on developer machines.
- The 30-minute and 10-minute targets are performance goals, not hard SLAs; the system must report actual times so targets can be adjusted as hardware and corpus evolve.
- Mutant testing is part of the verify pipeline; mutant counts in the verdict reflect the number of mutants killed, survived, or timed out per spec.
