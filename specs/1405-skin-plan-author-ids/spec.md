# Feature Specification: Skin plan author emits strict W-ids; plan validator rejects malformed ids

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `feat/1405-skin-plan-author-ids`

**Created**: 2026-09-10

**Status**: Draft

**Input**: User description: "Issue #1405 — skin lane emits a malformed outer-loop behavior table with sentence-fragment ids; 8 of 9 behaviors machine-unreachable (skin lane stuck at 0/1; only W2 ever gets a generated test)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The skin plan author emits strict W-ids (Priority: P1)

A developer declares the SKIN lane's W-behaviors in a spec's `## Lanes`
section and runs `zfa tdd plan`. The authoring step that produces the SKIN
plan's outer-loop behavior table writes every W-behavior id strictly matching
`^W\d+$` — one row per W-behavior, with any prose the declaration carried in
the **behavior** column, never in the **id** column. A declaration token that
arrives contaminated by leaked sentence prose (`W1 (renders the login screen
pixel-perfect` — a sentence split mid-fragment at a comma, leaving an
unmatched paren) is emitted as the strict id `W1` with the prose remainder
moved into the behavior column. The emitted id is never a sentence fragment
and never truncated mid-sentence.

**Why this priority**: This is the emission fix — the malformed table is the
root cause of the skin lane's 0/1 stall, and strict emission is what makes
the 9 declared behaviors machine-reachable again.

**Independent Test**: Plan a spec whose SKIN lane declares
`behaviors: [Sign In header and subtitle, W1 (renders the login screen pixel-perfect, W2]`;
the emitted table's W rows carry `W1` with prose in the behavior column, and
no row carries prose, spaces, or an unmatched paren in the id column.

**Acceptance Scenarios**:

1. **Given** a SKIN lane declaration token that starts with a `W<digits>`
   id followed by leaked prose or an unmatched paren, **When** the skin plan
   is authored, **Then** the row's id column is exactly the `W<digits>` id
   and the prose remainder appears in the row's behavior column
   **Type**: acceptance
2. **Given** any authored skin plan outer-loop table, **When** its id
   columns are inspected, **Then** every W-behavior id matches `^W\d+$` —
   no prose, no spaces, no unmatched parens, no truncated mid-sentence ids
   **Type**: acceptance

---

### User Story 2 - The plan validator rejects malformed ids at plan time (Priority: P1)

A spec whose `## Lanes` SKIN declaration carries behavior tokens that are
not W-behaviors at all (bare sentence fragments with no `W\d+` pattern —
`Sign In header and subtitle`, `a full-width guest outline button`,
`an or divider`) cannot be authored into W rows. The plan validator rejects
the plan at **plan time** — before any artifact is written and long before
gen/run — with refusal lines that name the offending token and the fix. The
malformed outer-loop table is never ingested: no `04-SKIN.md` is written, no
behavior row is synthesized from prose, and the exit code is 2. The
validator's diagnosis names the malformation class: an id column carrying
spaces, an unmatched paren, or no `W\d+` pattern.

**Why this priority**: Defense in depth — without the validator, a
non-sanitizable prose token would either silently vanish (the silent-drop
bug class, issue #1432) or leak into the table again.

**Independent Test**: Plan a spec whose SKIN lane declares
`behaviors: [Sign In header and subtitle, W2]`; the plan exits 2, the
refusal names `Sign In header and subtitle` with no `W\d+` pattern, and no
`04-SKIN.md` exists on disk.

**Acceptance Scenarios**:

1. **Given** a SKIN lane declaration token whose id column would contain
   spaces, **When** the plan runs, **Then** the plan is rejected at plan
   time with a refusal naming the token and the space malformation
   **Type**: acceptance
2. **Given** a SKIN lane declaration token whose id column would carry an
   unmatched paren, **When** the plan runs, **Then** the plan is rejected at
   plan time with a refusal naming the token and the unmatched-paren
   malformation **Type**: acceptance
3. **Given** a SKIN lane declaration token with no `W\d+` pattern at all,
   **When** the plan runs, **Then** the plan is rejected at plan time with a
   refusal naming the token and the missing-pattern malformation
   **Type**: acceptance
4. **Given** a plan rejected by the validator, **When** the feature
   directory is inspected, **Then** no `04-SKIN.md` and no behavior row
   derived from the malformed tokens exist — the malformed table was not
   ingested **Type**: acceptance

---

### User Story 3 - Status reflects the actual W-id count (Priority: P2)

With the plan fixed, `zfa tdd status` reports the skin lane's denominator
from the plan's machine-reachable W-id count — a spec declaring nine skin
behaviors plans nine W rows, the lane plan resolves nine behaviors, and the
lane verdict line reports `0/9` (or `9/9` when green) — never the malformed
world's silent `0/1` where nine declared behaviors collapsed to one
reachable row.

**Why this priority**: The status command reads run receipts whose totals
derive from the rows the lane plan resolves; the correct count follows from
strict emission plus validator rejection, and proving it pins the user-visible
symptom closed.

**Independent Test**: Plan a spec whose SKIN lane declares `W1-W9` with
clean ids and nine behavior prose annotations; the SKIN plan carries nine
W rows and the test-list reader resolves nine skin behaviors from it.

**Acceptance Scenarios**:

1. **Given** a spec whose SKIN lane declares nine W-behaviors with clean
   ids, **When** the feature is planned, **Then** the SKIN plan's
   outer-loop table carries exactly nine rows with ids `W1` through `W9`
   **Type**: acceptance
2. **Given** the planned SKIN plan from acceptance scenario 1, **When**
   the test-list reader resolves the lane plan's rows, **Then** it resolves
   nine skin behaviors — the W-id count, not a truncated remainder
   **Type**: acceptance

---

### User Story 4 - Clean W1..Wn specs keep working byte-compatibly (Priority: P2)

A spec whose SKIN lane already declares clean `W1..Wn` ids continues to plan
exactly as before: the validator passes it, no refusal fires, the emitted
table keeps the same shape, and every existing lane-plan consumer (gen, make,
run, verify) reads it unchanged. The validator only rejects malformed ids —
it never tightens the grammar for ids that already match `^W\d+$`, and the
CORE/BOTH lane declarations (with their documented `A3 (acceptance: ...)`
annotation form) are untouched.

**Why this priority**: Backward compatibility is the release gate — the fix
must never cost a working spec a re-run.

**Independent Test**: Re-plan the canonical issue-#1000 lane fixture (CORE
`[A1, A2, U1-U6]`, SKIN `[W1-W4]`, BOTH `[A3 (acceptance: navigates to
deal_list)]`); the plan exits 0, `04-SKIN.md` carries the four W rows, and
the BOTH annotation lands in the behavior column as before.

**Acceptance Scenarios**:

1. **Given** a spec with clean `W1-W4` SKIN ids and the documented BOTH
   annotation form, **When** the feature is planned, **Then** the plan
   exits 0 with the same lane-plan shape as before this change
   **Type**: acceptance
2. **Given** any plan the validator passes, **When** gen/run consume the
   lane artifacts, **Then** their behavior is unchanged — the fix touches
   only the skin plan author's emission and the plan-time validation
   **Type**: acceptance

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The skin plan author MUST emit skin W-behavior ids strictly
  matching `^W\d+$`: one row per W-behavior, prose in the behavior column
  only.
- **FR-002**: A SKIN declaration token that starts with a `W\d+` id and
  carries trailing prose or an unmatched paren MUST be emitted as the strict
  `W\d+` id with the prose remainder moved to the row's behavior column.
- **FR-003**: The plan validator MUST reject — at plan time, before any
  artifact is written — a SKIN lane whose declared behavior token would
  produce an id column containing spaces, an unmatched paren, or no `W\d+`
  pattern, with refusal lines naming the token and the malformation class.
- **FR-004**: A rejected plan MUST write no `04-SKIN.md` (and no lane
  artifacts) and MUST exit 2 — the malformed outer-loop table is never
  ingested.
- **FR-005**: Specs with clean `W1..Wn` SKIN ids MUST continue to plan
  with exit 0 and an unchanged table shape (backward compatibility).
- **FR-006**: The fix MUST NOT change the core engine cycle, the gen
  pipeline, the make pipeline, the verify gate, or the skin lane derivation
  algorithm (which behaviors exist and their lane assignment) — only the
  skin plan author's output format validation and emission.

### Key Entities

- **Skin plan author**: the plan-time step that turns `## Lanes` SKIN
  declarations into the SKIN plan's outer-loop behavior table rows.
- **Plan validator**: the plan-time gate that inspects the W-behavior ids
  destined for the SKIN plan's outer-loop table and refuses malformed ones.

## Success Criteria *(measurable)*

- **SC-01**: A SKIN declaration token `W1 (renders the login screen
  pixel-perfect` plans to a row whose id column is exactly `W1` and whose
  behavior column carries `renders the login screen pixel-perfect`
  (measurable: the emitted `04-SKIN.md` table row).
- **SC-02**: A SKIN declaration containing `Sign In header and subtitle`
  (no `W\d+` pattern) makes `zfa tdd plan` exit 2 with a refusal naming the
  token, and no `04-SKIN.md` is written (measurable: exit code + file
  absence).
- **SC-03**: A SKIN declaration token that cannot be resolved to a strict
  W-id row — no `W\d+` pattern at all (e.g. `Sign In header and subtitle`)
  or an id-shaped fragment that would put spaces or an unmatched paren into
  the id column without a leading `W\d+` anchor — is rejected at plan time
  with the malformation class named; a token that DOES start with `W\d+`
  (e.g. `W1 renders the login screen`, `W1 (renders`) is instead emitted
  strictly per SC-01 (measurable: refusal text vs. emitted row).
- **SC-04**: A spec declaring SKIN `W1-W9` with clean ids plans nine W rows
  and the lane plan resolves nine skin behaviors (measurable: row count in
  `04-SKIN.md` + reader resolution count).
- **SC-05**: The canonical issue-#1000 lane fixture (clean `W1-W4`, BOTH
  `A3 (acceptance: ...)`) plans with exit 0 and an unchanged `04-SKIN.md`
  shape (measurable: exit code + table shape).
- **SC-06**: Every malformed-id rejection happens at plan time: after a
  rejected plan, the feature directory contains no new `04-SKIN.md`
  (measurable: file absence immediately after the refused run).

## Assumptions

- The SKIN lane's W-id grammar is `^W\d+$` (the `W1-W4` skin-slot
  reservation documented since issue #1000); CORE/BOTH lanes keep their
  existing documented id grammar (`A3 (acceptance: ...)` annotations).
- The skin lane derivation algorithm — which behaviors exist and how lanes
  are assigned — is unchanged; the author only re-formats what it emits and
  the validator only gates the emitted ids.
- A sanitizer-rescuable token (leading `W\d+` + prose) is emitted with the
  prose in the behavior column; a token with no leading `W\d+` is not a
  W-behavior and is refused, never silently dropped.

## Out of Scope

- The `zfa tdd split` command's prior-list ingestion path, the gen
  pipeline, the make pipeline, the verify gate, and the run driver cycle.
- The spec parser's `## Lanes` tokenizer itself (the derivation input);
  the fix validates and formats what the author emits from it.
- Non-skin lanes' id grammar (CORE `A/U` ids, BOTH seam ids).
