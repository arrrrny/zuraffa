---
feature: 0971-route-a-plus-upgrade
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: 31e7b012 # short SHA audited (behavioral commit; this file lands in the follow-up audit commit)
behaviors: 17
proven: 10
likely: 0
test_after: 6
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 5/5 deliberate mutants killed # sampled, not tool-measured (see below)
mutants_survived: 0
suite: route chunk 87 passed, 0 failed (12s, 3x flake-free) / full chunked fast suite 74/74 chunks PASS
---

# TDD Verification: route A+ upgrade (spec 0971)

**Verdict: PASS_WITH_GAPS.** Every acceptance criterion of issue #971
reaches a real assertion through the real command surface, all five
deliberate mutants were killed, and the audit's one substantive finding
(a missing drift direction — a stale receipt verifying as healthy) was
remediated through a genuine red-first cycle (R1) rather than waved
through. The gaps that keep this from `PASS`: six order-5 error-path
behaviors were pinned **after** their implementation landed with the
T002/T004 cycles (classified `TEST_AFTER` below, disclosed rather than
reclassified), mutation strength is a 5-mutant deliberate sample rather
than a tool-measured score, and the audit was run by the same session
that wrote the tests.

## /speckit.tdd.verify dispatch (step 8)

Engine detection (step 0) was executed for real:

```bash
zfa --version 2>/dev/null && test -f .zfa.json && echo "ZFA_OK" || echo "ZFA_MISSING"
# -> ZFA_MISSING
```

No `.zfa.json` exists at the repo root, so the deterministic
`zfa tdd verify` engine is not wired for this checkout; the command's
**fallback LLM-guided audit** protocol ran instead: test-first evidence
from the cycle log and git history, the test-smell rubric pass,
deliberate-mutant strength checks scoped to the changed files, and
acceptance-criteria traceability. Everything below is from the real
runs of this session — commands as recorded, outputs as captured.

## Test-first evidence

The feature lands as one behavioral commit (`31e7b012`, repo convention
is feature-scale commits — the 049 precedent), so per-cycle ordering
rests on the cycle log, which was written through the real
`CycleLog.append` writer (schema-1 hash chain, `specs/0971-route-a-plus-upgrade/tdd/cycle-log.md`,
14 entries). Compile-level reds count as red per the 0806 precedent.

| Behavior | Class          | Evidence                                                                                                    |
| -------- | -------------- | ----------------------------------------------------------------------------------------------------------- |
| A1       | PROVEN         | cycle red recorded: `+3 -1: Some tests failed` — "zfa route --help no longer advertises --methods" (assertion-level; the help text contained `--methods`) |
| A2       | PROVEN         | cycle red recorded: `+0 -6` — all six envelope tests failed ("no JSON envelope found"; `--json` did not exist as an output flag) |
| A3       | PROVEN         | cycle red recorded: `+1 -3` — receipt missing / hash null / proof-red path (the "green on fresh create" test passed vacuously pre-implementation) |
| A4       | PROVEN         | cycle red recorded (compile-level): `Error: No named parameter with the name 'testRunner'`; the healthy/missing-builder tests were in that file |
| U1–U4    | PROVEN         | inside the T004 red file (missing receipt, failing test run, vanished route, hash drift — same compile-level red) |
| U11      | PROVEN         | inside the T004 red file (verdict receipt + `--json` envelope tests)                                        |
| U13      | PROVEN         | remediation driven red-first this session: `Expected: <1> Actual: <0>` (stale receipt verified as healthy), then green after the reverse-direction check |
| U5–U10   | TEST_AFTER     | order-5 error-path pins (corrupt receipt, no-entity fix line, structured skip, invalid scheme, --help surfaces, dry-run discipline): tests written after the implementation landed with the T002/T004 cycles — no per-behavior red exists. Mitigations: the family shares the command that was born red (A2); mutant M2 (dry-run guard dropped) is killed by U10's test, proving the pins assert real behavior; the family's newest member (R1/U13) was driven red-first. |
| U12      | NOT_APPLICABLE | characterization pin of untouched drift-mode behavior (sc_001/sc_002 stay green)                            |

Checks on pre-existing tests: no assertion was removed, loosened,
renamed, skipped, or excluded. The only existing-file edits are
additive (`RouteVerifyCommand` gains entity mode alongside untouched
drift mode; `ReceiptStore` gains `saveNamed` alongside `save`;
`RouteCommand` loses only the dead flag). `sc_002`'s drift JSON
contract and `dead_positional_grammar_test`'s exit-64 contract were
re-run green after every change.

## Mutation strength (deliberate mutants, changed files only)

No mutation tool is wired for this checkout (no `.zfa.json`), so the
rubric's deliberate-mutant protocol ran on the five highest-risk
behaviors. Each mutant was applied, the behavior's suite run (must
fail), the code restored byte-exact, and the suite re-run (must pass):

| Mutant                                            | File                        | Killed by | Kill type |
| ------------------------------------------------- | --------------------------- | --------- | --------- |
| M1 route-table-test hash binds reversed bytes     | route_receipt.dart          | T003      | assertion (`Expected: 8a98f72b… Actual: 660b5f36…`) |
| M2 dry-run receipt guard dropped (`if (true)`)    | route_create_command.dart   | T005      | suite failure |
| M3 verify exit code inverted                      | route_verify_command.dart   | T004      | suite failure |
| M4 GoRoute builder-presence check disabled        | route_verify_command.dart   | T004      | suite failure |
| M5 envelope schema version wrong (1 → 2)          | route_create_command.dart   | T002      | suite failure |

5 sampled / 5 killed / 0 survived. Sample scope: the three changed
command/receipt files. M1 was re-verified with a compile-clean mutation
to confirm the kill is assertion-level, not a compile artifact.

## Test-smell pass

Every new test file was re-read cold. Zero `HIGH` smells. Notable
deliberate choices: no doubles of the units under test (the commands
run against real temp projects); the only injected double is the
headless test runner (the tdd realize suite-runner pattern — the
subprocess boundary is exactly what the injection seam exists for);
the envelope tests parse printed output rather than reaching into
private state; one shared per-file `capturePrints`/`envelopeFrom`
helper instead of per-test copies. The suite is deterministic — the
`-C` CWD-swap races found in the first version of the tests were
removed by driving commands through `CommandRunner` with explicit
projectRoots (the bug_912 convention), after which the route chunk
passed 3× consecutively.

## Traceability: acceptance criteria to tests

| Issue #971 acceptance criterion                                             | Test(s) that reach it through the real entry point |
| --------------------------------------------------------------------------- | --------------------------------------------------- |
| `zfa route --help` no longer advertises the dead `--methods` flag            | spec_971_t001 (4 tests: flag gone, `-m` gone, bare-route contract, live subcommands) |
| `route create --json` envelope schema asserted by test                       | spec_971_t002 (6 tests: five contract keys, schema=1, routes/deepLinks values, testPath real on disk) |
| Fresh `route create` writes the routes receipt; proof check green, red on hand-edited route file | spec_971_t003 (4 tests: receipt content, hash binding, ProofChecker green/red — the same engine `zfa proof check` dispatches to) |
| `zfa route verify` exits 0 on a healthy table, 1 + `--> fix:` on a missing builder — both tested | spec_971_t004 (healthy→0 incl. runner-unavailable; missing builder→1+fix; 8 tests) + spec_971_f1 (stale receipt→1+fix) |

No untested criteria; no tests tracing to nothing (the dry-run and
help-surface pins trace to order 5's "every error path" clause).

## Suite state (real runs, this session)

- `dart test test/plugins/route` — **87 passed, 0 failed** (12s), re-run
  3× consecutively flake-free after the CWD-race fix.
- Chunked fast suite (`tools/run_tests_chunked.sh` semantics, run in
  resumable batches): **74/74 chunks PASS**. Two transient batch events
  investigated: (1) the route-chunk flake — root-caused to the new
  tests' `-C` CWD swaps racing under `concurrency: 2`, fixed by the
  CommandRouter rewrite, then 3× green; (2) one flake in the
  pre-existing `tdd/commands/view_command_test.dart` U-V1 — passes in
  isolation and on the full re-run, file untouched by this diff.
- `dart analyze` — 0 new issues (31 pre-existing errors confined to
  `examples/todo_tdd`, which requires Flutter codegen unavailable here;
  0 errors/warnings in `lib/` or `test/`).
- `dart format .` — 1987 files, **0 changed**.

## Audit independence disclosure

The same session authored the code and ran this audit (the fallback
path's expected shape on a solo session). Mitigations: every file was
re-read cold for the smell pass; every mechanical claim above (suite
runs, mutant kills + restores, engine detection, formatting) was
executed from the live tree during the audit rather than recalled; the
mutation findings are reproducible from the recorded mutant diffs in
`/home/z/my-project/mutation_results.txt`.

## Remediation record (/speckit.tdd.verify step 4, pass 1 → 2)

- **Pass 1 finding F1** (substantive): the verify static check compared
  only receipt → disk; a route module added after the receipt (stale
  ledger row) verified as healthy. Remediation task R1 appended to
  `tasks.md`, driven red-first (`spec_971_f1_reverse_drift_test.dart`,
  red `Expected: <1> Actual: <0>` → green), cycle logged (U13).
- **Pass 1 findings F2–F3** (discipline): the six TEST_AFTER order-5
  pins and the sampled-not-measured mutation score. Left as disclosed
  gaps — see the verdict line; no remediation task retrofits ordering.
