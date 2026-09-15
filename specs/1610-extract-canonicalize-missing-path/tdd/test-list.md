---
feature: 1610-extract-canonicalize-missing-path
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: f220b6a3
updated_at: bbb497d1
suite_baseline: green
---

# Test List: Extract canonicalizeMissingPath — documented precondition + direct walk-up test (chore #1610)

Derivation source: `spec.md` (US1/US2 acceptance scenarios + FR-001..FR-005,
SC-1..SC-4) and `tasks.md` (T001 behaviors U1–U4, T001m mutants M1–M3).
The helper predates the contract registry (no declared contract rows for
`path_canonicalizer`), so unit-lane routes use the labeled legacy fallback.

The behavior under test is the shared walk-up loop in
`lib/src/plugins/tdd/services/path_canonicalizer.dart` — which ancestor it
resolves, what it re-appends, and in WHAT ORDER — plus (non-test) the doc
comment that states its absolute-input precondition. The loop is
inside-out: this is a pure filesystem utility with no user-visible surface
of its own. All unit behaviors are fast-tier temp-fixture tests; symlink
scenarios skip on Windows per the repo's `onPlatform` convention.

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`. This chore's acceptance surface is
asserted THROUGH the inner-loop pins below (A1–A2 are read/diff audits, not
suite runs; A3–A6 are the U1–U4 pins and the pin-regression gate).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | The helper's doc comment names the absolute-input precondition, the relative-input CWD-join failure mode, and the input-unchanged fallback (US1/AC-1; FR-001, FR-002). | SC-1 | PENDING |
| A2 | Every call site (view/wire/func) absolutizes before calling — the documented precondition matches reality (US1/AC-2). | SC-1 | PENDING |
| A3 | Symlink-resolved nearest existing ancestor: missing path over an aliased root returns the RESOLVED root form plus the missing segments (US2/AC-1). | SC-2 | PENDING |
| A4 | Tail-order pin: nested missing segments re-appended in ORIGINAL order; exact-match assertion fails under the dropped-`.reversed` mutant (US2/AC-2). | SC-2, SC-3 | PENDING |
| A5 | One-segment boundary: existing symlinked direct parent resolves, basename re-appended (US2/AC-3). | SC-2 | PENDING |
| A6 | Root-boundary walk + defensive fallback documented as POSIX-unreachable; existing view/wire/func command pins stay green with zero command diffs (US2/AC-4; FR-003, FR-005). | SC-2, SC-4 | PENDING |

## Outer loop: widget behaviors

Not applicable — no UI surface in this chore.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/path_canonicalizer.dart`

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| U1 | A missing path whose nearest EXISTING ancestor is reached through a symlink alias resolves to the SYMLINK-RESOLVED ancestor form plus the re-appended missing segments — never the raw alias form (asserts A3). | SC-2, FR-004 | example | PENDING | `test/plugins/tdd/services/path_canonicalizer_test.dart::resolves the nearest existing ancestor through a symlinked root and re-appends the missing segments` |
| U2 | A missing path TWO segments deep (`missing_a/missing_b/subject.dart` over an existing root) re-appends the missing segments in ORIGINAL order — the exact-match assertion that FAILS if `tail.reversed` is dropped (the distinguishing power the command pins lack; asserts A4). | SC-2, SC-3, FR-004 | example | PENDING | `test/plugins/tdd/services/path_canonicalizer_test.dart::re-appends nested missing segments in original order (tail order)` |
| U3 | A missing path whose DIRECT parent is an existing symlinked DIRECTORY resolves the parent's symlink and re-appends exactly the basename (one-segment tail boundary; asserts A5). | SC-2, FR-004 | example | PENDING | `test/plugins/tdd/services/path_canonicalizer_test.dart::resolves a symlinked direct parent and re-appends the basename` |
| U4 | A missing path directly under the root (`<alias>/<missing>` where the alias resolves to the root) resolves to `<resolvedRoot>/<missing>` — the walk-up loop's NORMAL exit at the filesystem-root boundary; the no-ancestor fallback (input unchanged) is documented, NOT unit-hosted (defensive branch, POSIX-unreachable, no fake seam per the hard constraint; asserts A6's first half). | SC-2, FR-004, FR-002 | example | PENDING | `test/plugins/tdd/services/path_canonicalizer_test.dart::walks zero ancestors for a path directly under the root` |
| U5 | Mutation strength (T001m): each deliberate mutant is applied → targeted run → restored byte-identical (mutant states never committed); see the mutant matrix below. | FR-005, SC-3 | example | PENDING | `deliberate-mutant runs recorded in tdd/cycle-log.md` |
| U6 | Gate aggregation (T002/T004): new suite green; view pins (U-V3, U-V11/U-V12/U-V13, U-1603a/b), wire pins (U-W3, U-1603e), func pins (U-1603c, U-F5) green; `dart analyze` clean on touched scope; `dart format .` zero diffs; `git diff` shows no executable-line change on the helper (asserts A6's second half). | FR-003, FR-005, SC-4 | example | PENDING | `dart test --preset=all test/plugins/tdd/commands/view_command_test.dart test/plugins/tdd/wire_command_test.dart` + `dart test test/plugins/tdd/commands/func_command_test.dart` |

### Deliberate-mutant matrix (U5 / SC-3)

The behaviors already exist on master (994daeb1) — every U-behavior above is
green the moment it is written, so red evidence comes from the sanctioned
deliberate-mutant procedure (tdd-profile: "Mutation tool: none wired ...
falls back to deliberate-mutant sampling").

| mutant id | mutant (in `path_canonicalizer.dart`) | must go RED | restored GREEN |
| --- | --- | --- | --- |
| M1 | drop `.reversed`: `...tail.reversed` → `...tail` | U2 | U1, U3, U4 |
| M2 | skip the walk-up: return `path` on the first `FileSystemException` | U1, U2 | U3, U4 |
| M3 | drop the basename re-append: `joinAll([resolved])` | U1, U2, U3, U4 | — |

## Run-verified regression pins (characterization, NOT edited)

| id | behavior | traces | kind | state | test |
| --- | --- | --- | --- | --- | --- |
| P1 | view pins stay green: U-V3, U-V11/U-V12/U-V13, U-1603a/U-1603b (and the rest of the file) | SC-4, A6 | characterization | PENDING | `dart test --preset=all test/plugins/tdd/commands/view_command_test.dart` |
| P2 | wire pins stay green: U-W3, U-1603e (and the rest of the file) | SC-4, A6 | characterization | PENDING | `dart test --preset=all test/plugins/tdd/wire_command_test.dart` |
| P3 | func (third consumer) stays green: U-1603c, U-F5 and file | SC-4, A6 | characterization | PENDING | `dart test test/plugins/tdd/commands/func_command_test.dart` |

## Documentation behavior (non-test, US1/FR-001/FR-002/SC-1)

| id | behavior | traces | verified by |
| --- | --- | --- | --- |
| D1 | The helper's doc comment names: (a) the ABSOLUTE-input precondition, (b) the relative-input silent CWD-join failure mode, (c) the input-UNCHANGED no-ancestor fallback (asserts A1; A2's call-site re-read is T003's CALL-SITE RE-CHECK) | SC-1, FR-001, FR-002 | T003 read-through + comments-only `git diff` check (no executable change — FR-005) |

## Routing provenance

route: A1 -> acceptance lane [fallback: docs audit — no suite run; verified by file read + git diff in T003/T004]
route: A2 -> acceptance lane [fallback: call-site re-read audit — verified in T003 CALL-SITE RE-CHECK]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — asserted by U1 at the helper level]
route: A4 -> acceptance lane [fallback: legacy description classifier matched — asserted by U2 at the helper level]
route: A5 -> acceptance lane [fallback: legacy description classifier matched — asserted by U3 at the helper level]
route: A6 -> acceptance lane [fallback: legacy description classifier matched — asserted by U4 + U6/P1-P3 gates]

## Invariants and edge cases still to place

- The no-ancestor-resolves fallback (`parent.path == dir.path` → return
  `path`) is DEFENSIVE and unreachable through the public surface on POSIX:
  the filesystem root always resolves, so the loop exits normally at the
  root. Pinned as documented contract (D1c) + the U4 root-boundary
  behavior; NOT unit-hosted (a filesystem seam would restructure the
  helper — forbidden by the chore's constraint).
- Relative input is OUT OF CONTRACT (documented failure mode: silent
  CWD-join). Deliberately not asserted at runtime and not pinned by a test
  that would freeze the CWD-join misbehavior as API.
- Windows: U1/U3 create symlinks → `onPlatform: {'windows': Skip(...)}`,
  matching U-1603a's convention.

## Out of scope

- Asserting or absolutizing inside the helper: behavior change, forbidden
  by the chore constraint (spec Out-of-scope).
- A `@visibleForTesting` filesystem seam: restructures the helper for a
  POSIX-unreachable branch (spec Out-of-scope).
- func_command.dart edits: already imports the shared helper (spec
  Out-of-scope; P3 runs it read-only).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time
(adjusted for the tier reality discovered at baseline: the view/wire pin
suites carry `@Tags(['slow'])` and run ZERO tests under the default preset —
they require `--preset=all`; func is fast-tier and runs bare):

- Single test: `dart test <file> --plain-name "<name>"`
- New unit pins: `dart test test/plugins/tdd/services/path_canonicalizer_test.dart`
- Pin suites (slow tier): `dart test --preset=all test/plugins/tdd/commands/view_command_test.dart test/plugins/tdd/wire_command_test.dart`
- Third consumer (fast tier): `dart test test/plugins/tdd/commands/func_command_test.dart`
- Static analysis (scope): `dart analyze lib/src/plugins/tdd/services/ test/plugins/tdd/services/`
- Format gate: `dart format --output=none --set-exit-if-changed lib/src/plugins/tdd/services/ test/plugins/tdd/services/`
- Full suite: `dart test` — do NOT run for feature work (tdd-profile);
  scoped subsets above are the contract
