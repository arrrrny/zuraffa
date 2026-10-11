# Verification: 1407-make-gate-errors-only

**Verdict**: PASS

**Date**: 2026-09-11 | **Auditor**: spec-kit tdd-verify (cold-context audit; cloud agent)

## Phase 1 — Test-first evidence

Suite: `test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart` — real
`dart test` children through the fake zfa bin (TddFixture conventions).

| Behavior | Red evidence | Green evidence |
| -------- | ------------ | -------------- |
| A-1407-1 | RED pre-fix: the warnings-only refusal reaches the #737 tolerance and the make records `outcome=green-with-failed-build` — a failed-build label a mere warning must never produce (assert on `outcome=green` fails) | GREEN: `make: behavior=W3 outcome=green`, exit 0, the `warnings are non-blocking (issue #1407` verdict + the `unused_import` warning line logged, `## Cycle: W3 (green)` appended |
| A-1407-2 / U-1407-4 | RED pre-fix: identical `green-with-failed-build` shape on the engine lane | GREEN: `make: behavior=U3 outcome=green`, exit 0, same verdict line — the default (absent `analyze-gate` key) gate is errors-only |
| A-1407-3 | green-first characterization pin (the skip transition already reports `skipped`) | GREEN pre- and post-fix: `outcome=skipped`, exit 0 — the warning strictness matches the normal transition's (non-blocking in both) |
| U-1407-1 | green-first characterization pin (the red test decides) | GREEN: warnings-only refusal + red target test → `outcome=generation-error`, exit 1, no green entry, stub subject intact (the #1036 restore contract) |
| U-1407-2 | green-first characterization pin (#942 byte-identical) | GREEN: build verdict with 2 `error -` lines → `outcome=generation-error`, the `analyzer error(s)` note, no green entry, no non-blocking verdict |
| U-1407-3 | green-first pin pre-fix (today's behavior IS the legacy grading) | GREEN: profile `analyze-gate: 'warnings-blocking'` (quoted scalar) → the gate arm is skipped → the tolerance grades it → `outcome=green-with-failed-build`, exit 0 — the opt-in restores the pre-#1407 strictness |
| U-1407-5 | RED pre-fix (same shape as A-1407-2) | GREEN: explicit `analyze-gate: 'errors-only'` and unrecognized `analyze-gate: 'strict-everything'` both complete `outcome=green` — the opt-in is exactly `warnings-blocking` |
| U-1407-6 | partially RED pre-fix: (c)'s capped-logging asserts | GREEN: (a) no gate message → tolerance path (`green-with-failed-build`) unchanged; (b) 0-error message over raw `error -` lines → the shared parser wins, honest `generation-error` stands; (c) 12 warnings → verdict names `0 error(s), 12 warning(s)`, 10 lines logged (`u0`..`u9`), `u10` NOT logged, `... 2 more warning(s)` remainder |

Final suite state: `dart test --preset=all
test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart` → **8/8 passed**
(~1m30s, real `dart test` children). RED run (pre-fix): 4 failed / 4
passed — every intended red observed, every pin held.

## Phase 2 — Test smells

- No test interdependence: every test builds its own hermetic fixture
  (`TddFixture.create` + `dispose`); U-1407-5's loop re-seeds per value.
- No assertion-free tests: every behavior asserts the summary-line token,
  the exit code, the verdict-line text, and/or the cycle-log entry.
- No time bombs: fixed fixture data, no wall-clock dependence; the fake
  zfa bin is deterministic (`exitByArgv`/`stdoutByArgv` dispatch).
- Fixtures mirror the `make_command_test.dart` / `make_command_widget_939_test.dart`
  conventions (same helper names, same `makeArgs` shape).

## Phase 3 — Deliberate mutants (the riskiest new logic)

**Mutant M1** — the shared-parser cross-check dropped
(`_isWarningsOnlyBuildGateRefusal` returns true after the 0-error message
check without consulting `BuildCommand.analyzeReportsError`).

Result: **killed** — U-1407-6(b) flips red immediately (the 0-error
message over raw `error -` lines wrongly proceeds: exit 0 instead of the
honest non-zero stop). Reverted; suite green after revert.

**Mutant M2** — the profile opt-in clause dropped
(`!(await _profileWarningsBlocking(cwd))` removed from the gate condition).

Result: **killed** — U-1407-3 flips red immediately (the
`warnings-blocking` opt-in no longer restores the legacy grading; the make
reports `green` instead of `green-with-failed-build`). Reverted; suite
green after revert (8/8).

## Phase 4 — Real-analyze end-to-end proof

A throwaway package (`gate_proof_1407`, `/tmp/1407-gate-proof`) carrying the
issue's artifact in the gate's ACTUAL scope — the pre-existing unused
import lives under `lib/`, because the gate runs `dart analyze lib`
(`lib/src/commands/build_command.dart`, `verifyAnalyzeOrFail`) and a
`test/`-only warning can never reach its verdict.

Real `dart analyze lib` output in that package:

```
Analyzing lib...

warning - src/foo.dart:1:8 - Unused import: 'dart:math'. Try removing the import directive. - unused_import

1 issue found.
```

The REAL gate invoked against the same package
(`BuildCommand().verifyAnalyzeOrFail(projectRoot: '/tmp/1407-gate-proof')`,
run from this checkout) printed its own refusal — captured verbatim, not
hand-composed:

```
🔎 Running dart analyze on lib/...
Analyzing lib...

warning - src/foo.dart:1:8 - Unused import: 'dart:math'. Try removing the import directive. - unused_import

1 issue found.

❌ dart analyze reported 0 error(s) and 1 warning(s) — generated code does not compile cleanly.
   Fix the generator or run with --no-analyze to skip this check.
```

(gate returned `false`, exit 1 — the refusal this build output produces.)

Production classification (`BuildCommand.countAnalyzerIssues` — the #1035
single contract) on that captured output: `errors=0 warnings=1 infos=0`,
`analyzeReportsError=false` → the warnings-only shape; the gate-verdict
attribution is the REAL `❌ dart analyze reported 0 error(s) and 1
warning(s)` line above (not a hand-composed string), which engages the
#1407 non-blocking arm. **E2E PROOF: PASS** — a `lib/`-scoped pre-existing
warning under a real `dart analyze lib` run is classified non-blocking,
and the make proceeds on the behavior's own green receipt.

## Phase 5 — Acceptance-criteria coverage

- AC1 (gate on errors only) → A-1407-1 (green path), U-1407-1 (red test
  still stops honestly), U-1407-2 (errors keep the #942 refusal);
  SC-001/SC-002/SC-003 all proved.
- AC2 (consistent across lanes) → A-1407-1 (skin/widget lane) +
  A-1407-2 (engine/unit lane) — same outcome token, same verdict line;
  the branch lives in the one shared make grading block; SC-004 proved.
- AC3 (skip-transition consistency) → A-1407-3 (`skipped`) + A-1407-1
  (normal transition warnings non-blocking) — no strictness asymmetry
  within a run; FR-004.
- AC4 (backward compat via the tdd profile) → U-1407-3 (opt-in restores
  `green-with-failed-build`), U-1407-4/U-1407-5 (absent key, explicit
  `errors-only`, unrecognized value all default errors-only; a missing
  profile misfire-stops `runner-error` before any gate — the pre-existing
  profile contract, vacuously default); SC-005 proved.
- Hard constraint (fix only make_command.dart; engine cycle, verify-red,
  gen pipeline, dart analyze invocation untouched) → the diff touches
  `lib/src/plugins/tdd/commands/make_command.dart` only (plus the new
  test suite + spec artifacts); SC-006: `dart analyze` on the changed
  files reports 0 issues; `dart format` on the changed files is a no-op.

## Phase 6 — Regression sweep (honest accounting)

- `test/commands/build_command_unit_test.dart` (the shared parser pins):
  **48/48 passed**.
- `test/plugins/tdd/make_command_test.dart` (the #737/#942 tolerance
  family): **+33 -5** — the 5 failures are **pre-existing on the base
  commit** (verified by stashing the change and re-running: the pristine
  tree fails the IDENTICAL 5 tests — bug 657 verb/stub-path, U-829g,
  U-829h, A11/U17, A15 #737-compose-skip). Zero regressions introduced.
- `test/plugins/tdd/make_command_1036_test.dart` +
  `test/plugins/tdd/make_command_widget_939_test.dart` (the widget/skin
  make lane): **9/9 passed**.
- `test/plugins/tdd/bug_1258_skin_author_make_test.dart` (the skin
  authoring transition): **14/14 passed**.
- `dart format .` on the whole tree surfaces two PRE-EXISTING unformatted
  files (`tool/generate_openwiki_cli_docs.dart`,
  `example/test/tdd/004-login-ui/u1_test.dart` — both unformatted at the
  base commit, flagged here as unrelated; reverted out of this PR). The
  changed files are format-clean.

## Scope note (honest gaps)

- The full-repo test suite (heavy E2E tiers) was not run end-to-end on
  this cloud agent (kernel-cache/disk economics; the repo's own
  `dart_test.yaml` warns the full suite is NOT for cloud agents). The
  targeted seam suites above cover the touched surface: every suite that
  exercises the make grading paths is green except the five documented
  pre-existing failures.
- The warnings-blocking opt-in is read from the profile's Keys block and
  legacy frontmatter (the loader conventions); the profile WRITER
  (`tdd_profile_writer.dart`) is untouched per the hard constraint, so
  the key is documented in the spec/plan rather than emitted by `zfa
  setup`.
