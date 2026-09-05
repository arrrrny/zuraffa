# Feature Specification: Simulation Worlds — `zfa simulate --scenario` (virtual time, latency, failure storms)

**Feature Branch**: `spec/968-simulation-worlds`

**Created**: 2026-09-05

**Status**: Implemented

**Template Version**: `zuraffa-1.0`

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/968 — [VISION] simulation worlds: zfa simulate --scenario — certified golden worlds with virtual time, latency models, failure storms (VISION §9)"

## Context

Mock-first (#908–#915) delivered certified *mocks*: the #832 fixture worlds, the #1001 contract-tested Tier-1 mocks, the #960 dependency-row mocks, and the #913 realize differential. The missing half is **worlds**: scenario manifests that compose certified mocks into a coherent simulated reality with **time, latency, and failure semantics**. Without worlds, temporal feature classes (OCR pipelines, background sync, payments) cannot enter the TDD loop honestly: their defining behaviors are about *what happens over time and under failure*, which single-touchpoint mocks cannot express.

A **world** is a versioned, committed scenario manifest declaring:

- **touchpoints** — which certified mocks participate (from the spec's declared External Dependencies & Contracts table, issue #960's output)
- **time model** — virtual clock, deterministic seeds
- **latency model** — distributions per touchpoint (fast/slow/timeout bands)
- **failure schedule** — failure storms: auth expiry mid-flow, network flaps, partial writes
- **fixtures** — the golden corpora the world serves

Worlds live at `specs/<feature>/tdd/worlds/<scenario>.world.json` — committed, diffable, and CI-verifiable (`zfa simulate verify-world`). Every green run is attributable to a world version through a proof-carrying receipt (#807) that names the **world hash**; a mutated world invalidates the receipt. World runs are deterministically replayable (#806): same seed + same manifest → same run digest. World certification (#968's "never self-graded" rule) proves each touchpoint satisfies its *declared* contract by framework-executed invocation, and the differential gate (#915 composes) requires the same behaviors green against the mock world AND the real-adapter harness (direct binding, no world semantics).

Distinct from #908/#913 (those certify *adapters*; this certifies *realities composed from adapters*) and from #806 (replay re-executes history; worlds are the environment history runs in).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - `zfa simulate init <scenario>` scaffolds a world from the declared dependency table (Priority: P1)

A developer declares their feature's external touchpoints in the spec's External Dependencies & Contracts table (the #960 rail) and runs `zfa simulate init <scenario> --feature <feature>`. The command reads the declared rows, composes them into a committed, diffable world manifest (`specs/<feature>/tdd/worlds/<scenario>.world.json`) with a time model (deterministic seed + virtual clock), latency bands per touchpoint, a default failure-storm schedule (network flaps, auth expiry mid-flow, partial writes for the declared touchpoint kinds), and a golden corpus fixture table per declared contract method. The scaffolded world is then **certified** — the framework invokes every declared method through the world and writes `world-cert.json` — and refuses honestly when a declared contract has no servable fixture.

**Why this priority**: init is the entry point of the whole capability; without it no world exists to run against.

**Independent Test**: a workspace feature with a test-list declaring `FirebaseAuth | service | signIn(email, password) -> User, signOut() -> void | P1` and `RestSync | service | push(batch) -> SyncResult, pull(cursor) -> Page | P1`; `zfa simulate init checkout-flow --feature <f>` exits 0 with `simulate-init: scenario=checkout-flow feature=<f> touchpoints=2 certified=true world-hash=<sha256>`, and the manifest on disk declares both touchpoints, their parsed methods, the time/latency/failure models, and the corpus.

**Acceptance Scenarios**:

1. **Given** a feature with a declared dependency table, **When** `zfa simulate init <scenario> --feature <f>` runs, **Then** the world manifest is written (diffable JSON, deterministic given the same seed), every declared row appears as a touchpoint with its parsed contract methods, and the exit code is 0.
2. **Given** the scaffolded world, **Then** the framework certifies it (every declared method invoked through the world, per-method `satisfied: true` recorded in `world-cert.json` with the world hash) and appends the world manifest + cert receipt to the feature's cycle-log evidence (schema-1 hash chain).
3. **Given** a feature with no readable dependency table, **When** init runs, **Then** it refuses honestly (non-zero, fix hint naming `zfa tdd plan`) — never an empty world that silently passes.

### User Story 2 - `zfa simulate run <scenario>` executes the feature against the world; receipts record the world hash (Priority: P1)

A developer runs their feature's behaviors inside the world: `zfa simulate run <scenario> --feature <f>`. The command loads the manifest, recomputes the **world hash**, verifies the world's certification receipt matches the current hash (a mutated world fails here — the previous green is invalidated), executes the scenario deterministically under virtual time (latency bands advance the virtual clock, never wall time), fires the failure storms exactly where the schedule declares them, runs the differential gate (same behaviors against the mock world AND the direct real-adapter harness), and writes a proof-carrying run receipt naming the world hash, the seed, the run digest, and the verdict. Exit 0 is GREEN; any red play, certification mismatch, or differential drift is exit 1.

**Why this priority**: run is the TDD loop's green witness — the receipt is what makes every green attributable to a world version.

**Independent Test**: after init, `zfa simulate run checkout-flow --feature <f>` exits 0 with `simulate-run: scenario=checkout-flow world-hash=<h> verdict=GREEN plays=<n> drift=pass seed=<s>`, and `.zfa/receipts/world-run-checkout-flow.json` records the same world hash with `verdict: GREEN` and a run digest.

**Acceptance Scenarios**:

1. **Given** a certified world, **When** `zfa simulate run <scenario>` runs, **Then** the scenario executes deterministically (same seed → byte-identical play sequence → same run digest), latency never sleeps wall time (the run's virtual elapsed time >> wall time), and the receipt names the world hash.
2. **Given** a green run receipt, **When** the world manifest is mutated and run is re-invoked, **Then** the previous receipt is invalidated (no stale green can survive: the command reports the hash drift, exits 1, and the receipt on disk records the invalidation) with the fix `zfa simulate certify <scenario>`.
3. **Given** `--replay`, **Then** the run re-executes with the recorded seed and proves the run digest matches the recorded receipt (deterministic replay, #806 composes).
4. **Given** `--binding real` (or the differential phase), **Then** the same behaviors execute against the direct real-adapter harness (no latency, no storms, real clock) and the differential gate compares outcomes per behavior — drift is a named, red verdict.

### User Story 3 - A demo temporal feature (retry-with-backoff sync) is developed green entirely inside a world, with failure-storm scenarios as first-class red→green behaviors (Priority: P1)

The shipped reference feature `RetrySyncEngine` syncs a batch through a touchpoint with retry-with-exponential-backoff driven by the **virtual clock** (backoff waits advance virtual time; wall time stays ~0). Its world (`specs/968-simulation-worlds/tdd/worlds/checkout-flow.world.json`, committed in-repo) declares a network-flap storm over the sync touchpoint and an auth-expiry storm mid-flow. The failure-storm behaviors are first-class test-list behaviors: the engine survives the network-flap storm within its retry budget (green), surfaces auth expiry honestly (no blind retry storm), and repairs partial writes (the storm's half-written marker). A storm exceeding the retry budget is an honest RED sync — worlds never hand out free greens.

**Why this priority**: this is the acceptance heart of #968 — temporal classes can only enter the TDD loop when the loop can express time and failure.

**Independent Test**: `dart test test/simulation/worlds/retry_sync_engine_test.dart` — every test drives the engine inside `WorldRuntime` with storms active; the backoff path completes in ~0 wall ms while recording hundreds of virtual ms.

**Acceptance Scenarios**:

1. **Given** the network-flap storm (calls 2..4 fail 503), **When** the engine syncs with a 3-retry budget and exponential backoff, **Then** the sync succeeds on a later attempt, the outcome records every failed attempt, and the virtual clock advanced by the sum of latencies + backoffs (wall time ~0).
2. **Given** the auth-expiry storm mid-flow, **When** the engine hits it, **Then** the sync stops retrying auth-class failures (honest surface, no blind loop).
3. **Given** the partial-write storm, **When** the engine hits a half-written marker, **Then** it repairs the write (re-push) and the final state is consistent.
4. **Given** a storm that outlasts the retry budget, **When** the engine syncs, **Then** the sync is RED with the failure ledger — never a silent green.

### User Story 4 - World manifests are committed, diffable, and CI-verifiable (Priority: P2)

The world manifest is a small, sorted-key, stable-format JSON document under `specs/<feature>/tdd/worlds/` — a git diff shows exactly which touchpoint/latency/storm changed. `zfa simulate verify-world <scenario> --feature <f>` is the CI gate: the manifest parses, the recomputed world hash matches the committed certification receipt and the run receipt, and the declared touchpoint contracts are still satisfied. Any drift is exit 1 with the named delta.

**Why this priority**: CI-verifiability is what turns worlds from local convenience into a treaty.

**Independent Test**: `zfa simulate verify-world checkout-flow --feature <f>` exits 0; mutate the manifest (or any corpus fixture) → exit 1 naming the drift.

**Acceptance Scenarios**:

1. **Given** a committed, certified, green world, **When** `zfa simulate verify-world <scenario>` runs in CI, **Then** exit 0 with the hash triple (manifest, cert receipt, run receipt) agreeing.
2. **Given** any byte of the world drifted, **Then** verify-world exits 1 naming the drifted file and the expected/actual hash.
3. **Given** `zfa simulate certify <scenario>`, **Then** the world re-certifies LIVE (registry adds are re-proofs, never copies of old receipts — the #1001 discipline).

## Hard constraints

- Existing `zfa simulate` flag surface (`--scaffold`, `--feature`, `--fixtures`, `--scenario`, `--verify-guard`, `--family`, `--force`) is unchanged — `init`/`run`/`certify`/`verify-world` are added as subcommands.
- One PR for this spec; closes #968.
- Pure Dart, no Flutter SDK dependency (repo CI dart lane has no Flutter).
- World runs never dial sockets (the #832 network-isolation guard stays the floor).
- Receipts stay proof.v1-parseable (extra keys merge per the `saveNamed` contract, issue #996).
