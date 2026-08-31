---
feature: slice-depth-view-includes-presenter
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 11de4bfc
behaviors: 4
proven: 1
likely: 0
test_after: 0
no_test: 0
baseline: 3 # A1, A2, U2 — characterization pins of already-correct or pre-existing behavior
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 2/2 # deliberate mutants only — no mutation tool in the profile; scope: classifyLayer + view tier
mutants_survived: 0
suite: depth+classification files 14/14; chunked fast suite 61 chunks green incl. test/plugins/slice 82/0; 5 chunks exit-79 no-tests-selected (pre-existing, proven on pristine base); dart analyze 0 issues; dart format 1350 files 0 changed
---

# TDD Verification: `zfa slice cut --depth view` mirrors the presenter layer (#597)

**Verdict: PASS_WITH_GAPS.** The residual gap this branch can still prove —
the depth filter classifying a presenter outside `pages/` as
`presentation_shared`, which `--depth view` mirrors — went red→green with a
recorded red, and the #597 regression itself is re-provably caught by the
committed A13 test (deliberate mutant 2). The gap that forces the verdict:
the bug record's original failing state does NOT reproduce at HEAD
`11de4bfc` — the assessment's remediation is already merged (PR #595 landed
~30 min before the issue was filed) — so the original bug's evidence is a
baseline characterization, not a PROVEN red→green produced by this branch.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| U1 — presenter anywhere under presentation/ classifies `presenter` | PROVEN | cycle-log Cycle 1 records the red command and output (`Expected: 'presenter' / Actual: 'presentation_shared'`); test + fix land in one commit per repo convention, and the rubric's PROVEN requires exactly the recorded red |
| A1 — `--depth view` excludes the presenter (canonical pages/ layout) | NOT_APPLICABLE (BASELINE) | A13 (T099) is pre-existing and green at baseline; the guard it asserts landed in #595; cannot be re-driven red from this branch without reverting a merged fix |
| A2 — `--depth presentation` includes the presenter, domain out, usecases mocked | NOT_APPLICABLE (BASELINE) | new A13b test; tier had zero coverage before; passed on first run after manual-cut corroboration (cycle-log Cycle 2) |
| U2 — four-tier `layerAllowedAtDepth` table pinned | NOT_APPLICABLE (BASELINE) | new unit tests; all assertions held at HEAD (the table was already spec-correct) |

No pre-existing test was weakened: `slice_depth_test.dart` only GAINED a test;
`file_graph_test.dart` is new; no assertion was removed, loosened, renamed
away from a filter, or skipped; no config threshold changed.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | The bug record was stale on arrival: the issue (07:37 UTC) was filed after the fix-bearing PR #595 merged (07:03 UTC), so the tracker described an already-fixed defect. This report and the PR body close that loop explicitly. | `.specify/bugs/slice-depth-view-includes-presenter/assessment.md`; `git log d964801d` |
| 2 | MED | Presenter detection remains file-name based (`basename` contains `presenter`); a presenter class in a file named e.g. `product_vm.dart` is still misclassified as view/shared. Path-based classification is the spec 043 design; recorded as a design boundary, not fixed here. | `lib/src/plugins/slice/models/file_graph.dart` `classifyLayer` |
| 3 | MED | `tools/run_tests_chunked.sh` silently stops after `test/plugins/mcp` (its per-chunk `dart test` consumes the chunk-list stdin) and reports exit-79 "failure" for 5 slow/flutter-only folders — the FAIL is a runner quirk, pre-existing on the pristine base. | cycle-log Notes; `git stash` re-run: exit 79 at `test/property` on pristine HEAD |
| 4 | LOW | Generated `slice_di.dart` duplicates mock-import lines when several boundaries resolve to the same mock file (observed at presentation depth). Cosmetic; out of scope for the depth filter. | manual repro sandbox, pres_tier slice_di.dart |

## Mutation results

No mutation tool in the profile; deliberate mutants per the rubric, sampled on
the depth filter (the only changed logic) — 2 behaviors sampled, both caught:

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| remove the presenter basename branch from `classifyLayer` | U1 | No | U1's test failed with the exact pre-fix signature; restore verified green |
| add `'presenter'` to the view tier in `layerAllowedAtDepth` (re-introduces #597) | A1 | No | committed A13 (T099) failed — the original regression is still guarded |

Both mutants restored exactly; post-restore suite green (`+9: All tests
passed!`).

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| Issue #597 acceptance: `--depth view` excludes the presenter layer, view/controller/state (+widgets/mocks/slice_di) included | `A13 (T099)`, `U1`, `U2` | Yes — A13 drives the real `SliceCommand` against a fixture project |
| Assessment: other depth tiers still include the presenter when appropriate | `A14 (T100)` (feature), `A15 (T101)` (full), `A13b` (presentation), `U2` | Yes — real cuts per tier |
| Assessment: retain `mock_product_presenter.dart` + its `slice_di.dart` binding at view depth | `A13 (T099)` `contains` assertions | Yes |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- **The original red is not reproducible from this branch.** Proving the
  pre-#595 state red would mean reverting merged code; rejected as
  history-rewriting. A1's evidence is therefore baseline + the deliberate
  mutant that re-introduces the regression and shows A13 catches it.
- **Audit independence**: the same session wrote the tests and ran this
  audit (Hard Rule 2 disclosure). The smell pass was performed by re-reading
  every new/changed test file cold; no fresh-context subagent was used.
- **Mutation scope**: 2 hand-written mutants on the changed filter only; not
  an exhaustive mutation run; no coverage tooling run.
- **Slow tiers**: the depth acceptance file runs its slow-tagged tests via
  `--preset=all` scoped to the two files; the repo-wide
  regression/integration/property/benchmark presets were NOT run (disk-unsafe
  on this agent per dart_test.yaml; the fast chunked suite ran instead).
- **Runner fixes**: `run_tests_chunked.sh` stdin/std-exit-79 quirks are
  reported (finding 3), not fixed — out of this bug's blast radius.
- **`dart analyze`**: 0 issues on the full repo at the audited tree;
  formatting gate clean (`dart format .` → 1350 files, 0 changed).
