# Test List: 1610-extract-canonicalize-missing-path

Derivation source: `spec.md` (US1/US2 acceptance scenarios + FR-001..FR-005,
SC-1..SC-4) and `tasks.md` (T001 behaviors U1–U4, T001m mutants M1–M3).
The helper predates the contract registry (no declared contract rows for
`path_canonicalizer`), so unit-lane routes use the labeled legacy fallback.

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

One per pinned helper behavior (tasks.md T001) plus the mutation-strength
row (T001m) and the gate-aggregation row (T002/T004).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | Nearest existing ancestor resolves through a SYMLINK: fixture root aliased by a symlink; missing subject `<alias>/missing/subject.dart` → result starts with the RESOLVED root, never the alias form; segments re-appended. | FR-004, SC-2 | PENDING |
| U2 | Tail-order assertion the command pins cannot make: `root/missing_a/missing_b/subject.dart` (both middle segments missing) → EXACTLY `<resolvedRoot>/missing_a/missing_b/subject.dart` — dropping `.reversed` yields `.../subject.dart/missing_b/missing_a` and FAILS. | FR-004, SC-2 | PENDING |
| U3 | One-segment boundary: direct parent exists and is a symlinked directory → parent's symlink resolved, basename re-appended. | FR-004, SC-2 | PENDING |
| U4 | Root-boundary walk: missing path directly under the resolved root → resolved root + basename; the no-ancestor fallback (input unchanged) asserted UNTESTABLE-BY-PUBLIC-SURFACE in a comment (defensive branch; POSIX root always resolves — no fake seam per the hard constraint). | FR-004, FR-002, SC-2 | PENDING |
| U5 | Mutation strength (T001m): M1 (drop `.reversed`) kills U2; M2 (skip walk-up — return `path` on first FileSystemException) kills U1+U2; M3 (drop the basename re-append) kills U1+U2+U3; each restore returns the suite to GREEN; mutant states never committed. | FR-005, SC-3 | PENDING |
| U6 | Gate aggregation (T002/T004): new suite green; view_command_test.dart (U-V3, U-V11/U-V12/U-V13, U-1603a/b), wire_command_test.dart (U-W3, U-1603e), func_command_test.dart (U-1603c, U-F5) green; `dart analyze` clean on touched scope; `dart format .` zero diffs; `git diff` shows no executable-line change. | FR-003, FR-005, SC-4 | PENDING |

## Routing provenance

route: A1 -> acceptance lane [fallback: docs audit — no suite run; verified by file read + git diff in T003/T004]
route: A2 -> acceptance lane [fallback: call-site re-read audit — verified in T003 CALL-SITE RE-CHECK]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — asserted by U1 at the helper level]
route: A4 -> acceptance lane [fallback: legacy description classifier matched — asserted by U2 + killed mutant M1]
route: A5 -> acceptance lane [fallback: legacy description classifier matched — asserted by U3]
route: A6 -> acceptance lane [fallback: legacy description classifier matched — asserted by U4 + U6 pin regression]
route: U1 -> unit lane [fallback: legacy description classifier matched — no declared contract row for path_canonicalizer]
route: U2 -> unit lane [fallback: legacy description classifier matched — no declared contract row for path_canonicalizer]
route: U3 -> unit lane [fallback: legacy description classifier matched — no declared contract row for path_canonicalizer]
route: U4 -> unit lane [fallback: legacy description classifier matched — no declared contract row for path_canonicalizer]
route: U5 -> unit lane [fallback: mutation-sampling evidence, not a suite run]
route: U6 -> unit lane [fallback: gate aggregation, not a suite run]
