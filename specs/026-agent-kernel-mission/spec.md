# Feature Specification: Mission Coalescing, Cancellation & Partial-Salvage Semantics

**Feature Branch**: `026-agent-kernel-mission`

**Created**: 2026-08-28

**Status**: Draft

**Input**: GitHub issue [#388](https://github.com/arrrrny/zuraffa/issues/388) — agent kernel: mission coalescing, cancellation and partial-salvage semantics

## User Scenarios & Testing *(mandatory)*

### User Story 1 — Deduplicate Identical Concurrent Missions (Priority: P1)

When multiple users submit identical or equivalent missions at nearly the same time (e.g. thousands of ZikZak users scanning the same product on Black Friday), only one mission actually executes. All subsequent callers receive the same results via a shared event stream.

**Why this priority**: Without coalescing, the system would run thousands of redundant missions for the same query, wasting compute and bandwidth. This is the core efficiency mechanism of the agent kernel.

**Independent Test**: Submit 50 identical mission requests concurrently. Verify exactly one mission executes and all 50 callers receive completion and partial-progress events.

**Acceptance Scenarios**:

1. **Given** 50 concurrent missions with identical spark type, normalized value, country, and strategy variant, **When** all 50 are submitted within the coalescing window, **Then** exactly one mission executes and all 50 callers receive the same completion events.
2. **Given** a coalesced mission is already running and new identical missions are submitted, **When** the new callers join, **Then** they immediately receive all pending partial-progress events that occurred before their subscription.
3. **Given** two missions that differ only in strategy variant, **When** submitted concurrently, **Then** each runs as a separate mission (no cross-variant coalescing).

---

### User Story 2 — Cancel a Mission With Full Resource Cleanup and Partial Salvage (Priority: P1)

When a running mission is cancelled (by the user, a policy, or a timeout), the system disposes all resources held by that mission (webview pools, network streams, open connections) and preserves any intelligence or partial results gathered up to the point of cancellation. No resource leaks occur.

**Why this priority**: Without safe cancellation, missions could leave orphaned webviews, unclosed streams, and wasted memory. Partial salvage ensures that even aborted work still warms the cache and feeds downstream intelligence.

**Independent Test**: Start a long-running mission, cancel it mid-execution, then verify all resources are released and partial results are persisted with a `cancelled_partial` outcome.

**Acceptance Scenarios**:

1. **Given** a mission is executing a webview-heavy step, **When** cancellation is triggered, **Then** the webview is disposed via the pool, captured network entries are emitted, and partial sightings are persisted under a `cancelled_partial` outcome.
2. **Given** a mission is executing a scraper step, **When** cancellation is triggered, **Then** the in-flight request is aborted, any partial response is returned, and the partial data is persisted.
3. **Given** a mission is cancelled, **When** the cancellation completes, **Then** a post-cancellation assertion confirms the webview pool is empty, streams are closed, and no orphaned handles remain.

---

### User Story 3 — Introspect Active Coalesced Missions and Subscribers (Priority: P2)

Operators and policy hooks can query the kernel to see which missions are currently active, how many callers are subscribed to each, and the coalescing window configuration. This enables monitoring, debugging, and policy-driven decisions.

**Why this priority**: Observability is essential for operators to verify coalescing is working correctly and to make policy decisions (e.g. escalating when subscriber count exceeds a threshold).

**Independent Test**: While a coalesced mission is running with multiple subscribers, query the kernel for `activeMissions` and `waitingSubscribers` and verify the returned data matches the actual state.

**Acceptance Scenarios**:

1. **Given** a coalesced mission with 30 active subscribers, **When** an operator queries `activeMissions`, **Then** the mission appears with its key, status, and subscriber count.
2. **Given** the coalescing window configuration is set, **When** an operator queries it, **Then** the current window duration is returned.
3. **Given** a coalesced mission completes, **When** the operator queries again, **Then** the mission no longer appears in active missions.

---

### User Story 4 — Serve Cached Outcome on Re-Submission (Priority: P2)

When a mission with the same key is submitted again within a configurable TTL after it has already completed, the system returns the cached outcome instead of re-executing the mission. This avoids redundant work for repeated identical queries.

**Why this priority**: Idempotency guards prevent wasted compute on repeated submissions and improve perceived responsiveness for callers who re-submit before knowing the previous result arrived.

**Independent Test**: Complete a mission, then immediately re-submit an identical mission. Verify the cached outcome is returned without re-execution. Wait for TTL to expire, then re-submit and verify the mission runs again.

**Acceptance Scenarios**:

1. **Given** a mission with key K has completed within TTL, **When** an identical mission is submitted, **Then** the cached outcome is returned immediately without re-execution.
2. **Given** a mission with key K has completed but TTL has expired, **When** an identical mission is submitted, **Then** the mission executes fresh and produces a new outcome.
3. **Given** the idempotency feature is disabled, **When** an identical mission is submitted, **Then** the mission executes fresh regardless of prior completion.

---

### User Story 5 — Subscriber Survives Original Mission Cancellation (Priority: P2)

When the original caller of a coalesced mission cancels, the subscribers are not cancelled. The kernel either continues executing, escalates to a new mission, or serves accumulated partials and re-runs as needed, per the active policy.

**Why this priority**: One user cancelling their request should not disrupt the other 9,999 users waiting for the same result.

**Independent Test**: Submit 50 coalesced missions. Cancel the original (first) caller. Verify all 49 remaining subscribers continue to receive events and eventually receive results.

**Acceptance Scenarios**:

1. **Given** a coalesced mission with 10 subscribers, **When** the original caller cancels, **Then** the mission continues executing for the remaining subscribers.
2. **Given** the original caller cancels and the kernel policy dictates escalation, **When** the cancellation is processed, **Then** a new mission is started to replace the cancelled one, and all subscribers are re-attached.
3. **Given** the original caller cancels and partial results exist, **When** the policy serves partials, **Then** subscribers receive the partial results with an indicator that the original execution was incomplete.

---

### User Story 6 — Mixed-Load Stability (Priority: P3)

Under a realistic production load of many concurrent missions with a high duplication rate, the kernel maintains stability: no deadlocks, bounded memory growth, and correct coalescing/cancellation behavior for every mission.

**Why this priority**: Reliability under load validates that the coalescing, cancellation, and salvage semantics work correctly at scale, not just in unit scenarios.

**Independent Test**: Run 200 mixed missions where 80% share duplicate keys. Verify no deadlocks, memory stays bounded, and all missions (unique and coalesced) complete or cancel cleanly.

**Acceptance Scenarios**:

1. **Given** 200 missions submitted with 80% duplicate keys, **When** all missions run to completion or cancellation, **Then** no deadlocks occur and all callers receive their expected results or cancellation signals.
2. **Given** the same 200-mission load, **When** memory is measured throughout execution, **Then** memory usage stays within a bounded range and does not grow linearly with the number of duplicate submissions.
3. **Given** a mix of unique and coalesced missions, **When** some are cancelled and some complete normally, **Then** every mission's resources are properly cleaned up and partial results are preserved where applicable.

---

### Edge Cases

- What happens when the coalescing window expires while new identical missions are still arriving? — The next batch should form a new coalescing group.
- What happens when the original mission fails (not cancelled) while subscribers are waiting? — Subscribers should receive the failure event; the kernel may or may not retry per policy.
- What happens when a cancelled mission has zero partial results? — The outcome is still recorded as `cancelled_partial` (an empty salvage is still a salvage).
- What happens when two missions have the same key but different callers submit them outside the coalescing window? — Each runs independently; the idempotency cache serves the earlier result if still within TTL.
- What happens when the TTL for cached outcomes is set to zero (disabled)? — Every submission runs fresh; no cached outcomes are served.
- What happens when a subscriber disconnects before the coalesced mission completes? — The subscriber is removed from the fan-out list; other subscribers are unaffected.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The kernel MUST coalesce identical missions at entry using a composite key derived from spark type, normalized value, country, and strategy variant.
- **FR-002**: For coalesced missions, the kernel MUST execute the mission only once and fan out completion and partial-progress events to all subscribers.
- **FR-003**: Cancellation of the original mission MUST NOT cancel subscribers — the kernel MUST either continue, escalate, or serve partials per the active policy.
- **FR-004**: On cancellation, the kernel MUST trigger a grace period for tools to flush resources (dispose webviews, abort requests, close streams) before forcing teardown.
- **FR-005**: Partial results and partial sightings from a cancelled mission MUST be salvaged into the mission record with an outcome of `cancelled_partial`.
- **FR-006**: A post-cancellation assertion MUST verify zero resource leaks (empty webview pool, closed streams, no orphaned handles).
- **FR-007**: The kernel MUST support idempotency: re-submitting a completed mission key within the configured TTL returns the cached outcome without re-execution.
- **FR-008**: The kernel MUST expose introspection endpoints for `activeMissions`, `waitingSubscribers`, and coalescing window configuration.
- **FR-009**: The kernel MUST document its single-isolate assumption and provide an extension point for future multi-isolate pool support.
- **FR-010**: The coalescing window duration MUST be configurable.

### Key Entities

- **Mission**: A unit of agent work submitted by a caller, identified by a composite key (spark type + normalized value + country + strategy variant). Carries status, outcome, partial results, and a subscriber list.
- **Coalescing Group**: A set of missions sharing the same key within the coalescing window. Exactly one mission in the group executes; the rest subscribe to its event stream.
- **CancelToken**: A signal that triggers the cancellation and salvage protocol for a running mission, initiating the grace period and resource teardown sequence.
- **Mission Outcome**: The terminal state of a mission — one of `completed`, `cancelled_partial`, `failed`, or `cached_served`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: When 50 identical missions are submitted concurrently, exactly 1 mission executes and all 50 callers receive the results — zero redundant executions.
- **SC-002**: A mid-execution cancellation disposes all resources (webview pool empty, streams closed) with zero leaked handles, verified by post-cancellation assertion.
- **SC-003**: Under a load of 200 mixed missions with 80% duplicate keys, no deadlocks occur and memory usage remains bounded throughout execution.
- **SC-004**: A completed mission re-submitted within TTL returns the cached outcome without triggering a new execution; after TTL expiry, a fresh execution occurs.

## Assumptions

- The agent kernel operates within a single isolate; multi-isolate pool support is a documented extension point, not part of this feature.
- The coalescing key derivation (hashing spark type + normalized value + country + strategy variant) is deterministic and collision-resistant.
- Tools that participate in cancellation (webview pool, scraper) support a grace period callback for flushing resources before teardown.
- The `CancelToken` mechanism is provided by the `AgentRuntimePlugin` kernel host (issue #386 dependency).
- Default coalescing window and TTL values are configurable at startup; reasonable defaults exist for each.
- The partial-salvage protocol stores results in the same persistence layer used for mission records (no separate storage system required).
- The idempotency cache is bounded and evicts oldest entries when full; exact eviction policy is an implementation detail.
