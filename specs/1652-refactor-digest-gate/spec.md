# Feature Specification: Phase-1 refactor digest gate — inherit make's certified post-state

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1652-refactor-digest-gate`

**Created**: 2026-09-15

**Status**: Draft

**Input**: User description: "Issue #1652 (perf) — on a forward `zfa tdd run`, every behavior pays one full refactor pipeline (preflight suite + `zfa build` + `dart format` + `dart fix` + re-proof) immediately after its make just certified green; the #1624 pass-batch ledger can never inherit between consecutive behaviors because forward progress changes `lib/` on every make (N behaviors ⇒ N full preflights). Measured: ~26 s refactor per behavior on the zcalc probe (~50% of the per-behavior cycle cost), of which the full-suite preflight is ~15 s and the pass registry ~10 s with `applied: 0 actions, no-op: true`."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The refactor right after a make inherits make's proof (Priority: P1)

An operator runs a forward `zfa tdd run` over N behaviors. Each behavior's
make certifies green on a tree that — between that make-green and the
behavior's phase-1 refactor spawn — is touched by no human and no external
process (the loop is machine-driven inside one run invocation). The
refactor spawn recognizes that byte-identical situation and inherits
make's fresh evidence: zero suite spawns, zero pass-registry spawns, a
clean no-op with honest evidence naming what was inherited and from which
make. The measured ~26 s per-behavior refactor collapses to the cost of
two tree snapshots and a file read.

**Why this priority**: This is the perf bug itself — O(behaviors ×
suite-time) per feature spent re-proving what the run proved seconds
earlier.

**Independent Test**: With a make-certified post-state recorded for the
current tree, a `--pass-batch` refactor spawn completes with zero suite
spawns and an honest inheritance line in its output and cycle-log entry.

**Acceptance Scenarios**:

1. **Given** a make green-applied and recorded its certified tree state,
   and the tree is byte-identical at the refactor spawn, **When** the
   driving run's phase-1 refactor spawn executes with the pass-batch
   opt-in, **Then** the pipeline is inherited: zero suite spawns, exit 0,
   and the output + cycle-log name the inheritance, the make it inherited
   from, and the fact that the full suite did not run at this tree.
   **Type**: acceptance
2. **Given** the same recorded post-state but an EXTERNAL edit to `lib/`
   or `test/` between the make and the refactor spawn, **When** the
   refactor spawn executes, **Then** the full pipeline runs (preflight +
   registry + re-proof) — a drifted tree is never inherited.
   **Type**: acceptance

---

### User Story 2 - Every mismatch falls back to the full pipeline (Priority: P2)

The inheritance is keyed on the same gate context the #1588 pass-batch
ledger uses: same suite template, same baseline content, same suite
configuration (`dart_test.yaml` + `pubspec.lock`), same exempt set, and
byte-identical `lib/` AND `test/` trees. Any context mismatch, tree
drift, corrupt or mistyped record, `--full-reproof` request, or a
flag-less standalone refactor falls back to the full pipeline — the
absolute-green contract (spec 048 FR-001) stands unchanged for
standalone use, and an explicit request for the strongest proof is always
answered by running it.

**Why this priority**: The perf win is only safe if every non-provable
case keeps today's behavior. This story is the safety envelope.

**Independent Test**: Each mismatch dimension (tree drift, baseline
rewrite, config rewrite, exempt-set change, corrupt record, missing
`--pass-batch`, `--full-reproof`) is exercised and shows the full
pipeline running.

**Acceptance Scenarios**:

1. **Given** a recorded post-state and a baseline-file rewrite (fresh
   capture bytes) between make and refactor, **When** the refactor spawn
   executes with `--pass-batch`, **Then** the full pipeline runs.
   **Type**: unit
2. **Given** a recorded post-state and a suite-configuration rewrite
   (`dart_test.yaml` or `pubspec.lock`), **When** the refactor spawn
   executes, **Then** the full pipeline runs.
   **Type**: unit
3. **Given** a recorded post-state whose exempt set differs from the
   spawn's effective exempt set, **When** the refactor spawn executes,
   **Then** the full pipeline runs.
   **Type**: unit
4. **Given** a corrupt or mistyped record file, **When** the refactor
   spawn executes, **Then** the full pipeline runs (safe failure —
   derived data is never trusted).
   **Type**: unit
5. **Given** a recorded post-state, a refactor spawned WITHOUT the
   driver-only pass-batch opt-in, **When** it executes, **Then** the
   full pipeline runs (the standalone contract is unchanged).
   **Type**: unit
6. **Given** a recorded post-state and `--full-reproof`, **When** the
   refactor spawn executes, **Then** the full pipeline runs (an explicit
   strongest-proof request is never inherited away).
   **Type**: unit

---

### User Story 3 - The record is honest, cheap, and best-effort (Priority: P3)

The driving run records make's certified post-state immediately after a
make green-applies (phase-1 make and phase-2a re-attempt call sites). The
record carries: when it was captured, which behavior's make certified it,
the suite template and context keys it was certified under, the byte
digests of `lib/` and `test/`, and a green verdict naming make's own
post-generation evidence. A write failure costs the NEXT refactor one
full pipeline — never correctness — and is surfaced as a warning only.
The record is derived data: rewritten by every green make, trusted by no
other consumer.

**Why this priority**: The record's shape and failure stance keep the
feature honest without expanding any green/safety contract.

**Independent Test**: A make green-application produces the record with
digests matching the on-disk tree; a simulated write failure or a stale
record never changes any outcome.

**Acceptance Scenarios**:

1. **Given** a make step green-applies during a driving run, **When** the
   driver proceeds to the next step, **Then** the record exists in the
   feature's `tdd/` directory with `lib`/`test` digests matching the
   on-disk trees and a green verdict naming the behavior's make.
   **Type**: unit
2. **Given** a stale record from an earlier run (tree since changed by a
   later make), **When** any later refactor spawn executes, **Then** the
   digest mismatch falls back to the full pipeline (the record describes
   one moment, never a standing exemption).
   **Type**: unit

---

### Edge Cases

- What happens when the make step outcome is the #741 already-green skip
  (the tree untouched by this make)? The earlier record still describes
  the certified tree; a matching spawn still inherits, honestly.
- What happens when the refactor spawn is deferred (phase 2) or the run
  stops between make and refactor? The record simply goes stale; the
  next spawn's digest comparison misses and the full pipeline runs.
- What happens on the first phase-2b batch spawn after the last make?
  If the tree is still byte-identical to that make's post-state, the
  same honest inheritance applies (the same proof, the same tree); any
  change since re-runs the pipeline.
- What happens when the record cannot be written (read-only tree, IO
  error)? A warning is surfaced; the next refactor pays one full
  pipeline; no outcome changes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST record the make's certified post-state (context
  keys + `lib`/`test` byte digests + green verdict + capture time +
  behavior id) when a make step green-applies during a driving run that
  opts its refactors into the pass-batch fast path.
- **FR-002**: System MUST let a `--pass-batch` refactor spawn inherit the
  full pipeline (zero suite spawns, zero pass-registry spawns, zero
  re-proof) when the recorded post-state matches the current tree and
  gate context exactly — same suite template, same baseline content, same
  suite configuration, same exempt set, byte-identical `lib/` and
  `test/`.
- **FR-003**: System MUST run the full pipeline on EVERY non-match:
  tree drift in either tree, baseline rewrite, suite-configuration
  rewrite, exempt-set difference, corrupt/mistyped/missing record,
  missing `--pass-batch`, or an explicit `--full-reproof`.
- **FR-004**: System MUST name the inheritance honestly — in stdout and
  in the cycle-log entry — including which behavior's make was inherited
  from, when it was certified, that the evidence is make's post-
  generation green evidence (the full suite did NOT run at this tree),
  and that the full gate still runs at feature completion and nightly.
- **FR-005**: System MUST keep the standalone (flag-less) refactor
  contract unchanged: it never reads or writes the record (spec 048
  FR-001 absolute green).
- **FR-006**: System MUST treat the record as derived, best-effort data:
  a write failure is a warning, never an error; a stale record is
  inert (digest mismatch → full pipeline).
- **FR-007**: System MUST NOT change the ledger's semantics: a
  refactor-proved full-pipeline gate (the #1588 record) still takes
  precedence, and the new record never overwrites it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a forward run, a behavior whose refactor spawn
  immediately follows its make-green executes zero suite spawns for that
  refactor (measured by suite-spawn counting in the fixture harness),
  with exit 0 and honest inheritance evidence.
- **SC-002**: Every mismatch dimension in FR-003 demonstrably re-runs the
  full pipeline (suite spawns occur) — no silent weakening.
- **SC-003**: The per-behavior refactor cost in the fixture harness
  drops from "preflight + registry + re-proof" to "two tree snapshots +
  a record read" on the inherited path, while the phase-2b batch pass
  and feature-completion preflight keep running unchanged.

## Assumptions

- Proposal 2 of the issue ("digest-gate the phase-1 refactor against the
  make's post-state") is the implemented direction; proposals 1 (defer
  into phase-2b) and 3 (scope the preflight) are recorded as rejected
  alternatives in the plan.
- The full-suite gate frequency stays as the #1588/#1624 line established:
  once per phase-2b batch pass, at feature completion (`zfa tdd verify`'s
  preflight), and nightly (the corpus lane). The accepted trade-off: a
  cross-behavior regression introduced by behavior k's make surfaces at
  the phase-2b batch pass (or the next full gate) instead of behavior k's
  refactor — the run still fails honestly, one gate later.
- The record lives beside the ledger in the feature's `tdd/` directory
  and mirrors the ledger's context keys so both sides reuse the same
  helpers (digest, baseline key, config key).
- Tests run in the existing two tiers: command-level (real refactor
  against fixture projects, suite-spawn counting via a logging wrapper —
  the #1588 harness shape) and driver-level (scripted fake zfa, asserting
  the driver writes the record on make-green — the run_command_test
  shape).
