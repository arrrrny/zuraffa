# Bug 1140 — Finder-kind taxonomy: scenario verbs map to assertion kinds, not just find.text

- **Issue**: https://github.com/arrrrny/zuraffa/issues/1140 ([TDD-138], part of EPIC 2: TDD Loop Completeness, extends #964, severity high)
- **Branch**: `fix/1140-finder-kind-taxonomy`
- **Records read as sole input**: the issue body (fetched live from the GitHub API; `.specify/bugs/1140-finder-kind-taxonomy/{issue,assessment}.md` did not exist in the repo — triaged against the brief + issue text only).

## Assessment (root cause)

Issue #964 (TDD-137) shipped the taxonomy itself — `finder_taxonomy.dart`
classifies scenario verbs into assertion classes, `BehaviorTestWriter`
emits verb-matched assertions, and `verify-red`'s kind gate
(`_certifyFinderKinds`, both the single and batch call sites) refuses a
red whose finder kinds do not match the scenario verbs. What #1140 asks
for is the CONTRACT wiring, and exactly one of its three wire-in points
was missing at the base commit (`c7cf331a`):

| #1140 wire-in | State at base | Evidence |
|---|---|---|
| `zfa tdd plan` outputs a "kind" column in the behavior table | **MISSING** | `plan_command.dart::_render` emitted `| id | behavior | traces | state |` for the widget section with no kind cell; `TestListReader` accepted only the 4-column shape (or the two deprecated 7-cell dialects) and a 5-data-column row was a malformed error |
| `zfa tdd gen` uses the kind to select the assertion template | present, but declarable | the writer re-derived the analysis from `b.description`; the plan's prediction was never persisted, so nothing bound gen to it and a hand-edited description silently generated assertions the plan never predicted |
| `verify-red` refuses a kind mismatch | present | `_certifyFinderKinds` at `verify_red_command.dart` call sites (single + batch) |

The residual risk class at base: plan → gen is an unverified handshake.
The plan "knew" (in the maintainer's head) what the scenario meant; the
test list recorded none of it; gen could never refuse a drifted row.

## Fix (this PR)

1. `finder_taxonomy.dart`: `predictedKinds` (derived class set + the
   sequence marker), `kindCellFor` (canonical-order comma-joined cell,
   `none` when no finder is derivable), `tryParseKindCell` (strict parse;
   null on unknown tokens so the reader can fail loudly).
2. `plan_command.dart::_render`: the widget behavior table emits
   `| id | behavior | kind | traces | state |` — derived from the same
   taxonomy the writer and the gate speak; acceptance/unit tables stay
   canonical 4-column; re-planning re-derives the cell (no accumulation).
3. `test_list_reader.dart`: `BehaviorRow.finderKinds` (null = no kind
   column — every legacy list; empty = declared `none`; non-empty =
   declared contract). `_parseDataRow` learns the 6-cell shape; a 6-cell
   row whose 4th cell is not a kind cell stays malformed naming the cell.
4. `models/behavior.dart`: `Behavior.finderKinds` carries the declared
   kinds through gen (including the `--kind` override path).
5. `gen_command.dart::_generate`: WIDGET rows with a declared kind cell
   are reconciled against `FinderTaxonomy.predictedKinds(description)`;
   drift refuses with the declared/derived cells + a `--> fix:` line
   BEFORE any artifact write (FR-002). Legacy rows keep the derive-only
   behavior.

verify-red needs no change: the kind gate now certifies a red generated
through the declared-kind chain (pinned end-to-end in the red suite's
`plan kind → gen template → certified red`).

## Verification

See `tdd/verification.md` in this directory — real command outputs, this
session: red → green evidence, mutant kill, whole-repo gates.
