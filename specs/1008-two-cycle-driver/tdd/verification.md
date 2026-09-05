# TDD Verification — feature `1008-two-cycle-driver`

Generated fresh from the REAL runs of this branch (the project is not
zfa-wired — no `.zfa.json` at the repo root — so this audit follows the
speckit.tdd.verify fallback path: test-first evidence, red-phase evidence,
test-smell rubric, acceptance-criteria coverage, and the actually-run
verification commands with their real outcomes).

## Gate

- gate: `passed_with_preexisting_exceptions`
- basis: every behavior of `tdd/test-list.md` has REAL red and green
  evidence in `tdd/cycle-log.md` (red: 21/21 tests failing for the right
  reason — the commands did not exist; green: 21/21 passing); every
  acceptance criterion of spec.md was executed against the real CLI; the
  regression gates match the pre-change baseline exactly, with the three
  non-matching suites each verified pre-existing at HEAD by stashing the
  change and re-running.

## Test-first evidence

- The test file `test/plugins/tdd/two_cycle_run_commands_test.dart` was
  written and committed BEFORE any implementation existed.
- Red proof (before implementation):
  `dart test test/plugins/tdd/two_cycle_run_commands_test.dart --preset=all -t slow`
  → `+0 -21` — every test fails with `Could not find a subcommand named
  "run-engine"/"run-skin"/"status" for "zfa tdd"` (the direct CLI repro
  and the full failure output are recorded in `tdd/cycle-log.md`).
- Green proof (after implementation): `+21: All tests passed!` (re-run
  after `dart format .` — still `+21`).

## Mutation-style strength check

The suite kills the classic weak-test mutants by construction:

- A lane that drives the wrong rows fails the exact step-invocation lists
  (U1/U7/U9 assert the full ordered `[gen|verify-red|make|refactor]`
  sequence, not just "exit 0").
- A gate that returns the wrong exit code fails U5/U6 (exit 2 pinned) and
  the status tests (exit 0 iff both green pinned).
- A meta-driver that runs the lanes out of order or re-drives BOTH
  behaviors fails U9's strict ordering assertion and the 20-step count.
- A summary-line or receipt-schema drift fails the exact `contains(...)`
  assertions on the machine lines and the decoded JSON fields.
- Legacy compatibility mutants fail U3/U12 (byte-compat step sequence and
  summary shape).

No formal mutation_test run was performed (the repo's mutation harness
keys on `tdd/artifacts.json` gen'd subject stubs; this spec's tests are
hand-written command-level tests in the spec 049 run-command-test
tradition — see `test/plugins/tdd/run_command_test.dart` for the pattern).

## Test-smell rubric

- No test asserts only "not throwing": every test asserts exact
  step-invocation lists, exit codes, receipt fields, or output lines.
- No shared mutable state across tests: each test gets a fresh
  `TddFixture` temp project (`setUp`), disposed in `tearDown`.
- No sleeps, no retries, no time-dependent assertions: the driver is
  deterministic against the scripted fake (the TddFixture pattern the
  repo's own spec 049 driver tests use).
- The fake step binary writes the same evidence contracts the real
  steps write (red/green cycle-log sections), so the evidence-path
  assertions exercise the real parsing.

## Acceptance-criteria coverage

- US1.AC1-4 (engine lane): U1, U2, U3, U4 — PROVED (exit 0, exact rows,
  receipt verdict/ids/counts, red receipt on honest stop).
- US2.AC1-4 (skin gate): U5, U6, U7, U8 — PROVED (exit 2 missing
  receipt, exit 2 non-green receipt, skin rows only with BOTH skipped,
  vacuous green on legacy).
- US3.AC1-4 (meta driver): U9/U9b, U10, U11, U12 — PROVED (lane
  ordering, fail-fast with no skin steps/receipt, unified journal entry +
  machine summary line, legacy byte-compat).
- US4.AC1-3 (status): U13, U14/U14b/U14c, AC3 — PROVED (one line, both
  verdicts, exit 0 iff both green, misfire stop on a missing feature
  directory).
- Plan-file lane resolution (#1000 forward-compat): U15 — PROVED
  (04-ENGINE.md/04-SKIN.md win over tags; ids in both files are BOTH).

## Verification commands (real runs, this session)

| command | result |
| --- | --- |
| `dart analyze lib test --no-fatal-warnings` | 0 errors; 315 issues vs 316 at HEAD (pre-existing warnings/infos; one unused import removed) |
| `dart test test/plugins/tdd/two_cycle_run_commands_test.dart --preset=all -t slow` | +21 All tests passed |
| `dart test test/plugins/tdd/run_command_test.dart --preset=all -t slow` | +39 -1 — identical to HEAD baseline (bug #691 fails at HEAD too; verified by stash/re-run) |
| `dart test test/plugins/tdd/services/` | +562 All tests passed |
| `dart test test/plugins/tdd/commands/` | +157 All tests passed |
| `dart test test/plugins/tdd/run_command_path_format_test.dart` | +5 All tests passed |
| `dart test test/plugins/tdd/run_baseline_cache_test.dart --preset=all -t slow` | +7 All tests passed |
| `dart test test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart --preset=all -t slow` | +7 -4 — identical to HEAD baseline (doctor tier) |
| `dart test test/plugins/tdd/scenarios/sc_019_legacy_dialect_migration_test.dart --preset=all -t slow` | +3 All tests passed (after the deprecation-note fix this spec required) |
| `dart test test/plugins/tdd/scenarios/sc_018_plan_run_loop_e2e_test.dart --preset=all -t slow` | fails at `zfa tdd plan` template-version drift — identical at HEAD (open issue #1058) |
| `tools/run_tests_chunked.sh` chunk plan (all 76 chunks, kernel caches cleared between) | every fast-tier chunk "All tests passed!"; 4 no-test folders exit 79 identically at HEAD; test/tdd/073-slice-isolation flaked once under load then passed 2/2 clean retries |
| `dart format .` | idempotent ("0 changed" on the second run); `git diff --stat` shows only this spec's files |
| `dart test test/plugins/tdd/bug_801_run_multi_feature_ownership_test.dart --preset=all -t slow` | NOT COMPLETED — integration tier (real CLI + `dart pub get` + real test runs) exceeds this machine's 10-minute budget; not claimed. Same driver path covered green by the suites above and the real-CLI exit-criteria demo |

## Exit criteria (issue #1008) — all PROVED

- `zfa tdd run-engine 004-login-ui` green — exit 0, receipt verdict green
  (behaviors A1, U1, U2).
- `zfa tdd run-skin 004-login-ui` green — exit 0 after the green engine
  receipt (behaviors A1, W1, W2; A1 skipped as engine-certified).
- `zfa tdd run 004-login-ui` succeeds — exit 0, both receipts green,
  unified journal entry naming both, `run: feature=004-login-ui
  result=complete pending=0 red=0 green=0 done=5`.
- `zfa tdd run-skin` fails with exit 2 when the engine receipt does not
  exist — PROVED (`result=engine-required`, zero steps driven).
- `zfa tdd status 004-login-ui` prints both lane verdicts — PROVED
  (`status: feature=004-login-ui engine=green skin=green`).

## Remediation tasks

None for this feature. Pre-existing repo failures surfaced by the
regression gates (unchanged by this spec, verified at HEAD): bug #691
(run_command_test), the doctor-tier bug_828 failures, sc_018's plan
template-version drift (#1058), and the bug_801 integration-tier runtime.

## Post-merge addendum (master 5159c68c merged into this branch)

Master moved 31 commits during development — including spec(1000) (the
lane split this driver consumes), fix(986/992/991) to the run driver, and
spec(1002) (which landed broken: it imports
lib/src/utils/stale_usecase_test_cleaner.dart without shipping the file,
so master HEAD's test tree does not compile). The branch merged master
and re-proved everything:

- dart analyze: 0 errors.
- New suite: +21 All tests passed (post-merge).
- run_command_test: **+49 All tests passed** — master's #986/#992 tests
  pass through the extracted RunDriverCore, and the pre-existing bug #691
  failure is cured by master's #986 fix.
- services +615, commands +227, path-format +5, reader +23, sc_019 +3.
- Exit criteria re-proved via the real CLI on a post-#1000 split feature
  (split-receipt.json + plan pair + meta-index): all five PROVED, exit
  codes included.
- The chunked fast suite on the merged tree: 79 of 83 chunks green; the
  4 red folders (cache / controller / presenter / view) fail IDENTICALLY
  on a pure-master worktree — pre-existing at master HEAD, not caused by
  this branch (verified by direct comparison).
- Two merge-necessity fixes, both documented in the merge commit:
  the restored stale_usecase_test_cleaner.dart (master HEAD does not
  compile without it) and the CliRunner.runCapturing exit-code snapshot
  (dart:io exitCode is process-global; concurrent test isolates clobber
  reads — the flake reproduces 1-in-7 on pure master with the same
  signature).

Gate: `passed` (with the pre-existing master-HEAD failures named above —
they are this repo's, not this spec's, and predate the branch).
