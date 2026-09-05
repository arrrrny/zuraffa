---
feature: 1007-contract-tests-first-class
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 1007-contract-tests-first-class@working-tree
engine_gate: not_assessed # no gen artifacts registered for this feature's dir — self-hosting lane, hand-authored tests (see Engine gate)
behaviors: 12
proven: 12
pinned: 0
likely: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # deliberate-mutant sampling below (4/4 killed)
mutants_survived: 0
suite: 2914 passed, 0 failed (fast tier, tools/run_tests_chunked.sh semantics, 70 chunks green / 4 designed skips); test/plugins/tdd one-shot 1103 passed, 0 failed (run twice); slow tier: contract e2e 2/2, corpus_run 23/23; dart analyze lib test = master baseline (314 infos, 0 errors); dart format . = 0 changes
---

# TDD Verification: `1007-contract-tests-first-class`

**Verdict: PASS** — every behavior of the contract lane is PROVEN
red-first: the feature was reproduced as failing output FIRST (the RED
repro script, below), then implemented, then pinned by tests in the same
change. All four issue exit criteria are PROVED by executed commands
with captured output, not recited from memory. Zero HIGH smells; the
suite-wide fast tier and the TDD plugin folder are green at the exact
master baseline.

Audit run by the same session that wrote the tests (stated per the
rubric's honesty rule): the red evidence below is the captured output of
the repro and test runs performed by this session, before the
implementation landed.

## Engine gate (stated honestly)

`zfa tdd verify --feature 1007-contract-tests-first-class` is
`not_assessed` (no gen'd artifact registry for this feature directory):
this feature is SELF-HOSTING — its behaviors are the zuraffa repo's own
`zfa tdd` plan/gen/verify-red/run/corpus mechanics, tested through
hand-authored suites under `test/plugins/tdd/` (the spec-046 scenario
convention) plus a real-`dart test` e2e for the generated pair. The
engine's mutation audit only assesses gen'd registries, so the mutation
gate was executed as deliberate-mutant sampling (below), per the
tdd-profile rubric.

## RED evidence (captured before the implementation)

`scripts/../repro_1007_red.sh` (kept in the session log, not committed)
drove the PRE-fix binary against the 004-login-ui fixture spec:

| Repro | Pre-fix output (captured) |
| ----- | ------------------------ |
| `zfa tdd plan 004-login-ui` | "RED: plan emits no contract:<id> rows (test-list has no 'contract:' lines)" |
| `zfa tdd gen contract:A1` | "zfa tdd gen: unknown behavior id \"contract:A1\". No matching row found…" |
| A contract-shaped row's generated pair | `classification: compile-error` — the `:` leaked into the subject function name (`subject_contract:a1` is not a Dart identifier); never a BLOCKED verdict |
| `enum BehaviorState` | `{ pending, red, green, mocked, done }` — no `blocked` member; `enum BehaviorKind` — no `contract` member |

## Exit criteria — PROVED vs not

| Exit criterion | Status | Evidence (executed this session) |
| -------------- | ------ | -------------------------------- |
| `zfa tdd plan 004-login-ui` emits `contract:A1` (entity method contract) in the engine plan | **PROVED** | plan run on the 004-login-ui fixture: test-list.md carries `## Contract loop: contract behaviors` and the exact row `| contract:A1 | User.validateEmail(String email) -> bool (entity method contract) | User.validateEmail | PENDING |`; the controller method (`contract:A2`) and usecase (`contract:A3`) rows follow; pinned by `contract_kind_1007_test.dart` (plan group) |
| `zfa tdd gen contract:A1` produces a contract test that enumerates method cases | **PROVED** | gen writes `test/tdd/004-login-ui/contract_a1_test.dart` (Cases 1..3: signature / implementation / return) + `lib/tdd/004-login-ui/contract_a1_subject.dart` (seam `bool validateEmail(String email)`); pinned by the gen group |
| A deliberately unimplemented method causes a BLOCKED (not RED) verdict | **PROVED** | (a) real `dart test` executes the generated pair — one failing test through an assertion (`Expected: not <Instance of 'UnimplementedError'>`); (b) `zfa tdd verify-red contract:A1` prints `verify-red: behavior=contract:A1 classification=blocked certified=false`, exit 1, receipt `.zfa/receipts/contract-blocked.A1.json` (schema `contract-blocked.v1`), and NO cycle-log red evidence; (c) `zfa tdd run 004-login-ui` stops at `contract:A1:verify-red` with `result=blocked blocked=1`, make never spawns, run-state records `blocked`; (d) implementing the seam flips the verdict to `unexpected-green` (out of the blocked class); pinned by the verify-red, run and e2e groups |
| Corpus-economics gate treats contract failures as highest-severity gaps | **PROVED** | gap ledger entries with `outcome=blocked` carry `severity: contract`; `GapLedgerTotals` orders open contract gaps FIRST and counts them (`contract_gaps=` token on the corpus summary line); the blocked stop prints the highest-severity note; pinned by the corpus-economics group + corpus_run slow suite |

All four criteria PROVED; none unproved.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| reader: Contract loop section sets kind | PROVEN | RED: pre-fix reader parsed such rows as malformed/kind-less; green: `contract_kind_1007_test.dart` reader group |
| reader: `contract:` id folds to a valid target | PROVEN | RED: `subject_contract:a1` (invalid identifier, the repro's compile-error); green: `subject_contract_a1` with canonical ids byte-identical (`A1`, `B-001`) |
| reader: BLOCKED state cell parses | PROVEN | RED: "unknown state \"BLOCKED\""; green: `BehaviorState.blocked` |
| plan: contract rows derived per entity method / controller / usecase | PROVEN | RED: repro [1]; green: plan group (3 rows + provenance `contract lane [declared: layer contracts section]`) |
| plan: no Layer Contracts → no contract section | PROVEN | pre-1007 plans keep their shape (additivity) |
| plan: ids stable across re-plan (traces reconcile) | PROVEN | re-plan keeps `contract:A1` + hand-advanced BLOCKED state |
| gen: contract pair (enumerated cases + seam + registry) | PROVEN | RED: repro [2] (unknown id) + [3] (compile-error pair); green: gen group |
| verify-red: BLOCKED verdict + receipt + no red evidence | PROVEN | RED: repro [3] (assertion → certified RED today); green: verify-red group (scripted honest transcript) + e2e (real dart test) |
| run: blocked parks the behavior, stops before GREEN | PROVEN | green: run group (fake-zfa driver: `result=blocked blocked=1`, state `blocked`, make never spawned) |
| corpus: severity=contract ordering + counts | PROVEN | green: corpus-economics group + corpus_run slow suite |
| e2e: real runner grades BLOCKED; implemented seam flips | PROVEN | `contract_blocked_e2e_1007_test.dart` (slow tier), 2/2 |
| additivity: full suite at master baseline | PROVEN | 2914 fast-tier + 1103 tdd-folder tests, 0 failures; analyze 314 = master; format clean |

## Deliberate mutants (no mutation tool wired — hand-run, this session)

| Mutant | Killed by |
| ------ | --------- |
| M1: revert `_lastTopLevelArrow` to detect `--` (return type silently lost) | the smoke run showed `-> void` seams; fixed; the e2e's `isA<bool>()` return case + gen group's `bool validateEmail` seam assertion kill it |
| M2: revert `_toSnakeCase` `:` fold (paths become `contract:a1_test.dart` / double underscores) | gen group asserts the exact `contract_a1_test.dart` paths |
| M3: drop the contract-kind re-grade in verify-red (falls back to certified RED) | verify-red group asserts `classification=blocked certified=false` AND `isNot(contains('classification=assertion certified=true'))` |
| M4: drop the blocked handling in the run driver (generic honest stop, state stays red/pending) | run group asserts `result=blocked`, `blocked=1`, run-state `blocked`, and the exact two-step invocation log |

## Honesty notes

- The fast-tier verify-red test drives a scripted-but-honest assertion
  transcript through the REAL classifier; the REAL `dart test` lane is
  the slow-tier e2e (2/2). Both were executed and captured.
- The slow tier contains three PRE-EXISTING failures on clean master
  (`run_command_test.dart` U24 timeout, its #691 test, and
  `gen_command_test.dart`'s #871 test) — reproduced identical on master
  before this branch; NOT caused by this feature (the slow tier is
  excluded from CI's default run).
- `zfa tdd plan 004-login-ui` in a bare temp project stops at phase-0
  (`zfa entity create` needs a real project) when driven with the REAL
  CLI end to end; the run-driver blocked verdict is therefore pinned via
  the house fake-zfa pattern (the same harness every run_command_test
  test uses), and the real-CLI path is pinned at the verify-red level.
