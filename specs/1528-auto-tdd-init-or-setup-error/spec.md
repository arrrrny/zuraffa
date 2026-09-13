# Feature Specification: Preflight — auto `tdd init` or fail with `setup-error` classification

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1528-auto-tdd-init-or-setup-error`

**Created**: 2026-09-13

**Status**: Draft

**Input**: Issue #1528 — "tdd: fresh-project first run stops with classification=unresolved on a missing TDD profile — setup error misclassified, and the idempotent fix (tdd init) is not auto-applied"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fresh-project first run self-heals the baseline (Priority: P1)

An operator seeds a fresh project (spec + `zfa tdd plan`, no `.specify/memory/tdd-profile.md`) and invokes `zfa tdd run <feature>`. Today the run spawns step A1 `verify-red`, whose child stops with `zfa tdd: TDD profile not found … Run `zfa tdd init`` and the meta run reports `stopped_at=A1:verify-red` with the child's `classification=unresolved` — a setup condition misread as a possible engine/test defect. The run must instead preflight the TDD baseline at entry, BEFORE the first step spawns: when the profile is missing, run the idempotent `tdd init` sequence (the exact writer sequence `zfa tdd init` executes), log every artifact it created, and proceed into the loop.

**Why this priority**: This is the reported dogfood failure — the fresh-project first-run experience is broken at the very first behavior, and the loop stops on a condition that is deterministically detectable and deterministically fixable before any test spawns.

**Independent Test**: Can be fully tested by deleting `.specify/memory/tdd-profile.md` from a prepared fixture, running `zfa tdd run <feature>`, and verifying the run recreates the profile (plus the other baseline artifacts), logs the created artifacts, and drives the first step without any `classification=unresolved` on the missing-profile path.

**Acceptance Scenarios**:

1. **Given** a fixture project whose `.specify/memory/tdd-profile.md` is absent and whose feature test list is planned, **When** `zfa tdd run <feature>` starts, **Then** the profile (and the other missing baseline artifacts) are recreated by the idempotent init sequence, the run output names the created artifacts, and the run proceeds past the entry into the first step
   **Type**: acceptance

2. **Given** a fixture project whose TDD profile is already present, **When** `zfa tdd run <feature>` starts, **Then** the entry performs no writes and the run output is byte-identical to the pre-#1528 behavior (the preflight is a silent no-op)
   **Type**: acceptance

3. **Given** a fixture project whose TDD profile is absent, **When** `zfa tdd gen <behavior-id> --project <root>` runs, **Then** the gen entry ensures the same baseline (auto-init, artifacts logged) before the behavior flow executes
   **Type**: acceptance

---

### User Story 2 - Setup conditions never classify as `unresolved` (Priority: P1)

`zfa tdd verify-red` (standalone or as a spawned step) treats a missing TDD profile as a pre-run failure and prints `classification=unresolved` — the same verdict the classifier uses for "the runner could not classify this failure", which reads as a possible engine/test defect. A missing profile is a SETUP condition: deterministically detectable before any test spawns, with a deterministic remediation (`zfa tdd init` is explicitly idempotent). The command must fail CLOSED with a distinct machine-readable classification (`setup-error`), a verdict receipt, and exit before any test is executed — never `unresolved` for setup conditions. `verify-red` does NOT auto-init (its FR-008 contract makes it read-only over `test/` and `lib/` except the cycle-log append; the init writers touch both trees).

**Why this priority**: The misclassification is the defect the issue is titled after; the classification is the machine contract agents parse.

**Independent Test**: Can be fully tested by deleting the profile from a fixture with a registered, gen'd behavior, running `zfa tdd verify-red <id>`, and verifying the final summary line carries `classification=setup-error`, the output names the profile path and the idempotent remediation, and no test process was spawned.

**Acceptance Scenarios**:

1. **Given** a fixture with a registered gen'd behavior and NO profile, **When** `zfa tdd verify-red <id>` runs, **Then** the final stdout line is `verify-red: behavior=<id> classification=setup-error certified=false feature=<feature>`, exit is non-zero, and no evidence is appended
   **Type**: acceptance

2. **Given** the same fixture, **When** `zfa tdd verify-red --all` runs with at least one pending behavior, **Then** the batch summary carries `classification=setup-error` (per-behavior summaries likewise), exit is non-zero
   **Type**: acceptance

3. **Given** a fixture with a valid profile, **When** `zfa tdd verify-red <id>` runs, **Then** the classification vocabulary for every NON-setup outcome is unchanged (assertion / unexpected-green / runner-error / unresolved-for-resolution-errors all behave exactly as before)
   **Type**: acceptance

4. **Given** a fixture with NO profile and an unknown behavior id, **When** `zfa tdd verify-red B-UNKNOWN` runs, **Then** target resolution still fails FIRST with `classification=unresolved` (a caller/usage error is not a setup condition — the pinned U18/sc-004 ordering contract holds)
   **Type**: acceptance

---

### User Story 3 - Auto-init failure fails closed, journaled, machine-readable (Priority: P2)

When the entry preflight cannot ensure the baseline (a baseline writer misfires — unreadable pubspec, unwritable path), the run/gen entries must NOT drive behaviors against a broken baseline. The entry fails closed before any step spawns: the refusal is journaled `preflight_red` in `tdd/journal.json` with the writer failures as violations, the summary line carries `result=setup-error`, the verdict receipt carries `exit_class=setup-error`, and the exit is non-zero (canonical failure 1, per the SPEC 917 golden table).

**Why this priority**: The fail-closed branch only triggers when auto-init cannot complete — rarer than US1, but it is the honesty guarantee that the loop never starts on a half-set-up baseline.

**Independent Test**: Can be fully tested by making the baseline writers fail (e.g. replacing `pubspec.yaml` with a directory), running `zfa tdd run <feature>`, and verifying zero steps spawn, the journal carries a `preflight_red` entry naming the writer failure, and the run summary/verdict carry `setup-error`.

**Acceptance Scenarios**:

1. **Given** a fixture where the init sequence misfires (pubspec unreadable), **When** `zfa tdd run <feature>` starts with the profile missing, **Then** no step spawns, the journal carries the `preflight_red` refusal with the writer failure named, and the final summary line reads `result=setup-error` with zeroed counts
   **Type**: acceptance

2. **Given** the same refusal, **When** the run is invoked with `--json`, **Then** the final stdout line is a `verdict.v1` envelope with `exit_class=setup-error` and a machine-actionable fix hint naming `zfa tdd init`
   **Type**: acceptance

---

## Edge Cases

- Profile present but unreadable (permissions): the entry preflight treats "exists" as the setup-complete signal (no auto-reinit — idempotency means never clobbering hand-edited setup); the downstream profile READ failure keeps its existing classification behavior (out of scope).
- Init partially completes then misfires (profile written, smoke test fails): the run fails closed with `setup-error`; a re-run of the idempotent init completes the remaining artifacts (each writer is skip-if-present).
- Concurrent runs: the preflight adds no locking of its own; the existing concurrent-run detection (exit 4) governs, and the preflight's writers are the same skip-if-present writers `zfa tdd init` has always used.
- `--force` (routing-preflight bypass) does NOT bypass the baseline preflight: the baseline is not a refusal gate, it is self-healing setup — it runs unconditionally at entry.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `zfa tdd run` MUST preflight the TDD baseline at entry, before any lane/step spawns: when `.specify/memory/tdd-profile.md` is missing under the resolved project root, it MUST execute the idempotent `tdd init` writer sequence (profile, dart_test.yaml, spec template, smoke test, Flutter app module when applicable, pubspec dependency patchers) and MUST log each artifact it creates
- **FR-002**: `zfa tdd gen` MUST preflight the TDD baseline at entry, before the behavior flow executes, with the same ensure-and-log semantics as FR-001
- **FR-003**: The auto-init MUST be the SAME writer sequence `zfa tdd init` executes (one shared implementation — no duplicated idempotency logic), MUST run in non-force, non-skin mode, and MUST NOT change `zfa tdd init`'s own observable output
- **FR-004**: When the baseline preflight cannot ensure the profile (a writer misfires), the `run`/`gen` entries MUST fail closed BEFORE any behavior is driven: non-zero exit, summary/verdict carrying the machine-readable class `setup-error`, and for `run` a `preflight_red` journal entry naming the writer failures
- **FR-005**: `zfa tdd verify-red` MUST classify a missing TDD profile as `setup-error` (summary line `classification=setup-error`, verdict receipt `exit_class=setup-error`, non-zero exit) BEFORE any test process spawns — never `unresolved` for this setup condition; `verify-red` MUST NOT auto-init (FR-008 read-only preservation)
- **FR-006**: The batch lane (`verify-red --all`) MUST carry the same `setup-error` classification on a missing profile (batch summary + per-behavior summaries), after the empty-targets early return and before the whole-file template load
- **FR-007**: Resolution-stage errors (unknown behavior id, ambiguous no-arg target, malformed test list) MUST keep their existing `unresolved` classification and their ordering BEFORE the setup check — a caller error is not a setup condition
- **FR-008**: When the TDD profile is already present, the preflight MUST be a silent no-op: no writes, no additional stdout, and the run/gen/verify-red observable behavior byte-identical to pre-#1528
- **FR-009**: Every setup-error exit MUST end with a machine-actionable remediation line naming `zfa tdd init` (the `--> fix:` convention)
- **FR-010**: The TDD loop (step sequencing, state machine, SingleTestRunner execution semantics, red classification of RUNNER transcripts) MUST be unchanged by this feature

## Layer Contracts

**Function**:
- `TddBaselineInit.ensure(projectRoot, {force, skin, onLine, onError}) -> BaselineInitReport(created, failures)` — the shared idempotent baseline writer sequence behind `zfa tdd init` and the entry preflight
- `TddProfilePreflight.ensure(projectRoot, {commandLabel, onLine}) -> ProfilePreflightReport(profilePresent, created)` — the entry-level ensure: no-op when the profile exists, auto-init (via `TddBaselineInit`) when missing, StateError when init misfires
- `verify-red setup check`: profile-existence probe after target resolution (single lane) / after empty-targets return (batch lane) — pure classification, no writes

### Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| TddProfile | `runner`, `single`, `file`, `suite`, `coverage` | The machine-readable runner map at `.specify/memory/tdd-profile.md` — the baseline artifact whose absence is the setup condition |
| BaselineInitReport | `created: List<String>`, `failures: List<String>` | What the shared init sequence created / which writers misfired |
| ProfilePreflightReport | `profilePresent: bool`, `created: List<String>` | What the entry preflight did before the first step |
| SetupErrorClassification | label `setup-error` | The machine-readable verdict for setup conditions; distinct from `unresolved` (the runner could not classify) and from the runner-transcript classes |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh fixture (profile absent, feature planned) driven by `zfa tdd run <feature>` recreates `.specify/memory/tdd-profile.md` at entry and never prints a missing-profile `classification=unresolved` — measurable by asserting the profile exists after the run entry and the step transcript contains no profile-not-found stop
- **SC-002**: A fixture with a valid profile produces byte-identical run/gen output to pre-#1528 — measurable by the existing run/gen test suites passing unchanged (the preflight is a silent no-op)
- **SC-003**: `zfa tdd verify-red` on a profile-less fixture with a gen'd behavior ends with `classification=setup-error` as the FINAL summary token, exit non-zero, no evidence appended, no test process spawned — measurable by the U27-class test flipped red→green
- **SC-004**: `dart analyze` reports no new warnings on the changed files, and every changed-file test passes — measurable by the verification commands in `tdd/verification.md`
- **SC-005**: The resolution-error vocabulary is untouched: unknown-id and ambiguous-target scenarios still classify `unresolved` (pinned U18/U20/sc-004 A13 keep passing)

## Assumptions

- `tdd init`'s writer sequence is the canonical baseline definition; the preflight reuses it verbatim (non-force, non-skin) rather than re-implementing artifact creation
- A missing profile is the ONLY in-scope setup condition; a present-but-malformed profile (no `single:` key) keeps today's misfire behavior (its classification is not part of issue #1528's dogfood evidence)
- The verify-red FR-008 read-only contract (no writes under `test/` or `lib/` beyond the cycle-log append under `specs/`) prohibits verify-red from auto-initializing the baseline; the entries WITHOUT that constraint (`run`, `gen`) own the self-heal
