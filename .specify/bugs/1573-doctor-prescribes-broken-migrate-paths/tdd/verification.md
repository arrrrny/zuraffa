---
feature: 1573-doctor-prescribes-broken-migrate-paths
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: dd390bf8
behaviors: 6
proven: 6
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: deliberate mutant 1/1 caught (positional acceptance restored)
mutants_survived: 0
suite: fast tier chunked 104 chunks — 98 pass + 5 slow-tier-only skips (test/benchmark, test/core/proof, test/integration, test/plugins/tdd/scenarios, test/tdd/077-make-engine-preset) + test/commands re-run standalone green (376/376 after its wrapper cap, 0 real failures); slow-tier targeted runs of every file with updated assertions green (bug_1397 9/9, gen_namespacing_827, bug_1573 6/6, bug_912 4/4; bug_874 doctor groups green — the file's 4 gen-recovery failures are identical at base db4db9a3, pre-existing, out of scope); dart analyze lib test --no-fatal-warnings exit 0 (112 info / 0 warning / 0 error, 0 in changed files); dart format clean on all six changed files
---

# TDD Verification: doctor + migrate-paths — executable prescription, bug-dir reachability, loud positional rejection (#1573)

**Verdict: PASS.** Every behavior B1–B6 in `tdd/test-list.md` is proven by
a test that existed and failed before the implementation (`+0 -6` at
cycle 1 red, same machine, same fixture) and passed after (`+6`). The
CI-proof the issue demanded — a test that EXECUTES the doctor's
prescribed command and asserts `migrated > 0` plus a doctor-healthy
follow-up — is B2; B4 proves the positional rejection leaves a bystander
form-drift registry byte-identical, which is the reported
collateral-damage shape. The live shipped-fixture repro was re-run at
every phase: the prescription is now
`zfa tdd migrate-paths --feature .specify/bugs/cycle-log-phantom-sections`
(exit 0, `migrated=5` under `--dry-run`), the positional form exits 2
(`ExitProtocol.usage`) naming the argument and pointing at `--feature`.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — the prescription is the flag form with the canonical bug reference | PROVEN | red: `Expected: contains 'zfa tdd migrate-paths --feature .specify/bugs/1573-sample-bug'` vs actual `zfa tdd migrate-paths 1573-sample-bug`; green post-fix, and the live doctor on the shipped fixture prints the new prescription verbatim |
| B2 — the prescribed command heals the diagnosed bug registry (migrated > 0, doctor → healthy) | PROVEN | red: `migrated=0` (bug directory never examined); green: `migrated=1`, registry records rewritten to the portable form, doctor re-run `healthy`; live dry-run on the shipped fixture plans `migrated=5` |
| B3 — a plain bug slug resolves through the bug extension pin | PROVEN | red: `migrated=0` with the pin active; green: `migrated=1` + portable rewrite |
| B4 — positional arguments are a loud usage error, never a sweep | PROVEN | red: exit 0 with `rewriting the recorded form for B1 in 1573-bystander-feature` (the bystander was swept); green: exit 2 (`ExitProtocol.usage`), message names the argument and `--feature`, bystander + bug registries byte-identical |
| B5 — the no-flag sweep covers `.specify/bugs/` | PROVEN | red: `no feature registry found under specs` with a bug registry present; green: `migrated=1` + portable rewrite |
| B6 — the path-form drift line prints the raw recorded value | PROVEN | red: drift shows the normalized view (`test/tdd/1573-sample-bug/a1_test.dart`), raw absolute never appears; green: drift carries the recorded machine-absolute string verbatim |

No pre-existing test was weakened or deleted. The six assertion updates
(the three bug #1397 and three bug #874 `--> fix:` pins) replace the
broken string shape with the fixed one — that string-shape-only pinning
is exactly the gap the issue names; the assertions now pin the flag form
AND still assert verdict/prescription/drift payload around them.

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | LOW | `_scanRegistries` resolves a plain slug through `resolveWithPin` (pin redirect honored) and additionally probes `.specify/bugs/<slug>` when no `specs/<name>` exists. A project holding BOTH a `specs/<slug>` and a `.specify/bugs/<slug>` registry resolves to the specs one (legacy priority, same precedence `resolveWithPin` applies to the pin); the bug copy is still reachable by path reference or sweep | `migrate_paths_command.dart` `_scanRegistries`; `feature_path_resolver.dart` precedence note |
| 2 | LOW | The positional rejection fires AFTER flag parsing but BEFORE any filesystem work, so a rejected invocation can never touch a registry; under `--json` the wrapper still emits the verdict envelope with the usage error (exit stays 2) | `migrate_paths_command.dart` `_run()` guard placement; `verdict_emitter.dart` catch path |
| 3 | LOW | Pre-existing (not introduced here): `bug_874`'s gen-recovery group (`--adopt` refusal, 4 tests) fails identically at base `db4db9a3` and on this branch — visible only when the slow tier is forced (`--preset=all`); CI's default fast tier never runs that file, which is also why the string-shape drift this bug fixes passed CI | `dart test --preset=all` base vs branch: identical `[E]` name sets (diff-verified) |
| 4 | LOW | `tools/run_tests_chunked.sh`'s recursion never emits a chunk for files sitting DIRECTLY under a heavy folder (`test/plugins/tdd/*.dart`, 102 files) when its subdirs emit chunks — the doctor-adjacent root-level suites (840/969/912/1324/1264…) were excluded from the chunk sweep and were run explicitly here. Consider emitting the residual direct files as their own chunk | chunk list (`chunks.txt`) vs `ls test/plugins/tdd/*.dart`; explicit root-level run `+30` green |

## Mutation results

No mutation tool in the profile; one deliberate mutant on the contract
the whole fix depends on — replaying the original bug by (a) reverting
the doctor's 2c prescription string to the positional name-only form and
(b) neutering migrate-paths' positional-argument guard. Killed: B1 red
(`Expected: contains 'zfa tdd migrate-paths --feature
.specify/bugs/1573-sample-bug'` vs the reverted prescription) and B4 red
(positional accepted again, exit 0 instead of `ExitProtocol.usage`);
`+4 -2: Some tests failed.` Restoration via `git checkout --` verified
byte-identical to the committed fix (`git status` clean on `lib/`), and
the full suite returned to `+6: All tests passed.`

## Acceptance criteria coverage

| Criterion (issue.md Expected) | Covered by |
| ----------------------------- | ---------- |
| 1. Prescription is the executable flag form with the canonical reference | B1 (+ live shipped-fixture doctor run) |
| 2. migrate-paths reaches `.specify/bugs/<slug>/tdd/artifacts.json` (flag, pin, sweep) | B2, B3, B5 |
| 3. Unrecognized positional arguments are rejected loudly | B4 (+ live exit-2 run) |
| 4. Path-form drift line prints the raw recorded value | B6 |
| 5. A test executes the prescription and asserts migrated > 0 | B2 (the suite runs the command and the doctor heal loop) |
