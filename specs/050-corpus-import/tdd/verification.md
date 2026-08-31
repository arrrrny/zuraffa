---
feature: 050-corpus-import
verdict: FAIL
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: f7e42e46 # short SHA audited
behaviors: 28
proven: 22
likely: 0
test_after: 6
no_test: 0
high_smells: 1
criteria_total: 8
criteria_covered: 8
mutation_score: 11/12 # deliberate mutants only (no mutation tool in profile); scope: this feature's changed files
mutants_survived: 1 # M1 — the --dry-run CLI wiring hole; triaged below
suite: 86 passed, 0 failed, ~6s # dart test test/cli/services/ test/commands/ test/core/project/
---

# TDD Verification: `zfa corpus import` (+ `zfa setup --specs`)

**Verdict: FAIL.** Six behaviors were verified only by deliberate mutants
(no recorded red — their implementations landed as byproducts of earlier
cycles before their dedicated tests existed), one acceptance test
asserts nothing, and one deliberate mutant survived inside a DONE
behavior. The audit was run by the same session that wrote the tests;
every file was re-read cold, the smell pass was delegated to a
fresh-context subagent and its findings vetted line-by-line, and the
disclaimer stands: this is not an independent audit.

## Test-first evidence

Baseline: fast tier 53/53 green at `bd90a04f` (merge base + master),
`dart analyze` 0 issues — recorded in the cycle log before cycle 1.

| Behavior | Class      | Evidence |
| -------- | ---------- | -------- |
| A1-A3    | PROVEN     | cycles 1-3 reds (`Expected: true / Actual: <false>` + the no-command CLI error); closed green at cycle 17; tests + source in `5efc0385` |
| A4-A6    | PROVEN     | cycles 18-20 reds (`❌ Error: UnimplementedError` on the deliberate existing-target stub); green after cycles 21-23; `cac9c108` |
| U1-U3    | PROVEN     | cycles 4-6 reds (compile error → stub → `UnimplementedError`, then order-assertion failure); `10efaf83` |
| U4       | TEST_AFTER | cycle 7: immediate pass (behavior was a byproduct of U3's `read`); deliberate mutant caught; no red exists |
| U5-U10   | PROVEN     | cycles 8-10 reds (`UnimplementedError` / empty-scan / missing-tdd assertion); `10efaf83`, `5efc0385` |
| U12, U13, U15 | PROVEN | cycles 11-13 reds (fake-mark disagreement, foreign flag unset, `UnimplementedError`); `5efc0385` |
| U11      | TEST_AFTER | cycle 24: immediate pass; mutant (tdd/ marker write) caught; no red |
| U14      | TEST_AFTER | cycle 25: immediate pass; mutant (manifest dry-run guard dropped) caught; no red |
| U16-U18  | PROVEN     | cycles 14-16 reds (stub family: no flags, no usage error, no help line); `5efc0385` |
| U19      | PROVEN     | cycle 29 red (`Actual: <-1>` — no `[6/8]` step; `❌ Could not find an option named "--specs"`); `f7e42e46` |
| U20      | TEST_AFTER | cycle 30: immediate pass (the "unchanged" behavior); mutant (unguarded import step) caught; no red |
| A7, A8   | TEST_AFTER | cycles 26-27: immediate passes (marks driven by US1's close); mutants (reason dropped; mark inverted) caught; no reds |

History check: no existing test was weakened — `git diff --name-only
bd90a04f..HEAD -- test/` shows only NEW feature test files; the one
existing assertion in the blast radius (`test/integration/
day_zero_smoke_gate_test.dart:61` asserts `Setup complete!`) still
holds (step labels are byte-identical without `--specs`).

## Findings

Ordered by severity. Findings 1-4 were surfaced by the fresh-context
subagent and vetted line-by-line; finding 1 and the M1 survivor were
independently confirmed by the auditor's own runs.

| #  | Severity | Finding | Evidence |
| -- | -------- | ------- | -------- |
| 1  | HIGH | U5's "accepts a corpus root" asserts nothing — the body is `await runImport();`; it proves only "did not throw" | `test/cli/services/corpus_importer_test.dart:450-452` |
| 2  | HIGH | The `--dry-run` flag is never driven through the real CLI: a deliberate mutant hardcoding `dryRun: false` in the command SURVIVES the whole 86-test suite (U14 tests the importer parameter; setup's `--dry-run` is separate wiring). Surviving mutant inside DONE behavior U16 | `lib/src/commands/corpus_command.dart:97` (mutant site); `test/commands/corpus_command_test.dart` (no `importCorpus(dryRun: true)` call anywhere) |
| 3  | MED | A2 bundles three behaviors (plan-succeeds / refuse-no-list / parser-reason parity) in one test — three failure modes, one signal | `test/commands/corpus_command_test.dart:351-430` |
| 4  | MED | A2's refusal output is never asserted to carry the reason (only `❌`); the in-test `SpecParser` re-invocation pins the 041 plugin's parser, not this feature's CLI surface | `test/commands/corpus_command_test.dart:419-427` |
| 5  | MED | A6 bundles default-keep and `--force` replace in one test (two independently assertable halves) | `test/commands/corpus_command_test.dart:213-249` |
| 6  | MED | T013's `s-full`/`s-noscen` shapes re-pin what U12's test already pins at the same level; only `s-nofrs`/`s-malformed` are novel | `test/cli/services/corpus_importer_test.dart:385-394` |
| 7  | MED | A1-A8 acceptance tests live inline in the command unit-test file; the repo's shape for that tier is `scenarios/sc_<NNN>_<slug>_test.dart` (tasks.md T019-T021 directed corpus_command_test.dart — recorded, not silently corrected) | `test/commands/corpus_command_test.dart` |
| 8  | MED | "a dry-run after a real import writes nothing new" asserts `reportLines isNotEmpty` — cannot fail (`_scanFeatures` throws on empty corpora); the checksum equality is the real assertion | `test/cli/services/corpus_importer_test.dart:268` |
| 9  | MED | `--dry-run`/`--force`/`--project` and `--specs` option-registration tests assert wiring, not behavior (all but `--dry-run` are behaviorally covered elsewhere — see finding 2) | `test/commands/corpus_command_test.dart:67-73`, `test/commands/setup_corpus_specs_test.dart:69-72` |
| 10 | LOW | The recursive sha256 checksum closure is hand-rolled three times across two files; the manifest path is rebuilt in three places | `corpus_importer_test.dart:255-263,290-296`, `corpus_command_test.dart:194-200` |
| 11 | LOW | U3's locals invert the write order (`raw1` holds the second write's bytes); the equality assertion is sound but the names mislead | `test/core/project/corpus_manifest_test.dart:104-108` |

Suite properties (subagent judgment, vetted): isolation excellent
(fresh fixtures per test, `addTearDown` cleanup), deterministic and
fast (~1s per file, no clock/random/network assertions — the source's
`DateTime.now()` for `imported_at` never surfaces in an assertion),
failure specificity strong (exact-equality matchers + `reason:` output
dumps + behavior-id group names), refactoring-insensitivity good
(files-on-disk / manifest JSON / captured output; the pinned
report/summary strings are contract pins, checked against
contracts/corpus-import.md). Zero doubles in the whole suite.

## Mutation results

No mutation tool is wired in the profile (tdd-profile.md: "Mutation
tool: none wired in CI"), so both the in-loop checks and this audit
used deliberate mutants on the changed files. Sampled behaviors and
results — 12 mutants total, 11 caught, 1 survived:

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| In-loop: `read` throws on missing manifest | U4 | No | Caught by U4 |
| In-loop: import writes `tdd/marker.txt` | U11 | No | Caught by U11 + 9 others |
| In-loop: manifest write ignores dry-run | U14 | No | Caught by U14 |
| In-loop: manifest emission drops reason | A7 | No | Caught by A7 |
| In-loop: manifest `ready` mark inverted | A8 | No | Caught by A8 |
| In-loop: `_readiness` always ready | T013/U12 | No | Caught by the parity test |
| In-loop: setup import step unguarded | U20 | No | Caught by U20 |
| Audit M1: command hardcodes `dryRun: false` | U16 | **YES** | Real hole — `--dry-run` never driven through the CLI; finding 2, remediation task R2 |
| Audit M2: manifest sort dropped | U2/A1 | No | Order assertions fail |
| Audit M3: skip comparison inverted | U7/U8/A4/A6 | No | 6 failures |
| Audit M4: report print dropped | A3/A4/A6 | No | Report-line assertions fail |
| Audit M5 (paper, subagent): summary-only refusal | — | noted | Covered by finding 4's analysis |

Every surviving mutant was restored and verified against the full
feature suite (86/86 green after each restore; git tree clean).

## Traceability

| Criterion | Tests | End to end (real CLI) |
| --------- | ----- | --------------------- |
| US1.AC1 (import + manifest deterministic) | A1, U1-U4, U6, U10, U18 | Yes — `corpus import` through `CliRunner.runCapturing` |
| US1.AC2 (plannable, zero manual edits) | A2, U12 | Yes — real `zfa tdd plan` on the imported feature |
| US1.AC3 (not-ready imported AND reported) | A3, U12, U15 | Yes |
| US2.AC1 (growth re-import touches only new) | A4, U7 | Yes |
| US2.AC2 (tdd/ byte-identical) | A5, U11 | Yes |
| US2.AC3 (divergent kept + hashes; --force) | A6, U8, U9 | Yes |
| US3.AC1 (marks ready/not-ready + reason) | A7, U12, T013 | Yes |
| US3.AC2 (consumer relies on manifest mark) | A8 | Yes |
| FR-001..FR-007 | U5-U19 (see test list `traces` column) | FR-001 end-to-end; FR-002..FR-007 at the owning level + acceptance coverage |

Untested criteria: none. Tests tracing to nothing: none (every `traces`
value resolves to a criterion in spec.md; the quickstart scenarios 1-5
were additionally executed verbatim with the real CLI — cycle-log
cycle 31).

## What was not audited

- Mutation was deliberate-mutant sampling (12 mutants on this feature's
  changed files), not a tool-scored run over every changed line — the
  profile wires no mutation tool. The sample is not exhaustive.
- The slow/integration tiers (including `test/integration/
  day_zero_smoke_gate_test.dart`, which drives real `setup`) were not
  run: they require the Flutter SDK, which is not installed in this
  environment. The fast tier (86 tests, the feature scope) is green.
- `zfa setup --specs`'s real-write (non-dry-run) path is exercised only
  indirectly via the shared importer's coverage; the fast-tier setup
  test drives dry-run only.
- Exit codes are approximated in-process (`exitOnCompletion: false`
  never exits); the real exit code was observed once per quickstart
  scenario (cycle 31) but is not asserted in a test.
- The audit was performed by the session that wrote the tests (with a
  fresh-context subagent for the smell pass, its findings vetted
  line-by-line). It is not an independent audit.
