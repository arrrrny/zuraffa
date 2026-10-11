---
feature: 0967-spec-mutation-arena
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 0967-spec-mutation-arena@working-tree
engine_gate: not_assessed # no gen artifacts registered for this feature's dir — self-hosting lane, hand-authored tests (same as 1007/1008; see Engine gate)
behaviors: 12
proven: 12
pinned: 0
likely: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: n/a # deliberate-mutant sampling below (the oracle itself IS the mutation machinery; demo: weak 6/6 survived as designed, strong 13/13 killed)
mutants_survived: 0
suite: chunked fast tier 82 chunks — 77 green, 4 designed skips, 1 red chunk (test/plugins/cache: 2 failures reproduced IDENTICAL on clean master via stash re-run — pre-existing, not this feature); test/commands root +206 -2 (2 failures pre-existing, proven identical on master); test/plugins/tdd root failing list byte-identical to master (comm diff = 0); new suites: spec_mutator +25, spec_fuzz_auditor +11, spec_fuzz_command +12 (fast tier), spec_fuzz_demo +2 (integration, REAL dart test spawns); dart analyze = 333 issues, EXACTLY the master baseline (diff vs baseline = empty); dart format . = 0 changed
---

# TDD Verification: `0967-spec-mutation-arena`

**Verdict: PASS** — every behavior of the arena is PROVEN red-first: the
feature was reproduced as failing output FIRST (the CLI repro + the four
red test suites, captured in `tdd/cycle-log.md`), then implemented, then
pinned by tests in the same change. All three acceptance criteria are
PROVED by executed commands with captured output, not recited from
memory. Zero HIGH test smells; the whole-repo gates are green at the
exact master baseline.

Audit run by the same session that wrote the tests (stated per the
rubric's honesty rule): the red evidence below is the captured output of
the runs performed by this session, before the implementation landed.

## Engine gate (stated honestly)

`zfa tdd verify --feature 0967-spec-mutation-arena` is `not_assessed`
(no gen'd artifact registry for this feature directory): this feature is
SELF-HOSTING — its subject IS the loop's own spec machinery, tested
through hand-authored suites under `test/plugins/tdd/` plus a
real-`dart test` demo (the spec-046 scenario convention), exactly like
1007 and 1008 before it. The engine's mutation audit only assesses gen'd
registries; mutation strength was executed as deliberate-mutant sampling
(below) AND by the feature's own oracle end to end (the seeded weakness
demo runs REAL `dart test` processes per mutant).

## RED evidence (captured before the implementation)

From `tdd/cycle-log.md` (all captured this session):

| Repro | Pre-fix output (captured) |
| ----- | ------------------------ |
| `dart run bin/zfa.dart spec fuzz 0967-spec-mutation-arena` | `❌ Could not find a command named "spec".` — exit **64** |
| `dart run bin/zfa.dart spec --help` | same refusal, exit 64 |
| `spec_mutator_test.dart` | `Error: Method not found: 'validateSpecContract'` — loading failure, 0 tests ran |
| `spec_fuzz_auditor_test.dart` | `Error when reading 'lib/src/plugins/tdd/models/spec_mutation.dart': No such file or directory` |
| `spec_fuzz_command_test.dart` | `Actual: '❌ Could not find a command named "spec".\n'` on every registration + usage test |
| `spec_fuzz_demo_test.dart` | missing-module loading failure, 0 tests ran |

## Exit criteria — PROVED vs not

| Exit criterion (issue #967) | Status | Evidence (executed this session) |
| -------------- | ------ | -------------------------------- |
| Seeded weakness demo: a deliberately weak spec for a toy feature survives the green loop; spec fuzz flags it; the strengthened spec kills all mutants | **PROVED** | `bash tools/spec_fuzz_demo.sh` (REAL `dart test` spawns, no injection): weak feature first goes green through the real loop (`dart test` exit 0), the fuzz round flags it — `survived=6`, exit 1, `certified=false`, weakness report written, 6 `severity: contract` gap-ledger entries, spec.md restored byte-exactly; the strengthened spec over the SAME implementation kills every mutant — `survived=0`, exit 0, `certified=true`; deterministic replay reproduces `spec-fuzz.json` byte-identically. The same scenario is pinned twice: `spec_fuzz_demo_test.dart` (integration tier, +2) and the CI job |
| Reports are deterministic given a seed (replay-compatible) | **PROVED** | weak and strong rounds run twice with the same seed → byte-identical `spec-fuzz.json` (asserted in the demo test AND in the CI script's diff check); `SpecMutator.select` is a stable seeded shuffle; report bodies carry no timestamps/wall-clock; `spec_mutator_test.dart` pins: seed 0 = document-order prefix, nonzero seed = identical subset across runs, ids stable across operator filters |
| Runs corpus-wide against the existing baseline infrastructure (#953) | **PROVED** | `zfa spec fuzz --corpus <target>` iterates `requireCatalog` (the #953/#1016 surface) under one global mutant budget with the never-stop discipline, writes per-feature reports, persists round state to `.zfa/corpus/spec-fuzz/<target>.json`, prints `spec-fuzz: corpus=... features=... certified=... failed=... result=ok|over-budget`; a missing catalog exits 2 with the `--> fix: zfa corpus catalog --target ...` recovery line; the two-feature corpus demo (weak + strong) exits 1 on the weak feature (+2 integration test) |
| Output: machine-readable weakness report `{mutation_id, spec_line, operator, verdict, evidence}`; exit nonzero when survived > 0 | **PROVED** | `spec-fuzz.json` rows carry exactly those keys (pinned by the auditor test's shape group); the machine line `spec-fuzz: feature=... mutations=... killed=... survived=... not_assessed=... budget=... seed=... fuzz_was_run=... certified=...` is the CI contract; exit 1 on survivors, 0 on all-killed — pinned in the command tests, the auditor tests, the demo test, and the CI script |
| Ledger integration: survived mutations are ledger gaps; CI gate blocks certified | **PROVED** | each survivor appends one deduplicated `GapLedgerEntry` (kind gap, `severity: contract`, `outcome: survived`, `expected_result: pass`, `behavior: <mutation_id>`); re-running the round appends nothing new (dedupe pinned); `--no-ledger` never touches the ledger (pinned); the referee's `GoldenWorkflow.result` already flips to `gaps` on open ledger gaps, so contract-severity survivors block the production verdict; the new `spec_fuzz` CI job (ci.yaml) runs the demo fail-on-should-be-red — a survived mutant on the strong spec FAILS the job |
| Operators declared per contract element (not free-text edits), deterministic and replayable | **PROVED** | `spec_mutator_test.dart` (+25): weaken targets Then clauses carrying specifics; drop targets edge-vocabulary scenarios only; swap-literal covers quoted/backticked/route/key/number tokens with per-occurrence candidates; widen covers `N..M` ranges and `at most/at least` bounds; drop-must-not removes the clause to the sentence boundary; application is line-surgical (the SpecMigrator pattern) — the drop deletes the scenario block and nothing else (FRs and sibling scenarios byte-intact, pinned) |

All criteria PROVED; none unproved.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| operator set parsing (labels, unknown-refusal naming the offender) | PROVEN | RED: module missing; green: spec_mutator_test group 1 |
| candidate generation (doc-order SM-### ids, filter-stable ids) | PROVEN | RED: same; green: ids stable across filters, exact element addresses |
| weaken strips literals/numbers from a Then | PROVEN | green: apply() assertions on the mutated line, prefix preserved |
| drop removes the edge-case block and nothing else | PROVEN | green: FR section + sibling scenario byte-intact assertions |
| swap-literal: strings `-swapped` inside delimiters, numbers +1 | PROVEN | green: `"'Hello-swapped'"`, `MUST return 43` |
| widen: range upper x2 / lower ÷2; bounds doubled | PROVEN | green: `within 0..200` |
| drop-must-not to the sentence boundary | PROVEN | green: `MUST NOT` gone, `MUST return 0 when the name` intact |
| budget/seed selection (prefix, seeded shuffle, over-budget) | PROVEN | green: selection group |
| P1 gate chain (template/parser/coverage/declarations/deps) | PROVEN | green: accepts fixture; refuses all-dropped scenarios (parser gate); refuses unknown template version |
| auditor oracle: weak fixture → all survive, flagged, ledger gaps, dedupe | PROVEN | RED: module missing; green: auditor test group 1 (fail_survived, 6 ledger rows `severity: contract`, second run appends nothing, spec.md hash-identical after the round) |
| auditor oracle: strong fixture → all killed, certified, P2 loop-red | PROVEN | green: `FR-001:literal:42` swap killed via `P2:loop-red` (regenerated test red against the committed implementation), byte-identical report on re-run |
| honest refusals (missing registry, red preflight, load failure, no candidates) | PROVEN | green: not_assessed / preflight_red gates; infra never a kill; vacuous never a pass |
| budget/seed at the auditor level; report shape; spec-hash binding | PROVEN | green: budget caps + same-seed selection; `{mutation_id, spec_line, operator, verdict, evidence}` keys; sha256 binding |
| command surface (registration, flags, usage errors, drift gate exit 3, corpus misfire exit 2) | PROVEN | RED: `Could not find a command named "spec"`; green: command test groups (12 tests) |
| demo (real processes): weak flagged / strong certified / corpus gating | PROVEN | integration tier +2 (32s + 20s of REAL `dart test` spawns) and the CI script end to end |

## Deliberate mutants (hand-run, this session)

| Mutant | Killed by |
| ------ | --------- |
| M1: route-token regex uses group(2) (RangeError on every swap over routes) | the mutator suite's route/literal generation tests (the exact crash was the first red run's output) |
| M2: element prefix uses the FR order index instead of the FR's written id | the widen test (element `FR-003:range` never found; fixed to `statement.elementPrefix`) |
| M3: bound tokens overlapping an explicit range (`within 0` inside `0..100`) produce no-op mutants | the widen test (the first candidate was the degenerate overlap; filtered) |
| M4: `if (final x = ...)` pattern / raw-string regex terminators | compile red (analyzer) — fixed before any green run |
| M5: ids assigned AFTER the operator filter (ids shift across filters) | the id-stability test (ids now assigned over the full set, then filtered) |
| M6: quote-insensitive swap (`'Hello'` → `'Hello'-swapped`) appends outside the delimiters | the swap test (`"'Hello-swapped'"` exact match required) |
| M7: verdict `return` inside `finally` (swallows exceptions) | analyzer lint `control_flow_in_finally` + restructured flow; restoration failures now surface as not_assessed outcomes |

## Honesty notes

- The slow tier's real-process evidence is duplicated on purpose: the
  integration test (local `--preset=all` runs) and the self-contained
  `tools/spec_fuzz_demo.sh` (CI — no test-runner dependency, the
  proof_smoke.sh recipe). Both were executed and captured.
- The chunked fast suite's one red chunk (`test/plugins/cache`, 2
  failures) was reproduced IDENTICALLY on clean master (stash → re-run →
  same two tests → pop) — pre-existing, NOT caused by this feature. Same
  proof for `test/commands` (2 entity-cli failures) and
  `test/plugins/tdd` root (failing list byte-identical to master:
  `comm` diff = 0 in both directions).
- `tools/run_tests_chunked.sh` splits heavy folders into subfolders only
  (pre-existing runner limitation): root-level files of
  `test/plugins/tdd` and `test/commands` are not chunk-covered on master
  either; they were run here directly (`dart test <folder>
  --exclude-tags flutter`) — matching what CI's `dart_core` job
  (`dart test test --exclude-tags flutter`) executes.
- `zfa spec fuzz` on a feature without `tdd/artifacts.json` grades
  `not_assessed` (honest refusal, exit 64) — legacy features are never
  silently passed, mirroring `zfa tdd verify`.
- No test asserts only "not throwing": every test pins exact ids,
  elements, exit codes, machine-line tokens, ledger fields, or
  byte-identical report content.
