**Template Version**: `zuraffa-1.0`

# Feature Specification: Spec-Mutation Arena — `zfa spec fuzz` (survived mutants are proven spec weaknesses)

**Feature Branch**: `1147-spec-fuzz-mutation-arena`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "[VISION-3] Spec-mutation arena: zfa spec fuzz — survived mutants are proven spec weaknesses (issue #1147, priority high — part of EPIC #1136, extends #967). Spec mutations applied to a feature; re-run behaviors; killed mutants are good (intent pinned), survived mutants are proven spec weaknesses."

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| --- | --- | --- | --- |
| SpecMutator (spec 0967, `spec_mutator.dart`) | lib contract | deterministic candidate generation + line-surgical application per contract element; `SM-###` ids in document order; seeded selection (`Random(seed)`, never `String.hashCode`) | P0 (shared, never duplicated) |
| SpecFuzzAuditor (spec 0967, `spec_fuzz_auditor.dart`) | lib contract | preflight-first referee; P1 plan-gate / P2 loop-red / P3 assertion pins; byte-exact restore (sha256) in `finally`; infra failure = not_assessed, never a kill, never a pass | P0 (shared, never duplicated) |
| GapLedgerStore (spec 051 FR-007) | file contract | survivors append `severity: contract` gap entries, deduplicated per mutation | P1 |
| verdict.v1 envelope (issue #969) | lib contract | `--json` emits the versioned envelope as the final stdout line | P1 |
| Traceability spec-hash (bug #846) | file contract | drift before fuzz = exit 3, mirroring `zfa tdd verify` | P1 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The referee fuzzes a green feature's spec (Priority: P0)

An agent certifies that a GREEN feature's test suite actually pins the spec's intent: `zfa spec fuzz <feature>` applies deterministic spec mutations, re-runs the loop's pins per mutant, and reports killed/survived with per-mutation evidence. A survived mutant is a proven spec weakness: the mutated spec still goes green, so nothing in the harness pins the original intent. Exit code is non-zero when survived > 0.

**Why this priority**: this is the whole feature — the VISION-3 referee round. Everything else exists to make this verdict deterministic and honest.

**Independent Test**: a fixture feature whose weak spec yields mutants that all survive exits 1 with a weakness report naming each mutation; the same feature under a strengthened spec kills every mutant and exits 0.

**Acceptance Scenarios**:

1. **Given** a green feature with registered behavior artifacts, **When** `zfa spec fuzz <feature> --project <dir>` runs, **Then** it applies the declared operators, writes the machine-readable weakness report rows `{mutation_id, spec_line, operator, verdict, evidence}` to `specs/<feature>/tdd/spec-fuzz.json` (+ markdown twin), prints the machine summary line `spec-fuzz: feature=... mutations=... killed=... survived=... not_assessed=... budget=... seed=... fuzz_was_run=... certified=...`, and exits 0 only when every mutant was killed.
   **Type**: acceptance
2. **Given** a mutated spec that still passes every pin, **When** the round completes, **Then** that mutant is reported `verdict: survived`, the command exits 1, and the row's evidence names the pins that were checked and did not fire.
   **Type**: acceptance
3. **Given** a mutation that breaks the contract structure, **When** the pin check runs, **Then** the mutant is reported `verdict: killed` with the rejecting pin and spec line as evidence.
   **Type**: acceptance
4. **Given** a feature whose suite is red or whose artifacts registry is missing, **When** `zfa spec fuzz <feature>` runs, **Then** it refuses to grade (preflight_red / not_assessed) and never reports a pass it did not prove.
   **Type**: acceptance

### User Story 2 - Five deterministic, replayable operators (Priority: P0)

The arena's mutations are the five declared operators applied per CONTRACT ELEMENT, never free-text edits: weaken (strip a Then clause's assertion-bearing specifics: "shows the error" -> "shows a message"), drop (remove an edge-case scenario), swap-literal (change a declared literal / route / key / number), widen (change a declared numeric range), drop-must-not (remove a MUST NOT clause). Same feature + same seed + same operator set -> byte-identical mutation set, order, verdicts, and report files (#806 replay semantics; seeds follow the house FNV-1a-derived convention, never `String.hashCode`, never wall-clock in report bodies).

**Why this priority**: VISION-3 demands "deterministic, replayable" operators; a referee whose rounds cannot be replayed cannot gate CI.

**Independent Test**: a fixture spec carrying all five element types yields one candidate per element with `SM-###` ids in document order; fuzzed twice with the same seed and budget produces byte-identical `spec-fuzz.json`; `--operators weaken,drop` produces only weaken/drop rows.

**Acceptance Scenarios**:

1. **Given** the five operators, **When** candidates are generated against a spec carrying all five element types, **Then** each operator targets its declared element class deterministically (weaken -> Then specifics, drop -> edge-case scenarios, swap-literal -> literals/routes/keys/numbers, widen -> ranges/bounds, drop-must-not -> MUST NOT clauses) and re-running generation yields identical candidates.
   **Type**: acceptance
2. **Given** the same feature, seed, operator set, and budget, **When** the fuzz runs twice, **Then** both rounds write byte-identical weakness reports (no timestamps or nondeterministic paths in the report bodies).
   **Type**: acceptance
3. **Given** `--operators weaken,drop` (or any subset), **When** the round runs, **Then** the report's rows carry only the selected operators' mutations, and an unknown operator label is refused as a usage error.
   **Type**: acceptance

### User Story 3 - The budget gates the round (Priority: P0)

`--budget N` caps the number of mutants run this round: a budget smaller than the candidate count runs exactly N mutants selected by the seed (0 = document-order prefix; a nonzero seed is a stable seeded shuffle), and the report records seed, budget, candidate count, and the mutations actually run.

**Why this priority**: the ZikZak rebuild walks ~120 specs; the budget is what makes the kill rate affordable corpus-wide (#953).

**Independent Test**: a fixture with more than two candidates fuzzed with `--budget 2` runs exactly 2 mutants and records `budget=2`; running it twice yields identical selection.

**Acceptance Scenarios**:

1. **Given** a candidate count greater than the budget, **When** the round runs, **Then** exactly `budget` mutants are judged, the machine line records `budget=N`, and the selection is deterministic for the given seed.
   **Type**: acceptance
2. **Given** a non-integer or sub-one budget, **When** `zfa spec fuzz` parses it, **Then** it is refused as a usage error with the fix line.
   **Type**: acceptance

### User Story 4 - Survived mutations are ledger gaps; certified is gated (Priority: P1)

Survived mutations are spec-contract weaknesses the corpus economics gate treats as first-class gaps: each survivor appends a `severity: contract` gap entry to `.zfa/corpus/gap-ledger.json` (deduplicated against an unresolved gap for the same mutation), the machine line carries `certified=false` unless the fuzz ran, generated at least one mutation, and killed every one.

**Why this priority**: a verdict that nothing consumes is presence-count theater — the issue's core complaint.

**Independent Test**: a fuzz round with one survivor appends exactly one deduplicated gap entry with `severity: contract`; a vacuous round (zero candidates, or the fuzz refused) is never certified.

**Acceptance Scenarios**:

1. **Given** a round with at least one survived mutation, **When** the round completes, **Then** each survivor appends one gap entry (`severity: contract`, `outcome: survived`) unless an unresolved gap for that mutation already exists, and the JSON report lists the ledger ids.
   **Type**: acceptance
2. **Given** the machine summary line, **When** CI or an agent parses it, **Then** `certified=true` appears only when the fuzz ran, at least one mutation was generated, and every generated mutation was killed.
   **Type**: acceptance

## Non-Functional Requirements

Determinism: no wall-clock, no `String.hashCode`, no iteration over unordered maps in report bodies; candidate order is document order; evidence is reduced to deterministic fields. Restoration: spec.md and any in-place regenerated test file are restored byte-exactly (sha256 verified) after every mutant, including on early exits and thrown errors. Honesty: infra failures grade not_assessed per mutant — never a kill, never a pass; the fuzz never edits a committed test to fake a verdict. The command layer stays injectable: the spawn/preflight seams that make the fast tier honest (no real subprocess in unit tests) must exist without changing default (real-process) semantics. Exit protocol: 0 pass / 1 survived > 0 / 2 corpus catalog misfire / 3 spec drift / 2 (legacy 64) usage + honest not_assessed/preflight_red refusals.

## Key Entities

| Entity | Fields | Purpose |
| --- | --- | --- |
| SpecMutationOperator | weaken, drop, swapLiteral, widen, dropMustNot | the declared operator set, parsed from `--operators` (labels: weaken, drop, swap-literal, widen, drop-must-not) |
| SpecMutationCandidate | mutationId, operator, specLine, element, behaviorId, originalValues, targetToken, description | one addressable mutation of one contract element, deterministic in document order (SM-###) |
| SpecFuzzVerdict | killed, survived, notAssessed | per-mutant verdict; evidence names the pin that fired |
| SpecFuzzGateDecision | pass, failSurvived, preflightRed, notAssessed | the round gate; precedence notAssessed > preflightRed > failSurvived > pass |
| WeaknessReport | feature, seed, budget, operators, mutations[], gate, certified, restoration | the machine-readable report rows `{mutation_id, spec_line, operator, verdict, evidence}` written to tdd/spec-fuzz.json (+ markdown twin) |

## Layer Contracts

- CLI layer: `zfa spec fuzz <feature> [--operators ...] [--budget N] [--seed N] [--json] [--project DIR] [--timeout minutes] [--runner dart|flutter] [--no-ledger] [--corpus <target>]` -> exit 0 pass / 1 survived>0 / 2 catalog misfire / 3 spec drift / 2 (legacy 64) usage; machine line `spec-fuzz: ...` is the CI contract.
- Service layer: `SpecMutator` (pure candidate generation + line-surgical application), `SpecFuzzAuditor` (preflight -> per-mutant pins P1/P2/P3 -> verdicts -> restoration -> ledger -> report), injectable spawns for the fast tier.
- Pin semantics (the oracle, exactly):
  - P1 plan-gate pin: the mutated spec fails the ingest gate chain (template-version treaty, SpecParser derivation, coverage gate, declaration refusals, undeclared-dependency lint).
  - P2 loop-red pin: the test regenerated from the mutated spec (real BehaviorTestWriter, written in place and restored) fails when run against the committed implementation.
  - P3 assertion pin: the mutated element's original values appear in an `expect(` assertion line of the feature's committed tests; for the drop operator the dropped behavior's own test is excluded.
  - survived = every pin silent = the mutated spec still goes green = the test suite does not pin the intent.

## Lanes

```yaml
lane: CORE
behaviors: [A1-A5]
flutter_allowed: false
```

## Edge Cases

- Feature with no mutable contract elements: not_assessed (reason `no mutation candidates generated`), `certified=false` — nothing was proven, never a vacuous pass.
- Last-scenario drop leaving zero acceptance scenarios: killed by P1 (SpecParser refuses a spec with no scenarios).
- Missing `tdd/traceability.md`: no drift gate (legacy features keep working, mirroring verify).
- Registry behavior ids that shift after a drop (AC renumbering): drop is judged on pins only — surviving behaviors' assertions are unchanged, so no regeneration spawn is required.
- `--runner flutter`: the runner template resolution mirrors issue #1044 (flag wins, profile `file:` next, pure-Dart default last).
