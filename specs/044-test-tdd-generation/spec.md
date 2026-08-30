# Feature Specification: 044 — Behavior-aware test generation and trustworthy mutation evidence

**Feature Branch**: `044-test-tdd-generation`
**Created**: 2026-08-29
**Status**: Draft
**Origin**: Local draft spec (no GitHub issue). Continues the TDD plugin
landed in `specs/041-tdd-setup-plugin` (PR #585).

## Mission

Extend the `zfa tdd` plugin so `zfa tdd gen <behavior-id>` materializes a
planned behavior into exactly ONE runnable test + ONE paired compilable
subject that honestly fails for the intended observable behavior, and so
`zfa tdd verify --feature <feature>` produces trustworthy, behavior-traced
mutation evidence that cannot be spoofed into a fake pass.

The two command surfaces this spec covers — `gen` and `verify` — are the
load-bearing inputs to the rest of the TDD loop (run, refactor,
verify-red, make). Without honest `gen`, the loop has no red. Without
trustworthy `verify`, the loop has no credible green. Both gaps are
currently filled by misfire-stop stubs and a partial implementation,
which is exactly the kind of "looks done, isn't done" state this spec
closes.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — `zfa tdd gen <behavior-id>` materializes one behavior (P1)

A developer with a behavior in `tdd/test-list.md` runs
`zfa tdd gen <behavior-id>` and the tool writes exactly one test file
under `test/` and exactly one paired subject file under `lib/`, then
returns a structured result listing the behavior id, the source
criterion the behavior traces to, the test path, the subject path, the
runnable test name (file::group::test), and an `Ownership` field telling
the caller whether each artifact was newly created or already present
from a prior `gen` run. The test, on its first execution, must fail
with an assertion-level failure (honest red) — not skipped, not
pending, not an unconditional placeholder, not a compile or load
error.

**Why this priority**: This story is the entry point to the whole TDD
loop. Without it, every downstream command (`verify-red`, `make`,
`run`, `verify`) has no test+subject pair to operate on.

**Independent Test**: From a feature directory with a `tdd/test-list.md`
containing at least one planned behavior, run
`zfa tdd gen <behavior-id>` and confirm exactly one test file and one
subject file are written; then run `dart test <test-path> --plain-name
"<test-name>"` and confirm the runner exits non-zero with an
assertion-failure class, not a compile/load/skip class.

**Acceptance Scenarios**:

1. **Given** `tdd/test-list.md` contains behavior `B-003` (unit
   classification) traced to `FR-007`, **When** the developer runs
   `zfa tdd gen B-003`, **Then** exactly one test file is written under
   `test/`, exactly one subject file is written under `lib/`, the
   command exits 0, and the printed result includes the six required
   fields: behavior id, source criterion, test path, subject path,
   runnable test name, ownership.
2. **Given** the artifacts from scenario 1, **When** the developer runs
   `dart test <test-path> --plain-name "<test-name>"`, **Then** the
   runner exits non-zero and the failure is classified as an assertion
   failure (not compile error, not load error, not skipped, not
   pending).
3. **Given** a behavior identifier that does not exist in
   `tdd/test-list.md`, **When** the developer runs
   `zfa tdd gen <unknown-id>`, **Then** the command exits non-zero
   before writing any file and prints a message naming the unknown
   identifier.
4. **Given** a behavior row missing a required field (description,
   source criterion, target, or classification), **When** the developer
   runs `zfa tdd gen <behavior-id>`, **Then** the command exits
   non-zero before writing any file with a message naming the missing
   field.
5. **Given** a behavior with classification `acceptance` and no
   pre-existing entity/use case/repository, **When** the developer
   runs `zfa tdd gen <behavior-id>`, **Then** the command still
   produces a runnable test and a compiling subject (it does not
   require any scaffolded domain layer to exist).

### User Story 2 — Idempotent repeat and ownership-conflict stop (P1)

A developer who has already run `gen` for a behavior runs `gen` for the
same behavior again. The second invocation detects that both artifacts
already exist, leaves them untouched, and returns `Ownership.reused`
for both. If, however, only one of the two artifacts exists, or an
artifact exists but was not written by `gen` (no recorded artifact
entry), the command refuses to overwrite the non-owned file, exits
non-zero, prints a message naming the affected file and the missing
ownership record, and leaves all files unchanged.

**Why this priority**: This story is the integrity guarantee for the
artifact registry. Without idempotency, repeated `gen` calls would
duplicate or shred tests; without the ownership-conflict stop, `gen`
would silently rewrite user-authored files it did not own.

**Acceptance Scenarios**:

1. **Given** `gen B-003` has already produced `test/B-003_test.dart`
   and `lib/B-003_subject.dart`, and the artifact registry records
   ownership of both, **When** the developer runs `gen B-003` again,
   **Then** no file is written, the command exits 0, and the result
   reports `Ownership.reused` for both test and subject.
2. **Given** `test/B-003_test.dart` exists on disk but the artifact
   registry has no entry for it (e.g. a developer hand-wrote the file
   outside `gen`), **When** the developer runs `gen B-003`, **Then**
   the command exits non-zero, prints a message naming
   `test/B-003_test.dart` as a non-owned conflict, and leaves the file
   byte-for-byte unchanged (verified by sha256 before/after).
3. **Given** a `--dry-run` flag, **When** the developer runs
   `zfa tdd gen B-003 --dry-run`, **Then** no file is written, no
   registry entry is created, and the command prints the planned test
   path, subject path, and ownership `planned` for both.

### User Story 3 — `zfa tdd verify --feature <feature>` runs trustworthy mutation (P1)

A developer who has `gen`-produced tests and implementation for a
feature runs `zfa tdd verify --feature 044-test-tdd-generation`. The
command:

1. Resolves the feature's mutation scope from the **registered behavior
   artifacts** (test files + subject files paired by behavior id), not
   from a free-form glob. If no behavior artifacts are registered, the
   audit reports `NOT_ASSESSED — no behavior artifacts registered` and
   exits non-zero.
2. Runs a **green-suite preflight** (`dart test <scope>`) before any
   mutation. If the preflight is not green, the command stops, writes
   `verification.md` with `PREFLIGHT_RED` as the gate decision, and
   exits non-zero. No mutation is performed.
3. Runs the mutation audit. The mutation result records killed /
   survived / timed-out **as three separate buckets**. When the
   mutation tool is unavailable, produces an empty report, produces an
   incomplete report, or produces an unparseable report, the result is
   marked `NOT_ASSESSED` for that bucket — never silently reported as
   a passing gate.
4. Restores every temporarily mutated subject to its pre-mutation bytes
   after the audit, regardless of whether the audit ended in success,
   failure, timeout, or interrupt. Source restoration is verified by
   sha256 comparison before the command returns.
5. Writes `specs/<feature>/tdd/verification.md` from the real run with:
   - feature scope (which behavior ids were in scope);
   - per-behavior outcome (killed/survived/timed-out/NOT_ASSESSED);
   - gate decision (`PASS`, `FAIL_SURVIVED`, `FAIL_TIMEOUT`,
     `PREFLIGHT_RED`, `NOT_ASSESSED`);
   - evidence traces (behavior id + source criterion for every
     affected subject);
   - non-sensitive repro diagnostics (command, exit code, elapsed,
     report path).
6. Never edits a test to fake a pass. The audit may not weaken, skip,
   delete, or filter a test to reach green.

**Why this priority**: This story is the trust boundary. Without it,
the `verification.md` produced by `zfa tdd verify` cannot be trusted
to reflect a real mutation run, and downstream CI gates that consume
it would pass on stubs.

**Acceptance Scenarios**:

1. **Given** a feature with `gen`-registered artifacts and a green
   suite, **When** the developer runs
   `zfa tdd verify --feature 044-test-tdd-generation`, **Then** the
   command runs the mutation audit, classifies every mutant into
   killed/survived/timed-out, restores every subject, and writes
   `verification.md` with the gate decision.
2. **Given** a feature whose preflight `dart test` is red, **When** the
   developer runs `zfa tdd verify --feature <feature>`, **Then** the
   command runs no mutation, writes `verification.md` with
   `PREFLIGHT_RED`, and exits non-zero.
3. **Given** a feature whose mutation tool is unavailable on PATH,
   **When** the developer runs `zfa tdd verify --feature <feature>`,
   **Then** the command writes `verification.md` with
   `NOT_ASSESSED — mutation tool unavailable` for the killed/survived/
   timed-out buckets and exits non-zero.
4. **Given** a feature whose mutation run produces one survived mutant
   traced to behavior `B-003`, **When** the developer runs
   `zfa tdd verify --feature <feature>`, **Then** the command writes
   `verification.md` with gate `FAIL_SURVIVED`, names behavior `B-003`
   and its source criterion as the affected evidence, and exits
   non-zero.
5. **Given** a feature whose mutation run was interrupted mid-audit,
   **When** the developer inspects the subjects after the command
   returns, **Then** every temporarily mutated subject's sha256
   matches its pre-audit sha256 (source restoration verified).

## Functional Requirements *(mandatory)*

### `zfa tdd gen <behavior-id>`

- **FR-001**: `zfa tdd gen <behavior-id>` materializes a planned
  behavior into exactly ONE runnable test file and ONE paired
  compilable subject file. The pair asserts the intended observable
  behavior. The test is honest red on first execution — not skipped,
  not pending, not an unconditional placeholder.

- **FR-002**: Required fields are validated up front: behavior id,
  classification (`unit` or `acceptance`), description, source
  criterion, target. A malformed request fails BEFORE any file is
  written. The failure message names the missing/invalid field.

- **FR-003**: `gen` supports both `unit` and `acceptance`
  classifications. The test+subject shape adapts: unit behaviors
  produce a function-level subject; acceptance behaviors produce a
  behavior-level subject (e.g. a fake "scenario runner" stub).

- **FR-004**: `gen` does NOT require a pre-existing entity/use
  case/repository. It generates a minimal compilable subject from
  scratch — the developer may later wire that subject into a real
  domain layer, but `gen` itself has no such prerequisite.

- **FR-005**: The `gen` result exposes: behavior id, source criterion,
  test path, subject path, runnable test name (file::group::test), and
  ownership status (`created` / `reused`) for both the test and the
  subject.

- **FR-006**: Repeating a matching `gen` request is idempotent: zero
  duplicate tests or subjects are created, and the result reports
  `Ownership.reused` for both artifacts.

- **FR-007**: `gen` persists a feature-scoped artifact record linking
  behavior id -> test path + subject path. The record is consumed by
  later TDD commands (`verify`, `run`). The registry file is
  `specs/<feature>/tdd/artifacts.json` and is append-only by `gen`.

- **FR-008**: An ownership conflict — one of the two expected files
  exists on disk but the artifact registry has no entry for that
  behavior+file pair — causes the command to stop WITHOUT modifying
  the file. The exit code is non-zero. The message names the affected
  file and the missing ownership record.

- **FR-009**: `--dry-run` plans the artifact pair without writing
  anything: no file is created, no registry entry is appended. The
  command prints the planned test path, planned subject path, and
  ownership `planned`.

- **FR-010**: The generated test asserts the intended observable
  behavior described in the behavior's `description` field. The
  assertion failure on first execution matches that behavior — not a
  placeholder `expect(true, isFalse)`.

- **FR-011**: The generated subject compiles cleanly. Running
  `dart analyze` on the generated subject reports zero errors (warnings
  allowed for unused-element lints on the stub).

### `zfa tdd verify --feature <feature>`

- **FR-012**: `zfa tdd verify --feature <feature>` derives the mutation
  scope from the registered behavior artifacts (the union of test
  files and subject files recorded in
  `specs/<feature>/tdd/artifacts.json`). When no behavior artifacts are
  registered, the audit reports `NOT_ASSESSED — no behavior artifacts
  registered` and exits non-zero without running the mutation tool.

- **FR-013**: The command runs a green-suite preflight
  (`dart test <scope>`) FIRST, before any mutation. If the preflight
  is not green, the command stops, writes `verification.md` with gate
  decision `PREFLIGHT_RED`, and exits non-zero. No mutation is
  performed in this case.

- **FR-014**: The mutation result records killed / survived / timed-out
  as three separate integer buckets. The three buckets are persisted
  to `verification.md` individually.

- **FR-015**: When the mutation tool is unavailable (binary not on
  PATH, dev_dependency missing), the result is marked
  `NOT_ASSESSED — mutation tool unavailable` for all three buckets.
  The gate decision is `NOT_ASSESSED`. The command exits non-zero.

- **FR-016**: When the mutation report is empty, incomplete, or
  unparseable, the result is marked
  `NOT_ASSESSED — <reason>` for all three buckets. The gate decision
  is `NOT_ASSESSED`. The command exits non-zero.

- **FR-017**: Default strict policy: ANY survived OR timed-out mutation
  fails the gate. The gate decision is `FAIL_SURVIVED` if at least one
  mutant survived, `FAIL_TIMEOUT` if at least one timed out (and none
  survived), else `PASS`. The behavior ids and source criteria of all
  affected behaviors are listed in the report.

- **FR-018**: The report traces every recorded outcome to behavior id
  + source criterion. Every killed/survived/timed-out/NOT_ASSESSED
  line in `verification.md` carries the behavior id and source
  criterion of the affected subject.

- **FR-019**: The report states the gate decision explicitly as a
  top-level field `gate:`. The five allowed values are `PASS`,
  `FAIL_SURVIVED`, `FAIL_TIMEOUT`, `PREFLIGHT_RED`, `NOT_ASSESSED`.

- **FR-020**: The report includes non-sensitive repro diagnostics:
  runner command, exit code, elapsed seconds, mutation report path
  (when one was produced). Secrets are NEVER included (the report
  never echoes environment variables or git tokens).

- **FR-021**: After mutation execution — whether the audit ended in
  success, failure, timeout, or was interrupted — every temporarily
  mutated subject is restored to its pre-audit bytes. Restoration is
  verified by sha256 comparison before the command returns. The
  report records `restoration: verified` or `restoration: FAILED`.

- **FR-022**: The audit NEVER edits a test to fake a pass. The audit
  may not weaken, skip, delete, filter, or rewrite a test to reach a
  passing gate. Any test editing is a hard contract violation
  reported in the audit.

- **FR-023**: The command exits non-zero whenever the gate decision is
  not `PASS`. CI gates consuming the exit code will therefore fail on
  any non-pass outcome.

### Automated coverage (meta-requirements)

- **FR-024**: Automated tests cover: generation (US1.AC1–5),
  idempotency/conflict (US2.AC1–3), standalone honest-red (US1.AC2),
  scoped mutation selection (FR-012),
  killed/survived/timed-out classification (FR-014),
  unavailable/unparseable (FR-015, FR-016), source restoration
  (FR-021).

## Success Criteria

- **SC-001**: Materialize any valid planned unit/acceptance behavior in
  ONE `zfa tdd gen` invocation and run its test independently with a
  loadable, assertion-level red failure on the first attempt.

- **SC-002**: 100% of successful `gen` results expose behavior id,
  source criterion, test path, subject path, runnable test name,
  ownership status — consumable by later TDD commands without
  rediscovery.

- **SC-003**: Repeating a matching `gen` creates zero duplicate
  tests/subjects; 100% of ownership conflicts preserve user content
  unchanged (sha256-verified).

- **SC-004**: 100% of completed `verify` reports identify feature
  scope and classify every evaluated outcome; unavailable/empty/
  incomplete/unparseable visibly marked `NOT_ASSESSED`.

- **SC-005**: A mutation audit with >=1 survived/timed-out mutation
  fails its gate in 100% of runs; reports affected behavior/scope.

- **SC-006**: After any completed/failed/timed-out/interrupted audit,
  source comparison confirms all temporarily mutated subjects restored
  before the command returns.

## Out of Scope

- `zfa tdd make` (impl generation from a red test) — deferred to a
  follow-up spec.
- `zfa tdd refactor` — deferred.
- `zfa tdd run` (full feature loop driver) — deferred.
- Mutation audit parallelism / sharding — deferred.
- Cross-feature mutation scope (`--branch` mode) — deferred.
