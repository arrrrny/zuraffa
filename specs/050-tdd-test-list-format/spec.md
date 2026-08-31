# Feature Specification: TDD plan↔gen test-list format contract

**Feature Branch**: `050-tdd-test-list-format`

**Created**: 2026-08-31

**Status**: Draft

**Input**: GitHub issue #617 — "tdd plan ↔ gen test-list format mismatch — gen can't read what plan writes — full loop (run) stops at first step". `zfa tdd plan` writes 4-column behavior rows (`| id | behavior | traces | state |`), but `zfa tdd gen`'s parser silently skipped rows with fewer than 6 cells; every behavior planned by plan was "unknown" to gen, so `zfa tdd run <feature>` stopped at its first step (`stopped_at=A1:gen`) with `zfa tdd gen: unknown behavior id`. The loop's two halves spoke different dialects; only hand-written 6-column lists worked with gen, and those were rejected by run's own 4-column reader.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run the full TDD loop from plan to done (Priority: P1)

A developer plans a feature with `zfa tdd plan <feature>`, then drives the whole
red-green-refactor loop with `zfa tdd run <feature>`. The loop must complete
end-to-end: every behavior the plan wrote is driven through gen → verify-red →
make → refactor, and the run finishes with `result=complete` and exit 0 — it
must never stop at its first step because gen cannot read what plan wrote.

**Why this priority**: This is the issue's headline failure — the completed
loop is dead on arrival when its two halves cannot parse each other's format.
Everything else in this spec exists to keep that front door open.

**Independent Test**: Run `zfa tdd plan <feature>` then `zfa tdd run <feature>`
on a real temp project with the real pipeline; assert the run reaches the gen
step of every behavior, ends `result=complete`, and exits 0.

**Acceptance Scenarios**:

1. **Given** a feature whose `tdd/test-list.md` was written by `zfa tdd plan`
   (4-column rows), **When** the developer runs `zfa tdd run <feature>`, **Then**
   every behavior is resolved by gen (no `unknown behavior id`), the loop drives
   all behaviors to DONE with evidence, and the run exits 0.
2. **Given** a `zfa tdd gen <behavior-id>` invocation against a plan-written
   list, **When** gen resolves the id, **Then** the behavior's kind comes from
   the enclosing section header (Outer loop → acceptance, Inner loop → unit)
   and its target resolves to the documented default when the row carries none.
3. **Given** a behavior id that no row in any scanned list matches, **When**
   `zfa tdd gen <behavior-id>` runs, **Then** it exits non-zero with
   `unknown behavior id` before any file is written.

---

### User Story 2 - Hand-written legacy 6-column lists keep working (Priority: P2)

A developer or agent following the spec-kit TDD extension hand-wrote a
`tdd/test-list.md` in the extension's 6-column shape
(`| id | behavior | traces | kind | state | test |`) — the shape this repo's
own specs/044–049 use. Those features must still be readable: the loop accepts
the legacy rows for one release, resolves their kind and target without
surprise, and tells the author the 4-column plan format is canonical.

**Why this priority**: The issue explicitly flags the migration risk for
hand-written 6-column fixtures; a format contract that instantly bricks the
repo's own completed features is not a contract, it is a regression.

**Independent Test**: Seed a feature with a hand-written 6-column list whose
kind cell is an extension test-shape (e.g. `example`), run `zfa tdd gen` /
`zfa tdd run` against it, and assert the rows resolve and the deprecation note
is printed — no `malformed test list` stop.

**Acceptance Scenarios**:

1. **Given** a test list whose rows are the extension's 6-column shape with a
   kind cell naming a test shape (`example`, `property`, `contract`,
   `approval`, or `characterization`), **When** any loop command reads the
   list, **Then** each row's kind comes from its section header, a path-like or
   empty last cell falls back to the default subject target, and a one-time
   deprecation note naming the canonical format is printed to stderr.
2. **Given** a test list whose 6-column rows carry `acceptance` or `unit` in
   the kind cell, **When** any loop command reads the list, **Then** the kind
   cell wins over the section header (the already-shipped compatibility rule)
   and the same deprecation note is printed.
3. **Given** the repo's own completed features (e.g. `049-tdd-run`) whose lists
   are hand-written in the 6-column extension shape, **When** `zfa tdd run
   <feature>` re-reads the list, **Then** the run proceeds past list-reading
   (no `result=runner-error` caused by the list's dialect).

---

### User Story 3 - Format drift fails loudly, at the front door (Priority: P3)

A maintainer changes the test-list format (or introduces a new dialect) without
updating every consumer. The shared reader must surface the drift immediately
with an error that names the file, the line, and the offending content — never
silently skip rows — and CI must catch drift at the loop's front door through
an end-to-end test that runs the real plan → run path.

**Why this priority**: The original bug survived because gen *silently
skipped* rows it did not understand. A contract that fails silently invites
the same bug back; a contract that fails loudly with a pinned e2e keeps it out.

**Independent Test**: Seed a list with a row matching neither the 4-column
canonical shape nor a recognized 6-column legacy shape; assert the reader
throws naming the line number and raw line, and the command exits non-zero.

**Acceptance Scenarios**:

1. **Given** a row that matches no accepted shape (wrong column count, unknown
   state, or an unusable kind cell), **When** the list is read, **Then** the
   reader raises an error naming the line number and the raw line content, and
   the calling command exits non-zero without writing files.
2. **Given** CI on a pull request that lets a consumer drift from the shared
   contract, **When** the slow-tier loop e2e (plan → run on a real temp project
   with the real pipeline) runs, **Then** the e2e fails at the drift point.

---

### Edge Cases

- A 4-column row appearing outside any `## Outer loop:` / `## Inner loop:`
  section (kind cannot be inferred) — malformed, stops with the line named.
- A 6-column extension-shape row outside any section (same ambiguity) —
  malformed, stops with the line named.
- A row whose state cell is not one of the accepted states (`PENDING`, `RED`,
  `GREEN`, `DONE`) — malformed, stops naming the unknown state.
- An empty behavior id in an otherwise well-shaped row — malformed.
- A list that exists but contains no behavior rows — the reader returns no
  rows and the run command reports it rather than pretending success.
- Pre-extension legacy lists with column counts other than 4 or 6 (e.g. the
  7-column rows in early specs) — out of scope; they stop the scan with the
  same named-line error (surfaced drift, not silent skipping).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The 4-column row shape `| id | behavior | traces | state |`
  written by `zfa tdd plan` MUST be the single canonical test-list contract;
  every loop consumer (gen, run) MUST parse lists through the one shared
  `TestListReader`.
- **FR-002**: The reader MUST derive a row's kind (acceptance vs unit) from its
  enclosing `## Outer loop:` / `## Inner loop:` section header for canonical
  rows.
- **FR-003**: The reader MUST resolve every row's subject target and never
  return an empty target: an explicit, non-path-like cell wins; otherwise the
  target defaults to `subject_<snake-id>`.
- **FR-004**: `zfa tdd gen` MUST resolve behavior ids through the shared
  reader; an id that no row matches MUST exit non-zero with
  `unknown behavior id` before any file is written.
- **FR-005**: A malformed row (wrong shape, unknown state, empty id, or
  unusable kind cell) MUST stop the reading command with an error naming the
  file, line number, and raw line; rows MUST never be silently skipped.
- **FR-006**: Hand-written 6-column rows whose kind cell is `acceptance` or
  `unit` MUST be accepted for one release, with the kind cell taking precedence
  over the section header, and a deprecation note printed once per file.
- **FR-007**: Hand-written 6-column rows whose kind cell is an extension test
  shape (`example`, `property`, `contract`, `approval`, `characterization`)
  MUST be accepted for one release, with the kind derived from the section
  header and the last cell treated as a test reference (path-like or empty
  cells fall back to the default target), and the same deprecation note
  printed once per file.
- **FR-008**: A slow-tier end-to-end test MUST exercise the exact repro —
  `zfa tdd plan` then `zfa tdd run` on a real temp project with the real
  pipeline — so format drift fails CI at the loop's front door.
- **FR-009**: The deprecation note MUST name the canonical 4-column format and
  the command (`zfa tdd plan <feature>`) that writes it.
- **FR-010**: Reading a list MUST be side-effect free apart from the stderr
  deprecation note; the reader MUST NOT rewrite, migrate, or delete the file
  it read.

### Key Entities

- **BehaviorRow**: one parsed test-list row — id, description, traces,
  state, kind, target; produced by the shared reader.
- **TestListReader**: the single parser for `tdd/test-list.md`; owns kind
  inference, state parsing, target defaulting, the deprecated 6-column
  compatibility shim, and the named-line malformed error.
- **Test list file** (`specs/<feature>/tdd/test-list.md`): the artifact both
  halves of the loop share; canonical shape written by `zfa tdd plan`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a real temp project, `zfa tdd plan <feature>` followed by
  `zfa tdd run <feature>` completes with `result=complete`, exit 0, and zero
  occurrences of `unknown behavior id`, `stopped_at=A1:gen`, or
  `result=stopped`.
- **SC-002**: All pre-existing features in this repo whose test lists are
  hand-written 6-column extension-dialect files (specs/044–049) are read
  without a malformed-list stop by the shared reader.
- **SC-003**: The full TDD plugin suite (`dart test test/plugins/tdd/`) and
  `dart analyze` pass with the new contract in place — zero regressions.
- **SC-004**: A deliberately malformed row stops the reader with an error
  naming the line number and raw line, verified by test.
- **SC-005**: The slow-tier loop e2e pins the plan→run contract and fails when
  any consumer stops understanding plan's canonical shape.

## Assumptions

- The compatibility shim is intentionally time-boxed: it accepts hand-written
  6-column rows for one release while authors re-run `zfa tdd plan` to
  migrate; removal is a future, separately-specced change.
- Pre-extension legacy lists with column counts other than 4 or 6 (e.g. the
  7-column rows in early specs) are out of scope for the shim; they continue
  to stop scans with the named-line error.
- The repo is a pure-Dart root package; the TDD plugin commands run through
  `bin/zfa.dart` and in-process `CliRunner` in tests, per the stack profile.
- Behavior states recognized by the driver remain `PENDING`, `RED`, `GREEN`,
  `DONE`; extension-only states (`BASELINE`, `BLOCKED`, `DROPPED`) are list
  bookkeeping, not driver states, and are not required to be drivable.
