# Bug Verification: `zfa tdd func` header claims now match the installed body state

- **Slug**: 1517-func-stale-honest-red-header
- **Tested**: 2026-09-11
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: PASS — red → green → full-suite, fresh from real runs; see tdd/verification.md

## Summary

The reported symptom is gone. After `zfa tdd func` fills a stub body with
a dummy, the subject file's header and doc comment claim the
scaffolded-dummy state (no `honest red`, no `UnimplementedError`, no
`MINIMAL COMPILABLE` anywhere in the file) while every contract trace
line survives verbatim, and the still-red scaffold keeps its (still true)
honest-red claims. The 3-test bug suite passes, the func-surface
regression suites pass, and the repo's disk-safe chunked fast suite
passes with zero failures.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| RED (pre-fix, commit deb68abe) | `dart test test/plugins/tdd/commands/bug_1517_func_stale_honest_red_header_test.dart` | fail as designed | `+1 -2`: U-1517-1 and U-1517-2 failed exactly on the stale claims (the printed subject shows `return true;` under the untouched honest-red header); the still-red guard U-1517-3 passed. |
| GREEN (post-fix) | same command | pass | `+3`: all three tests. Header/doc carry the scaffolded-dummy claim; traces byte-identical. |
| func-surface regressions | `dart test test/plugins/tdd/commands/func_command_test.dart test/plugins/tdd/commands/func_convergent_test.dart test/plugins/tdd/commands/func_declared_signature_test.dart test/plugins/tdd/json_flag_test.dart test/plugins/tdd/services/subject_writer_test.dart` | pass | 29/29. Covers the fill contract (U-F1..U-F9), the already-implemented fixed point and refusals (U7/U7b — the post-fill file stays byte-identical on re-run), declared-signature routing, `--json` envelope, and the gen templates the claims come from. |
| func-adjacent drivers | `dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart test/plugins/tdd/two_cycle_run_commands_test.dart test/plugins/tdd/scenarios/sc_017_real_pipeline_wires_subject_test.dart` | pass with pre-existing failures | 4 failures (bug_1259 U4/U5/U6, SC-017) — A/B-verified to fail IDENTICALLY on a stashed clean master (they spawn the real built `zfa` binary; `PathNotFoundException: lib/tdd/090-tdd-fixture/u_100_subject.dart` on master too). Not caused by this fix. |
| Full fast suite (chunked, disk-safe) | `tools/run_tests_chunked.sh` strategy, 103 chunks | pass | 98 OK · 5 SKIP (all-slow-tier folders: test/benchmark, test/core/proof, test/integration, test/plugins/tdd/scenarios, test/tdd/077-make-engine-preset) · **0 FAIL**. Kernel caches cleaned between chunks per the repo's standing disk policy. |
| Analyzer | `dart analyze lib/src/plugins/tdd/commands/func_command.dart test/plugins/tdd/commands/bug_1517_func_stale_honest_red_header_test.dart` | pass | `No issues found!` — no new warnings. |
| Formatting | `dart format` on both changed files, then re-run of the bug + func suites | pass | Formatted 2 files; 17/17 re-run green after formatting. |
| Still-red guard | U-1517-3 asserts the honest-red header remains when the scaffold keeps `throw UnimplementedError('implement per declared signature: …')` | pass | Proves the gate doesn't over-strip: claims are rewritten only when they are actually false. |
| Idempotency / replay | func_convergent U7 asserts the already-implemented re-run leaves the file byte-identical | pass | The rewrite runs only on the fill path, so `zfa replay` fixed-point semantics (spec 0806) are unchanged. |

## Residual Risks

- The claim sentences are matched against the exact SubjectWriter
  templates; if those templates are re-wrapped in the future the
  replacement would no-op — the safety net (drop any residual
  claim-marker comment line, trace keys exempt) covers that drift, and
  `subject_writer_test.dart` in the regression set pins the templates.
- `make_command.dart` has its own fill path with the same class of stale
  prose; explicitly out of scope here (one PR per bug, func surface
  only) and worth its own issue if the maintainers want the same
  reconciliation on the make lane.
