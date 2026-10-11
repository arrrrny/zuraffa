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
scaffolded-dummy state (no `honest red`, no `MINIMAL COMPILABLE`, and no
`UnimplementedError` in the non-trace claim prose — a preserved contract
trace line such as `description:` may still mention the marker) while
every contract trace line survives verbatim, and the still-red scaffold
keeps its (still true) honest-red claims. The 3-test bug suite passes
(now 5 tests after the review round), the func-surface regression suites
pass, and the repo's disk-safe chunked fast suite passes with zero
failures.

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
| Review round (PR #1523) | `dart test test/plugins/tdd/commands/bug_1517_func_stale_honest_red_header_test.dart` | pass | `+5`: U-1517-1 extended with a no-trailing-whitespace assertion; U-1517-4 (acceptance-scenario variant, fixture rendered by `SubjectWriter`) and U-1517-5 (hand-authored note survives; fallback note inserted) added. |
| Review round regressions | `dart test` over the func/gen/subject-writer surface (9 files) | pass | 46/46. Writer output verified byte-identical before/after the `StubClaims` extraction (rendered-render diff). |
| Review round analyzer / format | `dart analyze` on the three changed files; `dart format --set-exit-if-changed lib test` | pass | `No issues found!`; 2556 files, 0 changed. |

## Residual Risks

- The claim sentences are matched against the exact SubjectWriter
  templates; a wording change there is impossible to miss in production
  (`func_command` consumes `SubjectWriter`'s own `StubClaims`), and the
  pattern builder still tolerates re-wrapping. The residual-marker sweep
  (drop any claim-marker comment line, trace keys exempt) is scoped to
  the generated header and declaration doc-comment blocks, so it cannot
  delete a hand-authored note elsewhere in the file.
- `make_command.dart` has its own fill path with the same class of stale
  prose; explicitly out of scope here (one PR per bug, func surface
  only) and worth its own issue if the maintainers want the same
  reconciliation on the make lane.
