# Contracts: `zfa tdd compose` — phase-2 acceptance make composition

Feature: 052-acceptance-make-composition | Date: 2026-09-01 | Spec: [spec.md](../spec.md)

## C1 — `zfa tdd compose` command contract

### Invocation

```text
zfa tdd compose [<behavior-id>] [--feature <name>] [--project <path>]
```

- `<behavior-id>`: the acceptance behavior to compose. When omitted, the
  single-candidate inference of verify-red/make/wire applies (exactly one
  registry record); zero or multiple candidates stop with a named error.
- `--feature <name>`: restricts target resolution to
  `specs/<feature>/tdd/artifacts.json`.
- `--project <path>`: project root containing `specs/`, `test/`, `lib/`
  (default: current working directory). Tests pass the fixture root here.

### Preconditions (in order; first failure stops, non-zero, no writes)

1. **Resolution** — the behavior id resolves in a feature registry
   (`artifacts.json`); ambiguity names the features and demands
   `--feature`; an unknown id names the `zfa tdd gen` remediation
   (FR-001, wire's rules).
2. **Certified red** — a `kind: red` cycle-log section for the behavior
   exists in `tdd/cycle-log.md` (FR-002).
3. **Subject artifact** — the registry's `subject_path` exists on disk,
   inside the project root (misfire-stop naming `zfa tdd gen` otherwise).
4. **Anchor discovery** — ≥ 1 composable green unit subject (unit-kind
   test-list row ∩ green cycle-log evidence ∩ existing `subject_path`;
   FR-003). Zero anchors → `no-green-units`, non-zero, naming the
   precondition. A green unit whose subject file is missing →
   `runner-error` naming the missing artifact (US2.AC4).

### Effects

- On success, replaces the subject's `UnimplementedError` stub body with
  the GENERATED-stamped composed implementation importing and referencing
  every discovered anchor (FR-004, data-model.md shape). Writes nothing
  else; touches no test file.
- Idempotence: a subject with no `UnimplementedError` → `already-composed`,
  exit 0, no rewrite (FR-005). An `UnimplementedError` in an unrecognized
  shape → refusal, exit 1, no rewrite.

### Machine contract

Final stdout line on EVERY code path:

```text
compose: behavior=<id> outcome=<composed|already-composed|not-certified-red|no-green-units|runner-error> feature=<feature>
```

Exit 0 ⇔ `composed` or `already-composed`.

## C2 — Make composition-fallback contract

### Trigger (inside `zfa tdd make`, after resolution + red + drift + baseline checks)

When `GenerationPlanner.plan(summary)` returns an unexpressible plan:

1. Read the feature's test list via `TestListReader` and find the row for
   the behavior id. No row, or a malformed list → NO fallback: report
   `unexpressible` exactly as today (fail-closed, FR-007/FR-009).
2. Row kind is `unit` (or not acceptance) → NO fallback: `unexpressible`
   (unit honest-stop preserved, SC-004).
3. Row kind is `acceptance` → consult `CompositionTargets.discover(...)`
   (same discovery as compose's precondition 4). Zero anchors →
   `unexpressible` with the planner's behavior-terms reason (FR-009, the
   honest stop for prose that remains uncomposable, SC-003).
4. ≥ 1 anchor → build the fallback plan via `CompositionPlanner`
   (`compose <id>` → `build`) and execute it through `PipelineRunner`
   (FR-007/FR-010). Every executed step is captured and lands in the green
   evidence on success; a failed step misfire-stops the make with
   `generation-error` and no green entry (US4.AC2 of 047).

### Observable outcomes at the driver level

| Phase | Scenario                                        | make outcome before | make outcome after |
| ----- | ----------------------------------------------- | ------------------- | ------------------ |
| 1     | acceptance prose, no green units yet            | `unexpressible` (defer) | `unexpressible` (defer) — unchanged |
| 2     | acceptance prose, green units exist             | `unexpressible` (honest stop) | `green` via composition |
| 2     | acceptance prose, zero/missing anchors          | `unexpressible` (honest stop) | `unexpressible` (honest stop) — unchanged |
| 1/2   | unit behavior unexpressible                     | `unexpressible` (honest stop) | unchanged — fallback never engages |
| 1     | entity-bearing acceptance behavior              | `green` (planner plan) | unchanged — planner plan wins |

The driver contract is untouched: phase 2a spawns `tdd make <id>`, consumes
`outcome=green`/`unexpressible`; summary lines, exit codes, deferral rules,
and state semantics are exactly spec 049's (FR-011/FR-012).

## C3 — Purity contract (planner + fallback planner)

- `GenerationPlanner.plan()`: signature, mapping rules, and outputs
  byte-identical to master for every input (FR-008, SC-006). No new
  parameters; no new fields on `BehaviorSummary`.
- `CompositionPlanner`: pure — `(BehaviorSummary, List<ComposableUnitSubject>)
  → GenerationPlan` (or an uncomposable result when the anchor list is
  empty; the make layer decides before calling). Never touches the
  filesystem or spawns processes.
- `CompositionTargets.discover(...)`: the ONLY new filesystem-reading
  surface (test list + cycle log + registry + subject existence), returning
  `List<ComposableUnitSubject>` or a typed discovery failure.

## C4 — Test-file immutability contract (044)

Neither compose nor the make fallback writes, deletes, or rewrites any file
under `test/`. The only file compose writes is the target behavior's
subject file. Verified byte-for-byte in tests (US2.AC5, SC-018-style
fixtures snapshot the paired test content before/after).
