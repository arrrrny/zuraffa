# Feature Specification: `zfa tdd corpus` — batch loop driving, provenance audit, and the gap ledger

**Feature Branch**: `051-corpus-harness`

**Created**: 2026-08-31

**Status**: Draft

**Input**: Issue [#628](https://github.com/arrrrny/zuraffa/issues/628) — epic `045-tdd-full-app-cycle` precondition 5 (the harness). User description: "drive 120 extracted features through the loop on a greenfield app. The per-feature commands exist (plan/run/verify) but nothing orchestrates the corpus: batch driving in dependency order with resume, per-feature verify gate, a provenance audit attributing every lib/ file to a logged zfa command (minus the declared manual-UI carve-out manifest), and a gap ledger recording every STOP-ON-ROADBLOCK misfire so worked-around progress never counts."

## Mission

The epic's proof gate is 120 features, each driven
`plan → run → verify` by zfa commands only, with mechanical evidence that
no hand-written production code exists. The per-feature machinery is done
and verified live; what's missing is the **orchestrator**: a corpus-level
command that drives features in order, resumes across interruptions, gates
each feature on its verify audit, attributes every production file to a
logged zfa invocation, and — critically — records every misfire in a gap
ledger so zuraffa's gaps become first-class work items instead of silent
workarounds. This command is what makes "the app was written only by the
zfa tdd cycle" a checkable claim rather than an assertion.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Drive the corpus, feature by feature, with resume (Priority: P1)

A maintainer runs `zfa tdd corpus run` on the target app (fresh
`zfa setup` + corpus import, #627). The command reads the corpus manifest,
drives each `ready` feature through `zfa tdd run` then `zfa tdd verify`,
persists corpus-level progress after every feature (done / stopped /
not-ready), and on re-run resumes from the first incomplete feature. A
feature whose loop stops (e.g. #625-style deferral stops, or a generator
gap) halts the corpus run per STOP-ON-ROADBLOCK: the stop is recorded in
the gap ledger, and the run reports exactly where to resume.

**Why this priority**: This is the epic's engine — nothing else in the
harness matters if the corpus cannot be driven and resumed.

**Independent Test**: A 3-feature fixture corpus (one that completes, one
that stops on a scripted gap, one not-ready) → `corpus run` drives feature
1 to done+verified, stops on feature 2 with a ledger entry, leaves feature
3 untouched; re-run after "fixing" the gap resumes at feature 2 without
re-driving feature 1.

**Acceptance Scenarios**:

1. **Given** a manifest of N ready features, **When** `zfa tdd corpus run`
   executes, **Then** each feature is driven `run`-then-`verify` in manifest
   order, corpus progress persists after each feature, and the final summary
   reports per-feature outcomes.
2. **Given** a corpus run interrupted after feature k, **When** the
   maintainer re-runs it, **Then** features 1..k are not re-driven and the
   run resumes at k+1.
3. **Given** a feature whose loop stops (any step failure), **When** the
   corpus run reaches it, **Then** the whole run stops non-zero, the stop is
   recorded in the gap ledger (feature, behavior, step, outcome, issue link
   placeholder), and later features are not started.

---

### User Story 2 - Per-feature verify gate (Priority: P1)

A feature only counts as corpus-done when its `zfa tdd verify` gate passes
(or is explicitly waived with a recorded reason). The corpus runner treats
verify outcomes as first-class: `PASS` → feature done; `FAIL_SURVIVED` /
`FAIL_TIMEOUT` / `PREFLIGHT_RED` → stop and ledger; `NOT_ASSESSED` → stop
and ledger with the "mutation tool unavailable / gate policy" reason, so
the maintainer decides about the gate-policy question rather than the
runner silently absorbing it.

**Acceptance Scenarios**:

1. **Given** a feature whose loop completed and whose verify gate passes,
   **When** the corpus runner finishes it, **Then** the feature is marked
   done in corpus progress with the gate recorded.
2. **Given** a feature whose verify gate returns `NOT_ASSESSED`, **When**
   the corpus runner evaluates it, **Then** the run stops, the ledger
   records the reason, and the feature is not counted done.
3. **Given** an explicit recorded waiver for a verify outcome, **When** the
   runner evaluates that feature, **Then** the waiver (reason + who + when)
   is visible in corpus progress and the final report — never silent.

---

### User Story 3 - Provenance audit: every production file attributed (Priority: P1)

The maintainer runs `zfa tdd corpus audit`. The tool attributes every file
under the app's `lib/` to a logged zfa command invocation — drawn from the
cycle logs' recorded generation steps, the import/setup provenance, and the
declared manual-UI carve-out manifest. Unattributed files fail the audit by
name. The output is the epic's proof artifact: a machine-readable report
plus a human summary (`attributed / carve-out / unattributed` counts).

**Why this priority**: This is the checkable form of the epic's central
claim — without it, "only zfa wrote this app" is a story, not evidence.

**Acceptance Scenarios**:

1. **Given** a corpus-driven app, **When** `corpus audit` runs, **Then**
   every `lib/` file maps to a recorded zfa invocation or a declared
   carve-out entry; 100% attribution exits 0.
2. **Given** a file under `lib/` with no recorded provenance and no
   carve-out entry, **When** the audit runs, **Then** it exits non-zero
   naming the file.
3. **Given** the carve-out manifest, **When** an entry is removed, **When**
   the audit re-runs, **Then** the corresponding file becomes unattributed
   and fails — the manifest is the only exemption path and is itself
   versioned content.

---

### User Story 4 - The gap ledger (Priority: P1)

Every STOP-ON-ROADBLOCK event across the corpus run — step failures,
unexpressible behaviors, gate failures, misfires — lands in a single gap
ledger: feature, behavior, step, outcome, the failing command, and a link
field for the zuraffa issue it becomes. The ledger is append-only, survives
resumes, and the corpus report closes with ledger totals (gaps found /
issues filed / issues merged / gaps blocking). Worked-around progress never
appears: a feature is done only through the gated loop.

**Acceptance Scenarios**:

1. **Given** any corpus stop, **When** it happens, **Then** a ledger entry
   is appended with the five required fields and no test/source edits.
2. **Given** a resumed run that later passes the previously-gapped feature,
   **When** the ledger is read, **Then** the old entry remains (append-only
   history) and the feature's resolution is a new entry, not an edit.
3. **Given** the final corpus report, **When** the maintainer reads it,
   **Then** it lists ledger totals and names every unresolved gap blocking
   completion.

---

### User Story 5 - Corpus status at a glance (Priority: P2)

The maintainer runs `zfa tdd corpus status` to see, without driving
anything: features done / stopped / pending / not-ready (from the manifest
and corpus progress), gate outcomes, ledger totals, and the resume point.
Machine-readable final line, same contract style as the loop commands.

**Acceptance Scenarios**:

1. **Given** a partially driven corpus, **When** `corpus status` runs,
   **Then** it reports per-state feature counts, the resume point, and
   ledger totals, changing nothing.
2. **Given** CI consuming `corpus status`, **When** the summary line is
   parsed, **Then** exit 0 means "all manifest features done+gated", any
   non-zero means incomplete, without prose scraping.

---

### Edge Cases

- A feature marked not-ready in the manifest (#627): the runner skips it
  and reports it — never attempts to drive it.
- Corpus manifest edited mid-run (features added/removed): added features
  are driven on the next run; removed features keep their progress entries
  marked dropped (append-only, mirroring `run`'s dropped semantics).
- Two corpus runs concurrently on the same app: the second refuses via the
  corpus-level in-flight marker (same guard pattern as `run`).
- The verify gate's mutation cost at corpus scale: the runner passes a
  per-feature verify invocation as-is; any gate-policy decision (e.g. an
  explicit recorded waiver level) is surfaced through the ledger, not
  decided silently by the runner.
- Setup/import provenance (scaffold files like `main.dart`, the app shell
  from #626's fix) must be attributable too — the audit consumes the
  setup/import provenance records, not only loop cycle logs.

## Requirements *(mandatory)*

### Functional Requirements

**Corpus driving**

- **FR-001**: `zfa tdd corpus run` MUST drive every `ready` manifest
  feature, in manifest order, through `zfa tdd run` then `zfa tdd verify`,
  persisting corpus progress after each feature and resuming from the first
  incomplete feature on re-run.
- **FR-002**: Any feature-level stop MUST halt the corpus run non-zero,
  append a gap-ledger entry, and never start later features
  (STOP-ON-ROADBLOCK at corpus granularity).
- **FR-003**: Not-ready features MUST be skipped and reported, never driven.

**Verify gate**

- **FR-004**: A feature counts as corpus-done ONLY on a passing verify gate
  or an explicit recorded waiver (reason + actor + timestamp) visible in
  progress and final reports; `NOT_ASSESSED` and every failure outcome stop
  the run and ledger the reason.

**Provenance audit**

- **FR-005**: `zfa tdd corpus audit` MUST attribute every file under the
  app's `lib/` to a recorded zfa command invocation (loop cycle logs,
  setup/import provenance) or an entry in the versioned carve-out manifest;
  any unattributed file fails the audit by name.
- **FR-006**: The audit MUST emit a machine-readable report (per-file
  attribution, carve-out list, counts) plus the human summary line.

**Gap ledger**

- **FR-007**: Every corpus stop MUST append a ledger entry with feature,
  behavior, step, outcome, failing command, and issue-link field;
  append-only, resume-safe.
- **FR-008**: The final corpus report MUST include ledger totals
  (found / filed / merged / blocking) and name every unresolved blocking
  gap.

**Status & contract**

- **FR-009**: `zfa tdd corpus status` MUST report per-state counts, resume
  point, and ledger totals read-only, with a machine-readable summary line;
  exit 0 exactly when all manifest features are done+gated.
- **FR-010**: Concurrent corpus runs on the same app MUST be refused via a
  corpus-level in-flight marker; no state corruption.
- **FR-011**: The runner MUST honor the misfire-stop policy: any internal
  step that cannot complete stops with a non-zero exit and a clear report.

### Key Entities

- **Corpus Manifest**: from #627 — ordered features with readiness marks.
- **Corpus Progress**: persisted per-feature state (pending / driving /
  done+gated / stopped / waived) + in-flight marker; resume source.
- **Gap Ledger**: append-only stop records with issue links — the epic's
  gap-tracking artifact.
- **Provenance Record**: file → zfa invocation mapping (cycle logs +
  setup/import provenance).
- **Carve-out Manifest**: the versioned, sole exemption list for the
  audit (manual-UI files, per epic 045's clarified carve-out).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The 3-feature fixture (complete / gap / not-ready) drives,
  stops, ledgers, and resumes correctly — completed features never re-driven
  (0 duplicate invocations across resume).
- **SC-002**: 100% of verify outcomes are honored as gates or recorded
  waivers; 0 silent absorptions (fixture matrix over all five gate values).
- **SC-003**: On a corpus-driven fixture app, the audit attributes 100% of
  `lib/` files; planting one unattributed file fails the audit by name in
  100% of runs.
- **SC-004**: 100% of stops produce complete ledger entries; ledger history
  survives resumes with 0 edits to past entries.
- **SC-005**: `corpus status` summary line and exit codes are stable for CI
  consumption (contract test).

## Out of Scope

- Test-list format concerns (#617) and acceptance deferral (#625) — the
  runner consumes fixed behavior of `run`/`verify`; those issues fix the
  loop internals.
- Corpus import itself (#627) and the day-zero app surface (#626) — the
  harness consumes their outputs.
- Dependency-ordered driving beyond manifest order (lexicographic from
  #627; smarter ordering can grow later without contract change).
- Deciding the mutation gate policy — the runner surfaces it via ledger +
  waivers; the policy decision stays with the maintainer.

## Assumptions

- The per-feature commands (`run`, `verify`) and their machine contracts
  are stable as merged (#617/#625 fixes land independently).
- Corpus scale is ~120 features; per-feature state files and an aggregate
  progress file suffice (no database).
- The carve-out convention follows epic 045's clarified decision (manual-UI
  files allowed, declared, versioned).
- The audit's provenance sources are the cycle logs' generation steps plus
  setup/import provenance records (#626/#627 must emit theirs).
