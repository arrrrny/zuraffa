# tdd.verify — Bug #1488 acceptance vacuous green

- **Verified**: 2026-09-13, this session, on
  `fix/1488-acceptance-vacuous-green` (working tree, pre-push), HEAD base
  b621f38b (master)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64 (cloud sandbox, 4 GB
  RAM / 10 GB disk — see §4 environment caveats)
- **Scope**: the widened make step-3c gate + the two comment blocks, the
  new `bug_1488` suite, the two inverted legacy pins (`bug_1259` U3,
  `bug_1162` A-1162e), then the chunked fast suite and the slow tdd
  scope below.

## Verdict: PASS (with the recorded host/environment caveats in §4)

## 1. RED → GREEN (the fix's own cycle)

- **RED (pre-fix, clean b621f38b)**: `bug_1488` A1 — acceptance row +
  certified red + non-throwing subject + guard-only test certified
  `outcome=skipped`, exit 0, `## Cycle: A-1488 (green)` appended. Run:
  `+3 -1` (A1 the only failure; A2/A3/U1 guardrails already green).
- **GREEN (post-fix)**: A1 refuses — exit 1, `outcome=vacuous-green`,
  `UnimplementedError guard` named, NO green evidence. Run:
  `+4 -0` (`bug_1488` suite all green).
- The two inverted legacy pins re-ran green post-fix: `bug_1259`
  U1/U2/U3' and `bug_1162` all 5 (`+5: All tests passed!`,
  `+13 -3` across the three bug files where the -3 are the
  pre-existing environmental failures documented in §3).

## 2. dart analyze / dart format

- `dart analyze` on the five changed files: **No issues found!**
  (one transient `await_only_futures` info in the new 1162 pin was
  introduced and fixed during this session — final state clean).
- `dart format --output=none --set-exit-if-changed .`: **Formatted 2764
  files (0 changed)** — the tree is format-clean. (The `example/`
  package-resolution warning is the Flutter subpackage; no Flutter SDK
  on this host, expected, warning only.)

## 3. Full-suite sweeps (chunked; kernel caches cleared between chunks)

Fast suite (default tier; `dart_test.yaml` excludes `slow`):

- 106-chunk list of `tools/run_tests_chunked.sh` — every chunk OK or
  SKIP (all-slow folders, by design). Notable: `test/cli` OK,
  `test/commands` OK, `test/plugins/tdd/commands` OK.
- The loose `test/plugins/tdd/*.dart` files the subdir split skips
  (99 files, chunk `test/plugins/tdd/__loose__`): **+519 All tests
  passed!**
- `test/plugins/tdd/services` (fast tier): **+945 All tests passed!**
- Remaining commands+loose files (fast tier): **+488 All tests passed!**

Slow tdd scope (`--preset=all`, per file, `-j 1`) — fix-relevant
results:

| suite | result |
| ----- | ------ |
| bug_1488_acceptance_vacuous_green_test | +4 All tests passed |
| bug_1162_bug_subject_green_path_test | +5 All tests passed (incl. inverted A-1162e) |
| bug_1259_vacuous_green_test | U1/U2/U3' green (see §3a for U4-U6) |
| make_command_test | +33 (see §3a for the 5 env failures) |
| make_command_1036_test | +5 All tests passed |
| make_command_strict_071_test | +1 All tests passed |
| make_command_declared_071_test | +4 All tests passed |
| make_command_widget_939/950_test | +4 / +1 All tests passed |
| run_command_test | +50 All tests passed |
| run_skin_command_test, verify_command_test, gen_namespacing_827_test | All tests passed |
| issue_1308_vacuous_guard_remedy_driver_test | +4 All tests passed |
| issue_1482_run_preflight_driver_test | green (batch `+8 -2`, the -2 are §3a's 1323-seam env failures) |
| issue_1323_hand_delta_driver_test | green (same batch) |
| issue_1330_make_subject_edit_fallback_test | green (batch `+4 All tests passed`) |
| bug_1331_make_adopted_re_drive_test | +8 All tests passed |
| bug_1345_placeholder_re_drive_test | +5 All tests passed* |
| bug_1430_refresh_evidence_test | +14 All tests passed |
| bug_964_finder_kind_taxonomy_test | +33 All tests passed |
| compose_command_test | +15 All tests passed |
| bug_1373 / bug_1374 / func_command / func_convergent / func_declared_signature / two_cycle / unified_journal / runner_test / refactor_command / verify_red_subdirectory / two-cycle drivers | All tests passed |

### 3a. Non-passing tests — ALL reproduced on the CLEAN tree (git stash
protocol), zero introduced by this fix

| failing test | failure | clean-tree result |
| ------------ | ------- | ----------------- |
| bug_1259 U4/U5/U6 | gen-emission `PathNotFoundException` (gen subprocess cannot emit in sandbox) | identical `+4 -3` on stashed tree |
| make_command_test U-829g/U-829h, A10, A11/U17, A15 | multi-step real pipelines hit sandbox resource kills (`resource-limit` exit -6 / SIGKILL -9) | identical 5 failures on stashed tree (`+33 -5`) |
| issue_1323_hand_delta_seam U-1323-3/U-1323-4 | same gen-emission `PathNotFoundException` | identical 2 failures on stashed tree |
| gen_command_test #871 pin | registry description echo drift (test/impl, unrelated to make gate) | identical `+17 -1` on stashed tree |
| services/behavior_test_writer_test #871 pin | same #871 drift | identical `+11 -1` on stashed tree |
| verify_red_command U23/A1 | pins pre-#1397 absolute-path evidence form | identical failure on stashed tree (`+25 -2` with smoke) |
| tdd_command_smoke | corpus help text drift | identical (same stash run) |
| bug_801 / bug_828 / bug_840 / bug_874 | resource kills + CLI drifts (doctor `--feature`, `--adopt` shape, verdict JSON) | all 4 fail on stashed tree (`+20 -14`) |
| bug_1345 B1+B2 | `resource-limit` exit -6 on the compose child | +5 All tests passed with `ZFA_TDD_STEP_MEMORY_KB=0` |

\* The 1345 compose child was killed by the pipeline runner's 2 GB
address-space guard (`pipeline_runner.dart defaultStepMemoryKb`); with
the guard disabled the suite is fully green — and B1+B2 passing PROVES
the widened gate does not pre-empt the legitimate compose re-entry (the
re-drive fixture is real-assertion, per its own comment).

## 4. Environment caveats (honest limitations of this host)

- No Flutter SDK: `example/` subpackage resolution fails (expected;
  out of scope for the CLI fix); `--exclude-tags flutter` used on dir
  runs, mirroring `tools/run_tests_chunked.sh`.
- Sandbox resource limits: real-subprocess pipelines (gen/func/compose
  children) intermittently hit `resource-limit` kills or isolate-spawn
  failures (`SendPort` subtype error). Every such failure above was
  reproduced on the UNMODIFIED tree before classification.
- Background processes are reaped between commands here; the sweeps ran
  as resumable segmented batches with kernel-cache cleanup between
  chunks (`.dart_tool/test/incremental_kernel.*`,
  `$TMPDIR/dart_test.kernel.*`), per the dart_test.yaml protocol.
- `specify init` / `specify extension add` were NOT re-run: `.specify/`
  is already fully initialized in this repo (init-options.json,
  integration.json, extensions.yml lists bug + tdd as installed) and
  the task forbids clobbering existing `.specify/templates|scripts`.
  The bug + TDD artifacts follow the existing per-bug conventions
  (`.specify/bugs/1512-acceptance-vacuous-composition/` shape).

## 5. Constraint compliance

- Fix scope: ONLY the vacuous-green detection scope in
  `make_command.dart` (gate widened unit → unit+acceptance).
  `contentIsVacuousGreen` untouched (verified: no diff in
  `vacuous_guard.dart`).
- Unit-lane detection unbroken: `bug_1259` U1/U2 green, `bug_1488` U1
  green, `make_command_1036` +5, `bug_1345` +5.
- `dart analyze`: no new warnings. `dart format`: tree clean.
