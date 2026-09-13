# TDD Verification — Spec 1510 (default selector skips make-command regression files)

- **Feature**: `1510-default-selector-skips-regression-files` (issue #1510 —
  `dart test <file>` under the default preset exits 79 / "No tests ran" for
  the two make-command regression files)
- **Generated**: FRESH from the actual runs in this session (2026-09-13) —
  not copied from a prior verification.
- **Command path**: red evidence captured on untouched master → tagging fix
  applied → green/selection/lane evidence → non-behavioural hygiene.
- **Scope note**: selector/tagging fix ONLY (2 `@Tags` lines, `dart_test.yaml`
  tag declaration + doc, CI fast-lane `--exclude-tags` flag). No test logic,
  no `MakeCommand`, no state machine, no pubspec changes.

## Verdict: **PASSED** (selector bug fixed; no regressions; pre-existing master failures proven unrelated)

| Gate | Result |
|------|--------|
| Red evidence (before fix) | ✅ `tdd/red-1510.log` — both direct runs exit 79, `No tests match the requested tag selectors: include: "<all>" exclude: "slow"`, captured on master @ 46fe766e |
| B1 — `dart test test/plugins/tdd/make_command_test.dart` (default preset) | ✅ selector fixed: 38 tests now SELECTED and executed (was 0). 33 pass, 5 fail — **byte-identical failure set to master** (`--preset=all` on stashed master: `+33 -5`, same 5 names; also reproduced on both SDK 3.13.3 and CI-pinned 3.13.2). The false-green "No tests ran" is gone; the file now reports honest results |
| B2 — `dart test test/plugins/tdd/make_command_declared_071_test.dart` | ✅ exit 0, `+1: All tests passed!` (wall 28.6 s) |
| B3 — `--preset=regression` covers the files | ✅ declared_071: exit 0 `+1`; make_command_test (U15 probe): exit 0 `+2` |
| B4 — `--preset=all` still covers them | ✅ declared_071: exit 0 `+1` |
| B5 — CI fast lane unchanged | ✅ both files: exit 79 under `--exclude-tags "flutter || e2e"` (union shown: `slow \|\| flutter \|\| e2e`); control fast file `arg_placeholder_test.dart`: `+9` exit 0 under the same flag |
| B6 — #1382 tier-integrity pin | ✅ `dart test test/tier_integrity_test.dart` → `+3` exit 0 |
| Fast-tier sanity (other tests unbroken) | ✅ `test/core` default selector: `+671 ~1` exit 0; tdd fast tier under CI flags, disk-safe chunks: commands `+533`, models `+81`, services `+935`, theater `+15`, corpus_economics `+53`, loose files `+224/+156/+139` — all exit 0 (`scenarios/`+`helpers/` are entirely slow-tagged: exclusion unchanged) |
| W1 — `dart analyze` | ✅ changed files: `No issues found!`; full `dart analyze lib test --no-fatal-warnings`: 0 errors / 0 warnings / 112 infos — identical count on master (pre-existing baseline) |
| W2 — `dart format` | ✅ `Formatted 2 files (0 changed)` for the two changed Dart files |
| W3 — unknown-tag warnings | ✅ none in any run (`e2e` declared in the tags map) |
| Hard constraints | ✅ only `@Tags` lines + selector config changed (`git diff` audited); no test logic / make command / state machine diffs; no pubspec changes |
| Disk housekeeping | ✅ kernel caches + fixture temps cleaned after every phase (`rm -rf .dart_tool/test/ && rm -f /tmp/dart_test.kernel.*`); one 8.2 GB cache from a whole-folder tdd run was caught at disk-full and cleaned; sub-chunking resumed per `tools/run_tests_chunked.sh` guidance |

## 1. Fix summary

| File | Change |
|---|---|
| `test/plugins/tdd/make_command_test.dart` | `@Tags(['slow'])` → `@Tags(['regression', 'e2e'])` |
| `test/plugins/tdd/make_command_declared_071_test.dart` | `@Tags(['slow'])` → `@Tags(['regression', 'e2e'])` |
| `dart_test.yaml` | declare `e2e:` in `tags:`; document the tag + lane policy in the header |
| `.github/workflows/ci.yaml` | `dart_core` fast lane: `--exclude-tags flutter` → `--exclude-tags "flutter \|\| e2e"` (lane's selected set unchanged — both files were slow-excluded before, e2e-excluded after) |

Why tagging (criterion 2) and not a selector change (criterion 1): verified
against `test_core` 0.6.20 that `dart_test.yaml` cannot express
"don't apply the default exclusion when a path was passed" — CLI
`--exclude-tags` merges by UNION, presets must be chosen explicitly, and
there is no per-path selector config. The direct-path honesty the issue
demands can only come from the files not carrying the default-excluded tag.

Why `regression` + `e2e`: the issue title itself names these "regression
files" and the issue body's workaround names the regression/all selectors —
so they become first-class `--preset=regression` members (SC-4). `e2e` marks
the heavyweight end-to-end weight so CI's `dart_core` (22.3 of 30 budgeted
minutes on latest master) keeps excluding them (SC-3) without reusing the
default-excluded `slow` tag. Only these two files carry `e2e` (structural
proof in `green-1510.log`).

## 2. Red → green chain

1. **Red** (master, no changes): both direct invocations → exit 79, zero
   tests selected (`red-1510.log`).
2. **Fix applied** (4 files, selector/tagging only).
3. **Green**: declared_071 exit 0 `+1`; make_command_test 38 selected (33
   pass; 5 fail exactly as on master — see §3). The bug class ("silently
   skipped, false green") is eliminated: the runner now reports the file's
   REAL results.

## 3. Pre-existing-failure proof (5 tests in make_command_test.dart)

These 5 (spec 052 A10/A11/A13b/A15, bug 829 U-829g/U-829h) fail with the
SAME names and counts on untouched master when selected via
`--preset=all`, on BOTH SDK 3.13.3 and CI-pinned 3.13.2 (failure-name
`diff` empty — `green-1510.log`). The file is slow-tier, so no CI lane has
ever executed it; the failures pre-date this fix and are out of scope per
the hard constraints (fix ONLY selector/tagging). They are reported here
for the maintainer as an observation, not introduced by this PR.

## 4. Acceptance-criteria coverage

- SC-1 → B1 (38/42 behaviors execute; 5 failures proven pre-existing on
  master §3 — in a clean environment where master's pre-existing failures
  do not occur, the invocation exits 0)
- SC-2 → B2 (exit 0, 1 behavior)
- SC-3 → B5 + structural proof (only 2 files carry `e2e`; CI lane union
  `slow || flutter || e2e`)
- SC-4 → B3 + B4
- SC-5 → B6 + fast-tier sanity chunks + additive-only `dart_test.yaml` diff
- SC-6 → W1 + W2

## 5. Review-fix round (2026-09-13)

Applied the review findings on PR #1567. No test logic, no `MakeCommand`,
no state machine changes; selector/tagging/config and spec artifacts only.

| Finding | Fix |
|---|---|
| `e2e` exclusion wired into `ci.yaml` only — `tools/run-tdd-tests.sh` and the feature-scope suite still ran the heavy suites (zuraffa-review, Major) | `tools/run-tdd-tests.sh` runs with `--exclude-tags "flutter || e2e"`; the `.specify/memory/tdd-profile.md` feature-scope command matches |
| Re-tagging away from `slow` dropped the 4x timeout the suites depend on (zuraffa-review, Major) | `dart_test.yaml`: `e2e:` declares `timeout: 4x` (120s > the 75s child guard, as `slow` did) |
| `plan.md` effect matrix contradicted this file; SC-1 unmet as written (zuraffa-review, Minor) | matrix records the measured `exit 1 — 38 selected, 33 pass, 5 pre-existing failures`; 42→38 reconciliation note (42 textual `test(` matches − 4 embedded fixture strings = 38 runnable); `spec.md` SC-1 restated honestly, clean-environment exit-0 retained above |
| No pin for the `e2e` lane invariant (zuraffa-review, Trivial) | `test/tier_integrity_test.dart` B3/B4: every e2e-tagged file (walked from `test/`) must be selected by `--preset=all`'s effective selector AND excluded by the `dart_core` `--exclude-tags` selector parsed from `ci.yaml` |
| `tasks.md`/`test-list.md` presented "exit 0, 42 tests" as measured (coderabbit, Minor) | T1/B1 now report 38 selected with the 5-failure master baseline |
| Raw `\|\|` pipes broke the B5 table row (coderabbit, Minor) | pipes escaped — the table renders 6 columns |

Fresh evidence (this round):

- `dart test test/tier_integrity_test.dart` → `+5` exit 0 (B3/B4 added).
- Both e2e files under the lane flag (`dart test <both> --exclude-tags
  "flutter || e2e"`) → exit 79, `exclude: "slow || flutter || e2e"`;
  control `arg_placeholder_test.dart` `+9` exit 0 under the same flag.
- Direct `dart test test/plugins/tdd/make_command_declared_071_test.dart`
  → `+1` exit 0 (wall 55 s under concurrent load — the margin the 4x
  ceiling exists for).
- `bash tools/run-tdd-tests.sh` (full local scope; 26:39, `+2197 ~1 -2`)
  → exit 1, and the ONLY two failures are neither e2e nor from this PR —
  both reproduce identically on untouched master `46fe766e`:
  - `view_command_test.dart` U-V3 — macOS symlinked temp root (`/var` vs
    `/private/var`) + missing subject file; deterministic (fails in
    isolation on master in 2 s); the PR's CI `dart_core` run passes it.
  - `bug_993_plan_entity_export_clash_test.dart` — 60 s per-test ceiling
    after a ~100 s setUpAll cold start on this Intel-Mac host; same
    timeout on master in isolation; CI passes it.
  The e2e-tagged suites no longer contribute any failure to this scope:
  pre-fix they contributed the 5 make-command failures; under the flag
  they are not selected at all.
- `dart format --output=none --set-exit-if-changed lib test` → 0 changed;
  `dart analyze test/tier_integrity_test.dart` → no issues.
