# 1610-extract-canonicalize-missing-path

- **Spec ID**: 1610-extract-canonicalize-missing-path
- **Created**: 2026-09-16
- **Source**: GitHub issue #1610 (chore: extract the duplicated canonicalizeMissingPath helper (view + wire) into one documented utility)
- **Type**: chore — deduplication + documentation + direct unit test (P2 — no user-visible failure today; a drift accident waiting for a third canonicalizing command)
- **Branch**: chore/1610-extract-canonicalize-missing-path
- **Related**: #1603 (view_command canonicalization), PR #1606 (view fix, merged 2026-09-13), PR #1516 (wire fix origin, c1e287da), PR #1611 (the review round that already landed the mechanical extraction, 994daeb1)

## Problem

The subject-containment guard in the TDD plugin compares the project root and
the subject path in CANONICAL form, because on macOS the temp root travels a
symlink (`/var/folders` → `/private/var/folders`) and an unresolved comparison
misreads the project's own recorded subject as "outside the project root"
(#1603). A subject file that does not exist yet has nothing to
`resolveSymbolicLinks`, so it is canonicalized through its nearest EXISTING
ancestor plus the re-appended missing segments.

History of the helper:

- `wire_command.dart` carried the first `_canonicalizeMissingPath` copy since
  c1e287da (PR #1516 review round).
- PR #1606 (issue #1603) copied it **verbatim** into `view_command.dart` —
  deliberately, to keep the fix surgical.
- PR #1611's review round (commit 994daeb1) then did the mechanical
  extraction: both private copies were deleted and a shared
  `canonicalizeMissingPath` now lives in
  `lib/src/plugins/tdd/services/path_canonicalizer.dart`, imported by
  `view_command.dart`, `wire_command.dart`, AND `func_command.dart` (the third
  canonicalizing command the issue predicted).

What REMAINS open on the issue's acceptance criteria (the reason #1610 is
still open):

1. **The precondition is still undocumented.** The shared helper silently
   assumes its input is ABSOLUTE. Every call site absolutizes first
   (`p.normalize(p.absolute(cwd))`, with relative recorded subjects joined
   onto the absolute cwd before the call), but the helper's own contract does
   not say so. With a relative input, `p.dirname(path)` yields a relative dir,
   `Directory(...).resolveSymbolicLinks()` resolves it against the CURRENT
   WORKING DIRECTORY, and the result is silently CWD-joined — exactly the
   silent-wrong-result class the guard exists to prevent. A future caller that
   passes a relative path gets no error and no warning, just a quietly
   CWD-dependent answer.
2. **No direct unit test for the walk-up loop.** The helper's output only
   moves the inside/outside verdict of the guard, so the existing command pins
   (U-V11/U-V12/U-V13 in view_command_test.dart, U-W3/U-1603e in
   wire_command_test.dart) cannot distinguish a correct `tail.reversed` order
   from a dropped `.reversed` — for a two-segment tail both orders produce a
   plausible-looking path that still lands inside the root. The shared helper
   has no test file of its own; its walk-up behavior is exercised only
   incidentally through command-level tests.

## Goal

The shared helper is the single documented home of missing-path
canonicalization: its doc comment states the absolute-input precondition, WHY
it exists, and what the fallback returns — and a direct unit test file pins
the walk-up loop (nested missing segments, the tail order, a symlinked nearest
existing ancestor, the defensive no-ancestor fallback) so the order mutation
that the command pins cannot catch is caught at the helper's own level.

## User Scenarios & Testing

### User Story 1 - A maintainer reads the helper's contract before calling it (Priority: P1)

A maintainer adding the next canonicalizing command opens
`path_canonicalizer.dart` to reuse it. The doc comment tells them, before they
write a line: the input MUST be absolute (absolutize first —
`p.normalize(p.absolute(...))` or join onto the absolute project root), why
(the walk-up resolves against the filesystem; a relative input silently joins
the process CWD and the result becomes CWD-dependent), and what the fallback
returns (the input unchanged, when no ancestor resolves — the loop's
defensive exit at the filesystem root).

**Why this priority**: the undocumented precondition is the live trap the
issue names first; documentation is the fix that cannot regress.

**Independent Test**: read `path_canonicalizer.dart` — the library doc and the
`canonicalizeMissingPath` doc name the absolute precondition, the CWD-join
failure mode for relative input, and the no-ancestor fallback.

**Acceptance Scenarios**:

1. **Given** the helper's doc comment, **When** a maintainer reads it,
   **Then** the absolute-input precondition, the relative-input CWD-join
   failure mode, and the input-unchanged fallback are each stated
   **Type**: acceptance
2. **Given** the documented contract, **When** all existing call sites are
   re-read, **Then** each one absolutizes before calling (the documented
   precondition matches reality — no call site contradicts the doc)
   **Type**: acceptance

### User Story 2 - The walk-up loop is pinned by a direct test (Priority: P1)

A future edit that breaks the walk-up loop — dropping `.reversed`, reordering
the tail, walking one segment too few — turns the new direct unit tests red
at the helper's own level, with a failure message naming the helper, instead
of surfacing (if at all) as a confusing inside/outside verdict flip in a
command-level fixture.

**Why this priority**: the issue's second gap; the test is what makes the
documentation trustworthy over time. Same priority as US1 because the two
together close the issue.

**Independent Test**: `dart test test/plugins/tdd/services/path_canonicalizer_test.dart`
passes on the current helper, and each test is shown to fail under its
corresponding deliberate mutant (mutation evidence recorded).

**Acceptance Scenarios**:

1. **Given** a temp root with a symlinked alias, **When** the nearest
   existing ancestor of a missing path resolves through the alias,
   **Then** the helper returns the SYMLINK-RESOLVED form plus the missing
   segments (never the raw alias form)
   **Type**: unit
2. **Given** a missing path two segments deep (`missing_a/missing_b/subject.dart`
   over an existing root), **When** the helper walks up,
   **Then** the missing segments are re-appended in ORIGINAL order —
   `.../missing_a/missing_b/subject.dart`, not a shuffled or
   reversed reordering (this is the assertion the command pins cannot make)
   **Type**: unit
3. **Given** a missing path whose DIRECT parent is an existing symlinked
   directory, **When** the helper resolves, **Then** the parent's symlink is
   resolved and the basename re-appended (the one-segment tail boundary)
   **Type**: unit
4. **Given** the walk-up reaching the filesystem root boundary (a missing
   path directly under the resolved temp root's top), **When** the loop
   resolves the root, **Then** the result is the resolved root plus the
   basename (the loop's normal exit), and the defensive
   no-ancestor-resolves fallback (input returned unchanged) is documented as
   the POSIX-unreachable branch it is — the root always resolves on the
   platforms this repo tests
   **Type**: unit

### Edge Cases

- What happens when the input is RELATIVE? Out of contract: documented as
  forbidden (silent CWD-join). NOT asserted at runtime — an `assert` would
  change observable behavior (debug-mode throw), violating the chore's
  "do NOT change the canonicalization logic or the view/wire command
  behavior" constraint.
- What happens when EVERY ancestor is missing (no ancestor resolves)? The
  loop's defensive exit returns the input unchanged. On POSIX the filesystem
  root always resolves, so the branch is unreachable through the public
  surface; it is documented as defensive, not faked with an injectable
  filesystem seam (a seam would restructure the helper — out of a chore's
  scope).
- What about an input whose parent IS the filesystem root (`/<missing>`)? The
  loop resolves the root on the first iteration and appends the basename —
  covered as the walk-up's boundary case.
- Windows: symlink-creating tests skip via the same
  `onPlatform: {'windows': Skip(...)}` convention the command pins use.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The shared helper's documentation MUST state that the input
  path MUST be absolute, and that a relative input silently joins the
  process current working directory (the documented failure mode)
- **FR-002**: The shared helper's documentation MUST state the fallback
  contract: when no ancestor resolves, the input is returned UNCHANGED
- **FR-003**: The helper MUST remain the ONLY implementation of missing-path
  canonicalization in the TDD plugin — view, wire, and func commands keep
  importing it; no private copy may return
- **FR-004**: A direct unit test file
  (`test/plugins/tdd/services/path_canonicalizer_test.dart`) MUST pin: the
  symlink-resolved nearest existing ancestor, the ORIGINAL-ORDER
  re-append of nested missing segments (the tail-order assertion), the
  one-segment boundary, and the root-boundary walk
- **FR-005**: The canonicalization LOGIC must not change: the walk-up
  algorithm, its symlink resolution, its fallback, and the view/wire/func
  command behavior stay semantically identical to master (994daeb1's shape)
  — executable lines unchanged; only doc comments may differ on the helper

## Layer Contracts

**Function**:
- `canonicalizeMissingPath`: `canonicalizeMissingPath(String path) -> Future<String>`
  (existing; documentation + tests only)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-1**: `path_canonicalizer.dart`'s doc comment names the absolute-input
  precondition, the relative-input CWD-join failure mode, and the
  input-unchanged fallback — verified by reading the file; no executable
  line of the helper changes (`git diff` touches comments only)
- **SC-2**: `test/plugins/tdd/services/path_canonicalizer_test.dart` exists
  and passes green on the current helper; the suite covers the four pinned
  behaviors (FR-004) with POSIX-safe temp fixtures under
  `Directory.systemTemp`
- **SC-3**: Test strength is EVIDENCED, not assumed: each pinned behavior has
  a recorded deliberate-mutant run (e.g. dropping `.reversed` from
  `tail.reversed`) where the new test goes RED against the mutant and GREEN
  after restore — recorded in `tdd/cycle-log.md`
- **SC-4**: The existing command pins stay green:
  `view_command_test.dart` (U-V3, U-V11/U-V12/U-V13, U-1603a/U-1603b) and
  `wire_command_test.dart` (U-W3, U-1603e) pass unchanged;
  `dart analyze` on the touched scope reports no issues; `dart format .`
  leaves zero diffs

## Hard constraints

- Extract + test + document ONLY. The canonicalization logic and the
  view/wire (and func) command behavior must remain unchanged — no
  `assert`, no absolutization inside the helper, no signature change, no
  filesystem-seam refactor.
- One PR per chore. `Closes #1610`.
- Windows-skipped symlink tests follow the repo's `onPlatform` convention.

## Out of scope

- Asserting or absolutizing inside the helper (behavior change — rejected
  above).
- A `@visibleForTesting` filesystem seam to make the no-ancestor fallback
  directly reachable (restructures the helper; the fallback is documented as
  defensive instead).
- Extracting or testing any other duplicated helper.
- Touching `func_command.dart` (it already imports the shared helper; its
  pins U-1603c/U-F5 are expected green and are run, not edited).
- Migrating the spec to `.specify/specs/` or renaming existing spec
  directories.
