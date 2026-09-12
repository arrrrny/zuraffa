# TDD Verification: 1480-spec-grammar-propagation

- **Feature**: .specify/bugs/1480-spec-grammar-propagation
- **Verified**: 2026-09-11T00:40:00Z
- **Auditor**: LLM-guided fallback audit (speckit.tdd.verify fallback path — engine detection: ZFA_MISSING in this environment; `zfa tdd verify`'s mutation phase requires a zuraffa-wired consumer project)
- **Verdict**: PASS_WITH_GAPS

## Gate summary

| Check | Result | Evidence |
|-------|--------|----------|
| Test-first discipline (red before green) | PASS | Cycle-log records the RED runs BEFORE any fix code: 9 assertion failures (`plan_contracts_decoupled_1480_test` 4, `plan_unit_fallback_fail_fast_1480_test` 4, and `plan_marker_emission_1186`/writer compile failure `Couldn't find constructor 'SpecTemplateWriter'`) — then the implementation landed, then GREEN. The compile-level red for U3 is the honest red for a missing module. |
| RED-phase evidence | PASS | RED transcripts quoted in `tdd/cycle-log.md` (e.g. "00:00 +0 -4: Some tests failed."; "00:00 +1 -4"). All failures were the new #1480 tests; baseline suites were green pre-fix. |
| GREEN evidence | PASS | Final targeted run: 14/14 across the three new files (`00:01 +14: All tests passed!`). |
| Regression scope (tests for changed code) | PASS | `test/plugins/tdd/services/` 804/804; all 22 plan-adjacent legacy suites re-run green after fixture triage (chunked runs, disk-capped); `test/cli/writers/tdd/` green; func/gen/wire/runner chunks green (26/26, 59/59). |
| Acceptance-criteria coverage | PASS | A1 (contracts file plans declared) → U1+A1 tests; A2 (fail-fast refusal, no 28-minute dead-end) → A2/A2b/U2d tests + real-CLI exit=1 check; A3 (init leaves the grammar installed) → A3 test + real-CLI init check. U1–U5 all covered. |
| Test smells | PASS | No smoke tests: every assertion pins a REAL artifact or exit class through the real CLI entry (`CliRunner.runCapturing` + `lastDispatchedExitCode`, per the #1096 contract); refusal tests assert negative artifacts (no test-list.md, spec byte-identical); no tautologies; fixtures corrected when the gate caught a REAL untraced FR in my own fixture (U1+A1 first run) — the gate was right, the fixture was wrong. |
| Real-run provenance | PASS | Every verdict in this file comes from commands executed in this session (timestamps in cycle-log); nothing copied or back-dated. |
| Mutation testing | NOT RUN | Not zuraffa-wired here (no `.zfa.json`, no `zfa` binary; the repo's `mutation_test` wiring targets the tdd plugin's own feature specs, per `mutation-test.xml`). Surviving-mutant risk partially mitigated by the strong negative assertions (refusals, no-artifact, byte-identical spec) and the 804-test services suite. |

## Gaps (why not a bare PASS)

1. Mutation testing was not executed (environment limitation above).
2. The full monolithic `dart test` suite was not run as ONE invocation: two attempts hit the machine's 10-minute ceiling and the second filled the disk to 100% (kernel cache). Per the task's cloud-agent constraint ("only test what you changed — never the full suite") the regression was run CHUNKED instead, covering every suite that exercises the changed code paths; disk was restored to ≥13% free after each incident and cleaned between chunks.

## Remediation notes

- No code remediation required. The two pre-existing unformatted files on master (`tool/generate_openwiki_cli_docs.dart`, `example/test/tdd/004-login-ui/u1_test.dart`) were left untouched (out of scope; `dart format` on MY changed files reports 0 diffs).
- Suggested follow-up for the maintainers: wire a drift guard between `kZuraffaSpecTemplate` and the repo-local template (see fix.md Follow-ups).
