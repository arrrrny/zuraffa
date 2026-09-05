**Template Version**: `zuraffa-1.0`

# Feature Specification: Spec-Mutation Arena — `zfa spec fuzz` (mutation testing for intent)

**Feature Branch**: `0967-spec-mutation-arena`

**Created**: 2026-09-05

**Status**: Draft

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/967 — [VISION] spec-mutation arena: zfa spec fuzz — mutation testing for intent; survived mutants are proven spec weaknesses (VISION §7). Given a feature that is green (spec + passing behaviors + clean ledger), zfa spec fuzz applies spec mutations and re-runs the loop. Any mutated spec that still goes green is a proven spec weakness: the test suite does not pin the intent. The corpus's kill rate becomes the coverage metric that presence counts cannot fake."

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| --- | --- | --- | --- |
| SpecParser + RequirementScanner (this repo) | lib contract | spec.md grammar: acceptance scenarios `N. **Given** ... **Then** ...`, FR bullets `- **FR-NNN**: ...`, statement lineNo addresses; line-surgical rewrite is the SpecMigrator pattern | P0 (shared, never duplicated) |
| BehaviorTestWriter + SubjectWriter (spec 044) | lib contract | the gen pair the fuzz re-derives per mutant: numbers via `returns N` -> `equals(N)`, known exceptions -> `throwsA`, else generic `isNot(isA<UnimplementedError>())`; acceptance lane is invocation-only | P0 |
| MutationScope / ArtifactRegistry (spec 044 FR-012) | file contract | `specs/<feature>/tdd/artifacts.json` registers behavior_id -> {test_path, subject_path}; project-relative paths | P0 |
| MutationAuditor's honesty contract (spec 044 FR-013..023) | lib contract | green-suite preflight first; infra failure = not_assessed never pass; restore bytes + verify sha256; never edit tests to fake a verdict; non-zero exit on any non-PASS gate | P0 |
| GapLedgerStore (spec 051 FR-007, #1007 severity) | file contract | append-only `.zfa/corpus/gap-ledger.json`; gap entries carry `expected_result` in {complete, pass, behavior} and `severity: contract` for the highest class | P0 |
| Corpus catalog + budget (#953 corpus economics, #1016) | file contract | `corpus/catalogs/<target>.json` via requireCatalog; never stop at a failing feature — the budget is the gate | P1 |
| Traceability spec-hash (bug #846) | file contract | `tdd/traceability.md` machine block `spec-hash: sha256:...`; drift before fuzz = exit 3 (same refusal as `zfa tdd verify`) | P1 |
| verdict.v1 envelope (issue #969) | lib contract | `--json` emits the versioned envelope as the final stdout line | P1 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The referee fuzzes a green feature's spec (Priority: P0)

An agent certifies that a GREEN feature's test suite actually pins the spec's intent: `zfa spec fuzz <feature>` applies deterministic spec mutations (weaken a Then clause, drop an edge-case scenario, swap a declared literal/route/key, widen a numeric range, drop a MUST NOT), re-runs the loop's pins per mutant, and reports killed/survived with per-mutation evidence. A survived mutant is a proven spec weakness: the mutated spec still goes green, so nothing in the harness pins the original intent. Exit code is non-zero when survived > 0.

**Why this priority**: this is the whole feature — the arena's referee round (VISION §7). Everything else exists to make this verdict deterministic and honest.

**Independent Test**: a fixture feature whose weak spec yields mutants that all survive (nothing pins them) exits 1 with a weakness report naming each mutation; the same feature under a strengthened spec kills every mutant and exits 0.

**Acceptance Scenarios**:

1. **Given** a green feature with registered behavior artifacts, **When** `zfa spec fuzz <feature> --project <dir>` runs, **Then** it applies the declared operators, writes `specs/<feature>/tdd/spec-fuzz.md` plus the machine-readable `specs/<feature>/tdd/spec-fuzz.json` weakness report rows `{mutation_id, spec_line, operator, verdict, evidence}`, prints the machine summary line `spec-fuzz: feature=... mutations=... killed=... survived=... not_assessed=... budget=... seed=... fuzz_was_run=... certified=...`, and exits 0 only when every mutant was killed.
   **Type**: acceptance
2. **Given** a mutated spec that still passes every pin (plan gates pass, the regenerated test stays green against the committed implementation, no committed assertion pins the original value), **When** the round completes, **Then** that mutant is reported `verdict: survived`, the command exits 1, and the row's evidence names the pins that were checked and did not fire.
   **Type**: acceptance
3. **Given** a mutation that breaks the contract structure (plan-gate chain rejects the mutated spec), **When** the pin check runs, **Then** the mutant is reported `verdict: killed` with the rejecting gate and spec line as evidence.
   **Type**: acceptance
4. **Given** a mutation whose regenerated test fails when run against the committed implementation (the loop goes RED), **When** the pin check runs, **Then** the mutant is reported `verdict: killed` with the failing spawn's exit code and assertion line as evidence.
   **Type**: acceptance
5. **Given** a feature whose suite is red or whose artifacts registry is empty or whose spec drifted from the plan's traceability hash, **When** `zfa spec fuzz <feature>` runs, **Then** it refuses to grade (preflight_red / not_assessed / exit 3 drift, mirroring `zfa tdd verify`'s pre-gates) and never reports a pass it did not prove.
   **Type**: acceptance

### User Story 2 - Deterministic, replayable rounds (Priority: P0)

The arena's verdicts must be reproducible: same feature + same seed + same operator set -> byte-identical mutation set, order, verdicts, and report files (replay-compatible with #806 semantics: re-running the recorded round reproduces it). Seeds follow the house FNV-1a-derived convention (never `String.hashCode`, never wall-clock in report bodies).

**Why this priority**: VISION §7 demands "deterministic verdicts"; a referee whose rounds cannot be replayed cannot gate CI.

**Independent Test**: the same fixture fuzzed twice with the same seed produces byte-identical `spec-fuzz.json`; a different seed with a budget below the candidate count selects a different (still deterministic) subset.

**Acceptance Scenarios**:

1. **Given** the same feature, seed, operator set, and budget, **When** the fuzz runs twice, **Then** both rounds write byte-identical weakness reports (no timestamps or nondeterministic paths in the report bodies).
   **Type**: acceptance
2. **Given** a budget smaller than the candidate count, **When** selection runs, **Then** the seed deterministically chooses which mutants run (seed 0 takes document-order prefix; a nonzero seed is a stable seeded shuffle), and the report records seed, budget, candidate count, and selected mutation ids.
   **Type**: acceptance
3. **Given** mutation candidates, **When** ids are assigned, **Then** `SM-###` ids are stable in document order of the parsed contract elements regardless of operator filter, so replay and ledger rows stay addressable.
   **Type**: acceptance

### User Story 3 - Survived mutations are ledger gaps; certified is gated (Priority: P0)

Survived mutations are spec-contract weaknesses the corpus economics gate must treat as first-class gaps: each survivor appends a `severity: contract` gap entry to `.zfa/corpus/gap-ledger.json` (deduplicated against an unresolved gap for the same mutation), the machine line carries `certified=false`, and a CI job runs the fuzz gate so a survived mutant blocks certified status exactly like an open contract gap blocks a `complete` corpus verdict.

**Why this priority**: a verdict that nothing consumes is presence-count theater — the issue's core complaint.

**Independent Test**: a fuzz round with one survivor appends exactly one deduplicated gap entry with `severity: contract`, `expected_result: pass`, `behavior: <mutation_id>`; re-running the round does not duplicate it; the CI job's fail-on-should-be-red assertions fail when the gate is flipped.

**Acceptance Scenarios**:

1. **Given** a round with at least one survived mutation, **When** the round completes, **Then** each survivor appends one gap entry (`severity: contract`, `outcome: survived`, `behavior: <mutation_id>`, `expected_result: pass`) unless an unresolved gap for that mutation already exists, and the JSON report lists the ledger ids.
   **Type**: acceptance
2. **Given** the machine summary line, **When** CI or an agent parses it, **Then** `certified=true` appears only when the fuzz ran, at least one mutation was generated, and every generated mutation was killed — a vacuous or unrunnable round is never certified.
   **Type**: acceptance
3. **Given** the repository's CI, **When** the spec-fuzz job runs, **Then** it executes the seeded weakness demo end to end (real processes): the weak spec round must be flagged (the job fails if it is not) and the strengthened spec round must kill all mutants (the job fails if any survive).
   **Type**: acceptance

### User Story 4 - Corpus-wide fuzzing against the baseline infrastructure (Priority: P1)

`zfa spec fuzz --corpus <target>` iterates the cataloged features (requireCatalog — the #953/#1016 corpus economics surface) with one global mutant budget, never stops at a failing feature, writes each feature's report, persists the round state under `.zfa/corpus/`, and tallies certified/failed/not_assessed features in a corpus machine line.

**Why this priority**: the ZikZak rebuild walks ~120 specs; the kill rate must be measurable corpus-wide, not one feature at a time.

**Independent Test**: a fixture corpus catalog with two features (one weak, one strong) runs both under a budget, reports per-feature verdicts in the tally line, and exits 1 because the weak feature survived.

**Acceptance Scenarios**:

1. **Given** a catalog target with features, **When** `zfa spec fuzz --corpus <target> --budget N` runs, **Then** every feature is visited (never-stop discipline), the global mutant budget is respected, per-feature reports are written, and the tally line `spec-fuzz: corpus=<target> features=... certified=... failed=... not_assessed=... budget=... used=... result=ok|over-budget` is printed.
   **Type**: acceptance
2. **Given** any feature in the corpus fails its fuzz gate (survived > 0), **When** the corpus round completes, **Then** the command exits non-zero and the failing feature's survived rows appear in the persisted round state.
   **Type**: acceptance
3. **Given** no catalog exists for the target, **When** `zfa spec fuzz --corpus <target>` runs, **Then** it refuses with the requireCatalog recovery line (exit 2, `--> fix: zfa corpus catalog --target ...`).
   **Type**: acceptance

## Non-Functional Requirements

Determinism: no wall-clock, no `String.hashCode`, no iteration over unordered maps in report bodies; candidate order is document order; spawn output is reduced to deterministic evidence fields (exit code, matched assertion line, truncated). Restoration: spec.md and any in-place regenerated test file are restored byte-exactly (sha256 verified) after every mutant, including on SIGINT-style early exits and thrown errors (finally). Honesty: infra failures (timeout, load failure, missing writer inputs) grade not_assessed per mutant — never a kill, never a pass; the fuzz never edits a committed test to fake a verdict (the only test write is the loop-faithful regeneration via the real BehaviorTestWriter, restored afterwards). Cost: per-mutant work is bounded by the single-test spawn timeout (default 2 minutes, overridable); the preflight is one suite spawn.

## Key Entities

| Entity | Fields | Purpose |
| --- | --- | --- |
| SpecMutationOperator | weaken, drop, swapLiteral, widen, dropMustNot | the declared operator set, parsed from `--operators` (labels: weaken, drop, swap-literal, widen, drop-must-not) |
| SpecMutationCandidate | mutationId, operator, specLine, element, behaviorId, originalValues, mutatedPreview | one addressable mutation of one contract element, deterministic in document order (SM-###) |
| SpecFuzzVerdict | killed, survived, notAssessed | per-mutant verdict; evidence names the pin that fired |
| SpecFuzzGateDecision | pass, failSurvived, preflightRed, notAssessed | the round gate; precedence mirrors MutationGateDecision |
| WeaknessReport | feature, seed, budget, operators, mutations[], gate, certified, restoration | the machine-readable report rows `{mutation_id, spec_line, operator, verdict, evidence}` written to tdd/spec-fuzz.json (+ markdown twin) |

## Layer Contracts

- CLI layer: `zfa spec fuzz <feature> [--operators ...] [--budget N] [--seed N] [--json] [--project DIR] [--timeout minutes] [--runner dart|flutter] [--no-ledger] [--corpus <target>]` -> exit 0 pass / 1 survived>0 / 2 catalog misfire / 3 spec drift / 64 usage; machine line `spec-fuzz: ...` is the CI contract.
- Service layer: `SpecMutator` (pure candidate generation + line-surgical application), `SpecFuzzAuditor` (preflight -> per-mutant pins P1/P2/P3 -> verdicts -> restoration -> ledger -> report), injectable spawns for the fast tier.
- Pin semantics (the oracle, exactly):
  - P1 plan-gate pin: the mutated spec fails the ingest gate chain (template-version treaty, SpecParser derivation, coverage gate, declaration refusals, undeclared-dependency lint).
  - P2 loop-red pin: the test regenerated from the mutated spec (real BehaviorTestWriter, written in place and restored) fails when run against the committed implementation.
  - P3 assertion pin: the mutated element's original values appear in an `expect(` assertion line of the feature's committed tests; for the drop operator the dropped behavior's own test is excluded (a pin nothing requires is not a pin — the re-plan orphans it).
  - survived = every pin silent = the mutated spec still goes green = the test suite does not pin the intent.

## Lanes

```yaml
lane: CORE
behaviors: [A1-A12]
flutter_allowed: false
```

## Edge Cases

- Feature with no mutable contract elements: not_assessed (reason `no mutation candidates generated`), `certified=false` — nothing was proven, never a vacuous pass.
- Last-scenario drop leaving zero acceptance scenarios: killed by P1 (SpecParser refuses a spec with no scenarios).
- Missing `tdd/traceability.md`: no drift gate (legacy features keep working, mirroring verify).
- Registry behavior ids that shift after a drop (AC renumbering): drop is judged on pins only — surviving behaviors' assertions are unchanged, so no regeneration spawn is required (documented vacuous-green).
- `--runner flutter`: the runner template resolution mirrors issue #1044 (flag wins, profile `file:` next, pure-Dart default last).
