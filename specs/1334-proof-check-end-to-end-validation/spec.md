# Feature Specification: zfa proof chain — end-to-end receipt validation with JSON verdict

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `1334-proof-check-end-to-end-validation`

**Created**: 2026-09-09

**Status**: Approved

**Input**: User description: "https://github.com/arrrrny/zuraffa/issues/1148 — [VISION-4] The proof chain: zfa proof check validates every receipt end-to-end (EPIC 5: Simulation, Replay & the Proof Machine). Every artifact ships proof. Every green is reproducible. The proof chain links: spec → plan → behaviors → gen → verify-red → make → receipt → realize → world. Exit 0 when the chain is intact, non-zero with --json verdict listing every drift."

## Naming note (locked decision)

Issue #1148 asks for `zfa proof check` end-to-end, but `zfa proof check`
already exists (issue #807): it re-derives receipt digests and exits 0/1.
The task's hard constraints forbid modifying it ("This is a NEW command,
not a modification of existing proof/verify commands. Build it as a new
proof subcommand" / "Do NOT change the existing ... proof check"). The
end-to-end validation therefore ships as the NEW subcommand
**`zfa proof chain`** — the issue's own vocabulary ("The proof chain
links: spec → plan → ..."), under the existing `zfa proof` group, next to
the untouched `check`. The `zfa proof` group's help lists both subcommands
and cross-references them.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - CI runs one command and gets a machine verdict (Priority: P1)

A CI pipeline (or an agent) wants the dream from the issue:
`zfa proof chain && flutter test` — no human reviews a black box. The
command walks `.zfa/receipts/` and the project tree, validates the six
links of the chain, and exits by protocol: 0 intact, 1 drift, 2
infrastructure error. `--json` emits one parseable verdict object
(schema `proof-chain.v1`) listing every drift/gap item with category,
file, expected, actual, and fix.

**Why this priority**: the exit-code protocol and the JSON verdict are the
contract everything else hangs off; without them CI cannot gate and
agents cannot parse.

**Independent Test**: run `zfa proof chain` in a clean project (exit 0),
seed a drifted receipt (exit 1), point at an unreadable receipts dir
(exit 2).

**Acceptance Scenarios**:

1. **Given** a project with zero receipts and zero specs, **When**
   `zfa proof chain` runs, **Then** it exits 0 with a vacuous-green
   verdict (the chain has nothing to disprove).
   **Type**: acceptance
2. **Given** a receipt in `.zfa/receipts/` whose artifact was hand-edited
   after generation, **When** `zfa proof chain` runs, **Then** it exits 1
   and the verdict lists a `receipt_digest` drift naming the file, the
   expected digest, the actual digest, and a fix.
   **Type**: acceptance
3. **Given** any check outcome, **When** `--json` is passed, **Then**
   stdout is exactly one JSON object (parseable by `jsonDecode`) whose
   `items` each carry `category`, `severity`, `file`, `expected`,
   `actual`, and `fix`.
   **Type**: acceptance
4. **Given** `.zfa/receipts/` exists but a receipt document is corrupt
   beyond parsing AND the receipts directory itself is unreadable
   (missing/unlistable), **When** `zfa proof chain` runs, **Then** it
   exits 2 (infrastructure error) with a `--> fix:` line.
   **Type**: acceptance

### User Story 2 - Behavior coverage is proven from the cycle log (Priority: P1)

The chain's second link: every spec's declared behaviors have green
evidence. The command reads `specs/<feature>/tdd/test-list.md` (behavior
ids) and `specs/<feature>/tdd/cycle-log.md` (green evidence), the same
stores the tdd machinery writes, and reports behaviors without green
evidence as gaps — never silently green.

**Why this priority**: behavior coverage is the spec→behaviors link; a
chain that skips it proves only digests (that is `proof check`'s job).

**Independent Test**: seed a feature with a test-list id that has no
green cycle-log entry; the verdict reports a `behavior_coverage` gap; add
the green entry; the gap disappears.

**Acceptance Scenarios**:

1. **Given** a feature whose test-list declares behavior `B1` and whose
   cycle-log holds a `kind: green` section for `B1`, **When** the
   behavior-coverage check runs, **Then** `B1` counts as covered and no
   gap is reported.
   **Type**: acceptance
2. **Given** a feature whose test-list declares `B2` with no green
   cycle-log entry, **When** the check runs, **Then** the verdict lists a
   `behavior_coverage` gap for `B2` (severity gap — reported, not
   exit-failing) with fix `zfa tdd run <feature>`.
   **Type**: acceptance
3. **Given** a feature whose green evidence names a test file that no
   longer exists on disk, **When** the check runs, **Then** the verdict
   lists a `test_integrity` drift (evidence without artifact — severity
   drift, exit 1), because existing evidence must stay honest.
   **Type**: acceptance

### User Story 3 - Generated tests compile (and can run) (Priority: P2)

The gen→test link: every tdd gen'd test (registered in
`specs/<feature>/tdd/artifacts.json`) still exists on disk and its
imports resolve (compile-level integrity, no subprocess). With
`--run-tests`, each registered test is actually executed (`dart test`)
and runtime failures are drift.

**Why this priority**: integrity of the generated suite is what makes
"every green is reproducible" true; import-resolution is the fast static
half, `--run-tests` the slow honest half.

**Independent Test**: seed an artifacts.json pointing at a test file that
imports a missing file; the verdict lists a `test_integrity` drift. Point
it at a healthy file; the item disappears.

**Acceptance Scenarios**:

1. **Given** a feature whose artifacts.json records a test file that is
   missing from disk, **When** the check runs, **Then** the verdict lists
   a `test_integrity` drift (severity drift) for the missing file.
   **Type**: acceptance
2. **Given** a registered test whose relative or self-package imports
   dangle (target file absent), **When** the check runs, **Then** the
   verdict lists a `test_integrity` drift naming the unresolved import.
   **Type**: acceptance
3. **Given** `--run-tests` is passed and a registered test exits non-zero
   when executed, **Then** the verdict lists a `test_runtime` drift with
   the exit code and the command's output tail; without `--run-tests`
   runtime is reported as not-exercised (info), never claimed.
   **Type**: acceptance

### User Story 4 - Route and usecase verifies are accounted for (Priority: P2)

The receipt→verify links: every declared route table
(`routes-<Entity>.json`) has a verify verdict (`routes-<Entity>-verify.json`,
`verdict.ok`), and every usecase-create receipt's entity can be
gate-checked. Failed verifies are drift; never-run verifies are gaps with
the exact fix command; skipped-with-reason verifies are honored.

**Why this priority**: routes and usecases are the two verify verbs that
already persist (routes) or expose (usecases) machine verdicts; the chain
must read them, not re-implement them.

**Independent Test**: seed `routes-Product.json` + a verify receipt with
`verdict.ok=false` → drift; delete the verify receipt → gap; seed a
usecase-create receipt whose entity passes the gate → no item.

**Acceptance Scenarios**:

1. **Given** a declared routes receipt with a verify receipt recording
   `verdict.ok == false`, **When** the check runs, **Then** the verdict
   lists a `route_verify` drift (severity drift, exit 1).
   **Type**: acceptance
2. **Given** a declared routes receipt with NO verify receipt, **When**
   the check runs, **Then** the verdict lists a `route_verify` gap with
   fix `zfa route verify <Entity>` (severity gap).
   **Type**: acceptance
3. **Given** a verify receipt whose input records a skip with a reason
   (`verdict: skip`, `reason: ...`), **When** the check runs, **Then**
   the route is reported as skipped-with-reason (info), never drift.
   **Type**: acceptance
4. **Given** a usecase-create receipt for entity `Product` and a healthy
   generated usecase tree, **When** the usecase check runs, **Then** no
   item is reported; with drifted/conforming-failing usecases the verdict
   lists a `usecase_verify` drift; when no usecase artifacts exist at
   all, the check is vacuously green.
   **Type**: acceptance

### User Story 5 - Xray coverage kinds are traced or named as gaps (Priority: P3)

The coverage link: every kind declared in a feature's UI ledger
(`specs/<f>/tdd/ui-ledger.md`) is traced by a green behavior or named as
an untraced-kind gap. Stored state is a cache — traced-ness is recomputed
from the current green evidence.

**Why this priority**: the ledger is the newest, least-populated store
(3 features in this repo, mostly empty); the check must be honest about
what exists without inventing coverage.

**Independent Test**: seed a ledger row `sample | text | B1 | DONE` where
`B1` has no green evidence → gap naming kind `text`; add green evidence
for `B1` → the kind traces.

**Acceptance Scenarios**:

1. **Given** a ledger row whose provers all have green evidence, **When**
   the xray check runs, **Then** the row's kind counts as traced.
   **Type**: acceptance
2. **Given** a ledger row whose provers have no green evidence (or no
   provers at all), **When** the check runs, **Then** the verdict lists
   an `xray_coverage` gap naming the kind and the surface (severity gap).
   **Type**: acceptance
3. **Given** a feature with no ledger file, **Then** the xray check
   contributes no items (a kind never declared is never a gap).
   **Type**: acceptance

### Edge Cases

- What happens when `.zfa/receipts/` does not exist? — vacuous green
  (0 receipts, 0 findings; the issue says receipts appear after verbs
  run), same convention as `proof check`.
- What happens when a receipt JSON is corrupt? — the item is reported as
  an `infra` error if the receipts DIRECTORY is unreadable (exit 2);
  individual corrupt receipts are skipped with a gap item (one broken
  document must not erase the provenance of healthy ones — the
  ReceiptStore convention).
- What happens when `specs/` does not exist? — all spec-derived checks
  are vacuously green.
- What happens when a route verify receipt is both pass and stale (older
  than the routes receipt)? — the latest-wins rule applies per receipt
  file; staleness ordering by the `at` timestamp, with the verdict
  recorded in the item when superseded.
- What happens when the same behavior id appears in multiple green
  entries? — last entry wins (the CycleEvidence append-only convention).
- What happens when `--run-tests` hits a test-runner timeout? — reported
  as `test_runtime` drift with the timeout duration; the command never
  hangs past its per-test budget.
- What happens on a repo where generation verbs wrote no receipts (the
  25+ verbs that do not emit receipts yet)? — gaps, never errors (the
  hard constraint: "missing receipts are reported as gaps, not errors").

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The command MUST be a NEW subcommand `zfa proof chain`
             under the existing `zfa proof` group, leaving `zfa proof
             check` (#807) byte-for-byte unchanged in behavior and flags.
- **FR-002**: Receipt digest validation — the command MUST walk every
             parseable `proof.v1`/`test.v1` receipt in `.zfa/receipts/`
             and verify each recorded file path + SHA-256 digest against
             the current file on disk; drift MUST be reported with file
             path, expected digest, and actual digest.
             traces: ProofChainChecker
- **FR-003**: Behavior coverage — for every feature under `specs/` with
             a `tdd/test-list.md`, the command MUST check each declared
             behavior id for green evidence in `tdd/cycle-log.md`;
             behaviors without green evidence MUST be reported as gaps.
             traces: ProofChainChecker
- **FR-004**: Generated test integrity — for every record in
             `specs/<f>/tdd/artifacts.json`, the command MUST verify the
             test file exists on disk and its imports resolve; with
             `--run-tests` it MUST execute the test and report runtime
             failures.
             traces: ProofChainChecker
- **FR-005**: Route verification — for every declared route receipt
             (`routes-<Entity>.json`), the command MUST read the latest
             verify verdict (`routes-<Entity>-verify.json`): fail is
             drift, missing is a gap, skip-with-reason is honored.
             traces: ProofChainChecker
- **FR-006**: Use-case verification — for every usecase-create receipt
             entity, the command MUST evaluate the usecase conformance
             gate in-process; failures MUST be reported as drift, and
             missing artifacts as gaps.
             traces: ProofChainChecker
- **FR-007**: Xray coverage traceability — for every
             `specs/<f>/tdd/ui-ledger.md`, the command MUST recompute
             each row's traced-ness from current green evidence and
             report declared-but-untraced kinds as gaps.
             traces: ProofChainChecker
- **FR-008**: JSON verdict — `--json` MUST emit exactly one parseable
             JSON object with schema `proof-chain.v1` containing: schema,
             ok, exitClass, counts (per check), and an `items` array
             where every item carries category, severity (`drift`/`gap`/
             `info`), file, expected, actual, and fix.
             traces: ProofChainReport
- **FR-009**: Exit codes — 0 when no drift items exist (gaps do not
             fail), 1 when any drift item exists, 2 on infrastructure
             errors (unreadable receipts directory, unlistable specs),
             per the ratified SPEC 917 protocol.
- **FR-010**: Text mode MUST print a human summary: per-check counts,
             every item with its `--> fix:` line, and a final
             `proof-chain: ... — OK|FAIL|INFRA` verdict line.
- **FR-011**: The command MUST NOT modify any file it reads (receipts,
             cycle-log, artifacts, ledgers) — it is a read-only auditor.
- **FR-012**: A `--run-tests` flag (default off) MUST opt into executing
             registered tests; without it, runtime is reported as
             not-exercised info, never as a pass.

### Non-functional Requirements

- **NFR-001**: Default invocation (no `--run-tests`) MUST complete
             without spawning any subprocess (static checks only) so it
             is fast and hermetic enough for pre-commit hooks.
- **NFR-002**: The checker core MUST be pure/injectable (projectRoot +
             optional test runner injection) so unit tests drive it
             without the CLI.
- **NFR-003**: One broken store (corrupt receipt, missing cycle-log)
             MUST NOT abort the remaining checks — each check degrades
             independently.

## Layer Contracts

**Function**:
- `ProofChainChecker`: `check() -> ProofChainReport`
- `ProofChainReport`: `toJson() -> Map<String, dynamic>`
- `RouteVerifyReader`: `latestVerdict(projectRoot, entity) -> RouteVerifyVerdict?`
