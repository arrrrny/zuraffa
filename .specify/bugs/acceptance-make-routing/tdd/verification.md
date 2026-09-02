feature: acceptance-make-routing (bug #873, slug acceptance-make-routing)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 7ddf1b3c
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: 50 # scope: the #873 extraction/prefix guards, 2 deliberate mutants, no mutation tool in profile; M2 survived as equivalent-for-contract (redundant defense), see below
mutants_survived: 1
suite: fast tier chunked 67/67 chunks OK (62 pass, 5 empty-folder SKIP), 0 failed; targeted: planner 28/28, 873 CLI repro 1/1, U-873 3/3; slow-tier regression run recorded with 6 pre-existing master failures (baseline-verified, NOT introduced here)
---

# TDD Verification: bug #873 — acceptance behavior routed to `zfa make <BehaviorId>` (no --no-entity)

**Verdict: PASS_WITH_GAPS.** All four issue criteria are covered by tests
that landed in git history BEFORE the fix (test-only commit → fix
commit), the issue's exact CLI failure shape is reproduced and pinned at
both the planner and the `zfa tdd make` surface, no HIGH smells, and the
planner-guard mutant was caught. The gaps are process- and
environment-shaped: this audit was not independent (same session), six
pre-existing slow-tier failures on master were baseline-verified rather
than fixed, and the second mutant survived as a redundant defense.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| B-873-planner — the behavior's own id (from the generated test name `<id> — <description>`) is never the extracted entity name; the id-prefixed composite is refused unexpressible | PROVEN | RED recorded at the test-only tree: planner 3/3 fail with the offending dispatch verbatim (`zfa entity create -n A3 \| zfa make A3 \| zfa tdd wire A3 --entity A3 \| zfa build`); history: test-only commit precedes the fix commit; the pre-fix stash tree reproduces the identical red |
| B-873-narrow — a REAL entity behind the id prefix still derives (guard skips only the id token, #758 keeps its wire contract) | PROVEN | U-873b: `A1 — the Todo repository service ...` still plans the full 4-step Todo contract (`entity create -n Todo → make Todo → wire --entity Todo → build`); pre-fix the same input derived `A1` (baseline red output shows the `A1` contract verbatim) |
| B-873-cli — `zfa tdd make A3` with the real gen composite honest-stops `unexpressible` (the same deferral A1/A2 get in the issue log); no `make A3` / `entity create -n A3` dispatch; no green cycle | PROVEN | RED at the test-only tree reproduces the issue byte-for-byte (`plan: 4 step(s)` → `command: .../zfa make A3` → `exit: 1` → `outcome=generation-error`); post-fix the fake-bin dispatch log is EMPTY and the summary reads `outcome=unexpressible` |
| B-872-interplay — digit-bearing legal entity names are untouched; only the behavior's OWN id is refused | PROVEN (scope) | U-873b proves a non-id entity behind the prefix resolves; the filter compares against the record's own id only (no `^A\d+$` pattern); direct user invocation (`zfa entity create -n A1; zfa make A1`) never passes through `_extractCapitalizedTrace` |

No existing test was weakened, skipped, renamed out of a filter's reach,
or excluded by config in this change.

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | MED | 6 slow-tier failures exist on master and still fail at HEAD (5 in `make_command_test.dart`, 1 in `generation_planner_real_cli_test.dart`); they are NOT introduced by this change — each was re-run against the pre-fix stash tree and failed byte-identically (same expected/actual, modulo temp-dir hash) | `red-green-logs/baseline_873_prefix_failing.txt`, `baseline_873_real_cli.txt` vs post-fix `green_873_make_full_regression.txt`, `green_873_planner_real_cli.txt`; the #657 message-format failure and #826 kill-verdict trio predate this branch |
| 2 | LOW | Audit not independent: run by the same session that wrote the fix and its tests (rubric Hard Rule 2) | this report; smells re-checked from the files as written |
| 3 | LOW | Mutation M2 (make-side prefix strip disabled) survived: no test pins the strip alone because the planner filter backstops the observable contract | judged equivalent-for-the-#873-contract, kept as defense-in-depth (it also keeps the description clean for keyword routing, slug derivation, and cycle-log rendering for every consumer, not just the trace extractor) |

## Mutation results

No mutation tool in the profile (`.specify/memory/tdd-profile.md`:
"Mutation tool: none wired in CI"); deliberate-mutant sampling per the
rubric, one mutant at a time, restored exactly, suite re-verified green
after each restore. Sample: 2 mutants on the two changed sites.

| Mutant | Behavior | Survived | Judgment |
| --- | --- | --- | --- |
| `generation_planner.dart:426` — id filter dropped (`if (word.toLowerCase() == idLower) continue;` → comment) | B-873-planner | No | Caught by ALL three planner pins (U-873a/b/c fail; the CLI repro survives only via the make-side strip — the redundancy the two-guard design intends) |
| `make_command.dart:906` — prefix strip disabled (`if (description.startsWith(testNamePrefix))` → `if (false && ...)`) | B-873-cli | Yes | Equivalent-for-contract: the planner filter alone refuses the id-prefixed description, so the CLI repro stays green; the strip is retained as defense-in-depth (prose cleanliness for keyword routing, slug derivation, cycle logs) — the observable #873 contract does not depend on it |

## Traceability

| Criterion (from issue #873) | Tests | End to end |
| --- | --- | --- |
| AC-1: the acceptance path never dispatches `zfa make <BehaviorId>` / `entity create -n <BehaviorId>` (the #696 family, no `--no-entity`) | U-873a + U-873c (planner pins, dispatch-arg assertions) + CLI repro (fake-bin dispatch log must be empty) | Yes — the CLI repro drives the real `zfa tdd make` command through `CliRunner` against a real temp fixture registry, spawning a fake `zfa` binary whose argv log is asserted |
| AC-2: the repro honest-stops `unexpressible` — the same deferral A1/A2 get (per #829: compose in phase 2 or a REAL entity from Key Entities, never the behavior id) | CLI repro asserts `make: behavior=A3 outcome=unexpressible`, non-zero exit, no `## Cycle: A3 (green)` in the cycle log | Yes — same real-command path; the fake-bin `make A3 → exit 1` mapping reproduces the issue's #496 fail-fast to prove the pipeline never reaches it |
| AC-3: #758's extraction contract survives — real spec-named entities still route through the 4-step CRUD plan | U-873b (exact 4-step argv equality on `Todo`) | Planner-level (the unit contract of `_extractCapitalizedTrace`); the CLI-level CRUD route is covered by the existing `make_command_test.dart` suites (31/36 pass, failures pre-existing per Finding 1) |
| AC-4: #872's legal digit-bearing entity names are not broken by the guard | U-873b + scope analysis (own-id-only filter; direct `make A1` invocation unaffected) | Planner-level + code-path analysis; no test constructs a full user-typed `zfa entity create -n A1; zfa make A1` flow here — that path does not route through the planner |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The 6 pre-existing master failures (Finding 1): diagnosing/f fixing the
  #657 message-format regression and the #826 kill-verdict trio is out
  of scope for this bug; the baseline equivalence is the evidence this
  change did not worsen them.
- Mutation via tool: none in the profile; the 2 deliberate mutants
  sample only the two changed sites, not the whole planner.
- A real end-to-end `zfa setup → tdd plan → gen → verify-red → make`
  run on a fresh project (the issue's literal repro): the CLI repro
  mirrors its registry record and dispatch shape against a fake zfa
  binary; the full sandbox flow needs a real AOT `zfa` install, which
  this cloud agent does not have (the real-CLI suite's other failure is
  pre-existing, Finding 1).
- Flutter-tagged tests and the remaining slow tiers beyond the two
  directly-affected suites: excluded per `dart_test.yaml` tiering on
  this agent; `examples/` analyzer drift (47 pre-existing issues on
  master, zero in touched files) left untouched.
