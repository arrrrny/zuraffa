# Verification: 1528-auto-tdd-init-or-setup-error

## Test-first evidence (red → green)

| behavior | red evidence | green evidence |
| -------- | ------------ | -------------- |
| U-1528-1 (FR-005/FR-009 verify-red single lane) | RED: `dart test …issue_1528_setup_error_test.dart` — actual transcript showed `classification=unresolved` on the missing-profile path (the bug); the setup-error assertions failed | GREEN: 2/2 — fail-closed summary `classification=setup-error certified=false`, `--> fix: run \`zfa tdd init\`, then re-run`, verdict receipt `exit_class=setup-error` under `--json`, exit 1, no evidence, profile still absent (FR-008 read-only preserved, no auto-init) |
| U-1528-2 (FR-006 batch lane) | RED: batch summary showed `classification=unresolved feature=all` | GREEN: 2/2 — per-behavior + batch `classification=setup-error`, fix line, exit 1; empty-targets early return keeps `classification=batch` exit 0 |
| U-1528-3 (FR-007 ordering/vocabulary) | — (born-green invariants; passed on pre-fix master) | GREEN: 2/2 — unknown-id with NO profile still resolves FIRST (`unresolved`), valid-profile unexpected-green unchanged; pinned U27 flipped to setup-error |
| U-1528-4 (FR-001/FR-004 run entry) | RED: `--preset=integration` — no profile after the run (no preflight), no fail-closed gate on misfire | GREEN: 2/2 — missing profile → idempotent init at entry (profile + smoke test + dart_test.yaml + spec template logged as created), loop drives its first step, no `unresolved`; misfire → journaled `preflight_red` (result=setup-error, writer failure in violations), zeroed summary, exit 1, ZERO spawns |
| U-1528-5 (FR-002/FR-004 gen entry) | RED: no preflight, no profile after gen; misfire exited 0 | GREEN: 2/2 — auto-init + artifact log before the flow (exit 0); misfire → refusal verdict `exit_class=setup-error`, exit 1 |
| U-1528-6 (FR-008 no-op guarantee) | — (born-green) | GREEN: 1/1 — profile present → verify-red prints no preflight line, profile bytes untouched, honest red still certifies |
| U-1528-REG1 (FR-003/FR-010 regression guard) | — | GREEN: see test-run matrix below; the only failures are BYTE-IDENTICAL to the clean base commit (stash-diff verified, pre-existing environmental) |

## Test runs (cloud-agent scope: changed files only — no full suite)

```text
dart analyze (all changed lib+test files)                                → No issues found!
dart format (changed files)                                              → 0 diffs after formatting
dart test issue_1528_setup_error_test.dart --exclude-tags "slow,integration" → 7/7 pass
dart test issue_1528_setup_error_test.dart --preset=integration           → 4/4 pass
dart test verify_red_command_test.dart + verify_red_subdirectory_test.dart --preset=all
                                                                         → 22 pass / 1 fail (pre-existing, identical on base)
dart test run_command_test.dart --preset=all                             → 50/50 pass
dart test gen_command_test.dart + tdd_command_smoke_test.dart + json_flag_test.dart
         + bug_1303_dep_override_preflight_test.dart --preset=all        → 42 pass / 2 fail (pre-existing, identical on base)
dart test bug_1458 + bug_912_template_self_hosting + bug_1183 + two_cycle_run_commands
                                                                         → 15/15 pass
dart test run_engine_command_test + run_skin_command_test + bug_922 + bug_1159
                                                                         → 17/17 pass
```

## Pre-existing failures (stash-diff verified against clean master 46fe766e)

- `verify_red_command_test.dart › U23/A1` — evidence path-form expectation fails identically on the base commit (environmental).
- `gen_command_test.dart › bug #871 registry composite third segment` — fails identically on base.
- `tdd_command_smoke_test.dart › zfa tdd --help lists the corpus family` — fails identically on base.

None are touched by this branch: the same test IDs fail before and after, with no new failures introduced.

## Test-smell rubric

- **Assertion strength**: the setup-error tests pin the EXACT summary line
  (`classification=setup-error certified=false feature=…`), the `--> fix:`
  remediation, the verdict envelope fields, the exit code, the journal
  entry (`preflight_red` + violations), and the ABSENCE of step spawns
  (fake-zfa argv log emptiness) — not loose `contains('setup')` matches.
- **No test-only backdoors**: every scenario drives the real CLI through
  `CliRunner` over `TddFixture` (profile-less fixtures for the setup
  conditions; the fake zfa binary for the driver tier).
- **Honesty checks**: the no-op test asserts the profile's BYTES are
  untouched when present; the fail-closed test asserts the profile was
  NOT created by verify-red (the self-heal belongs to run/gen only); the
  misfire tests assert ZERO spawns so a broken baseline can never
  half-drive a loop.

## Acceptance-criteria coverage

- SC-001 (fresh fixture self-heals at run entry): U-1528-4 missing-profile scenario.
- SC-002 (valid profile → byte-identical behavior): U-1528-6 + the unchanged regression suites (run 50/50, lanes 17/17).
- SC-003 (verify-red ends with `classification=setup-error`, no spawn, no evidence): U-1528-1 (incl. U27 flip).
- SC-004 (analyze clean + changed-file tests pass): the matrix above.
- SC-005 (resolution vocabulary untouched): U-1528-3 + the pinned U18/U20/sc-004 A13 suites passing unchanged.

## Layer-contract conformance

- `TddBaselineInit` is the ONLY copy of the idempotent writer sequence; `zfa tdd init` output stays byte-identical (init sub-tests in verify_red_subdirectory_test.dart and the writer suites pass unchanged).
- `TddProfilePreflight.ensure` is the single entry preflight (run + gen); `verify-red` probes WITHOUT writing (FR-008).
- `setup-error` is carried by `kSetupErrorLabel` (one constant, three surfaces: run `result=`, verify-red `classification=`, verdict `exit_class=`).
- The TDD loop, state machine, and runner transcript classification (`RedClassification`) are untouched — the runner-transcript classes and the step sequencing tests all pass unchanged.
