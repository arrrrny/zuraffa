---
feature: tdd-run-6col-deprecation-warning
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: d4cf1d06
behaviors: 4
proven: 0
likely: 3
test_after: 1
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: n/a # no mutation tool; deliberate mutants 3/3 caught
mutants_survived: 0
suite: fast tier 60/65 chunks passed + 5 no-test (exit 79 "no tests ran") skips, 0 failures (chunked per directory); slow tdd integration scenarios 6 passed / 0 failed; slow tdd driver+sc_013+sc_014 28 passed / 0 failed; dart analyze 0 issues; dart format . 0 changed
---

# TDD Verification: `zfa tdd run` 6-col deprecation warning — suppress for spec-sanctioned lists, correct migration text (#649)

**Verdict: PASS_WITH_GAPS.** The warning is split by dialect inside the
reader's single print site: the tdd extension's own hand-written 6-column
shape (specs/044–049, spec 050 FR-007) now reads with ZERO stderr output, and
gen's old private dialect keeps a one-time warning whose migration advice
describes a manual `test-list.md` format conversion to the 4-column shape and
never names `zfa tdd plan`. The red was observed in-session before the fix —
three scenario tests failed for the RIGHT reasons (stderr non-empty on a
spec-sanctioned list; advice containing `zfa tdd plan`) — and 3/3 deliberate
mutants on the new gate were caught. Gaps: test + fix land in one commit
(repo convention) so git ordering alone proves only `LIKELY`; the
no-parsing-change behavior is a TEST_AFTER regression guard (green suite,
no red-first run); and the audit is same-session, not a fresh-context
subagent pass.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| B1 — a spec-sanctioned extension-shape 6-col list (specs/049 verbatim, 42 rows, all DONE) runs with ZERO stderr output and completes | LIKELY | failed pre-fix for the RIGHT reason: `Expected: empty` stderr, actual = the deprecation note (sc_019 A6 strengthened assertion `run.stderr, isEmpty`; cycle: session transcript, red command `dart test test/plugins/tdd/scenarios/sc_019_legacy_dialect_migration_test.dart --preset=integration`). Manual repro on a temp project: exit 0, `result=complete done=42`, stderr 0 bytes post-fix. Test + fix in one commit → `LIKELY` not `PROVEN` |
| B2 — a gen-legacy 6-col list emits the corrected one-time warning: a MANUAL format conversion to the canonical 4-column shape, never `zfa tdd plan` | LIKELY | failed pre-fix for the RIGHT reason: `Expected: not contains 'zfa tdd plan'` on both the updated U3 (mixed-dialect list via real gen) and the new B1 (pure gen-legacy list, 2 rows, via real gen). Post-fix stderr: `Migrate by manually converting tdd/test-list.md to the canonical 4-column shape (id/behavior/traces/state); the 6-column dialect is accepted for one release.` |
| B3 — the warning is emitted at most once per file (per-file gate preserved) | LIKELY | B1's fixture carries TWO gen-legacy rows; `RegExp('deprecated 6-column test-list rows').allMatches(stderr), hasLength(1)` — failed pre-fix only on the advice text, passed the once-per-file assertion, and the gate-drop mutant (below) is caught by exactly this assertion. U3's mixed-dialect list (4-col + extension + gen rows) keeps the same hasLength(1) pin |
| B4 — row parsing is unchanged: both 6-col dialects still parse identically (kind-from-cell, shape-from-cell, target defaulting, escaped pipes) | TEST_AFTER | no red-first run — this is the bug's "do not change row parsing" constraint expressed as a guard: reader unit suite (`test/plugins/tdd/services/test_list_reader_test.dart`, 050 shim + 617-shim + escaped-pipe U15 cases) green, `test/plugins/tdd/models` 52, `test/plugins/tdd/services` 122, `test/plugins/tdd/commands` 7 all green post-fix |

No pre-existing test was weakened: the only touched existing assertions are
sc_019 U3's `expect(stderr, contains('zfa tdd plan'))` — REMOVED because it
asserted the exact incorrect advice this bug reports (the issue's Problem 2,
sanctioned by the fix assignment: "do not break tests asserting on the old
message string unless they are updated"), replaced with STRONGER assertions
(`isNot(contains('zfa tdd plan'))` + `contains('manual')` +
`contains('4-column')`); and sc_019 A6, STRENGTHENED with the zero-stderr
assertion. No assertion was loosened, no test skipped or renamed out of a
filter's reach, no threshold lowered.

## Deliberate mutants (no mutation tool in the profile; sampling on the changed gate)

| # | Mutant (one small change, restored exactly after) | Result |
| --- | --- | --- |
| 1 | Gate inverted: `dialect != _DeprecatedDialect.genLegacy` (warn for everyone EXCEPT legacy) | CAUGHT — 2 failures: A6 `Expected: empty` stderr (extension list warned), B1/U3 `Expected: contains 'deprecated 6-column test-list rows'` (legacy went silent) |
| 2 | Gate dropped: condition reduced to `dialect == _DeprecatedDialect.genLegacy`, per-file flag never set (warn per row) | CAUGHT — B1 `Expected: an object with length of <1>` (2 legacy rows → 2 notes) |
| 3 | Advice-text regression: mutant text smuggles `re-running \`zfa tdd plan\`` back into the migration sentence | CAUGHT — 2 failures: U3 + B1 `Expected: not contains 'zfa tdd plan'` |

Restored exactly after each mutant; suite re-run green after restoration
(sc_019 3/3). Sampling covers the changed branch's three behaviors; not
exhaustive over the file (the parse paths were not mutated — they are
explicitly out of scope for this fix).

## Findings

Ordered by severity. No `HIGH` findings.

| # | Severity | Finding | Evidence |
| --- | -------- | ------- | -------- |
| 1 | MED | Environment (not this change): `tools/run_tests_chunked.sh` loses its while-read stdin to `dart test` subprocesses after the `test/plugins/mcp` chunk — in this sandbox only 37 of 65 chunks ran under the stock invocation and the run printed `FAIL: one or more chunks failed.` with zero test failures in the log. The remaining 28 chunks were run with an instrumented copy (stdin from /dev/null, per-chunk exit codes): 26 PASS + 2 exit-79 no-test skips, 0 failures. The repo's own recorded bug `test-harness-subprocess-deadlock` names this family | stock log ends at chunk 37 `test/plugins/mcp` ("All tests passed!", +117) then `FAIL` with no `Some tests failed` anywhere; instrumented run covers chunks 38–65 |
| 2 | MED | Environment (not this change): `test/core/dependencies`, `test/integration`, `test/plugins/tdd/scenarios`, `test/property` are all-slow-tier folders — `dart test <dir>` exits 79 ("no tests ran") under the default fast tier, which the stock runner counts as chunk failure. Pre-existing on any cloud agent; unrelated to the fix (fix touches only `test_list_reader.dart` + one tdd scenario file). The slow tdd suites in those folders were run explicitly instead (see suite totals) | exit 79 reproduced directly: `dart test test/integration --exclude-tags flutter` → exit 79, `No tests match the requested tag selectors` |
| 3 | LOW | The grace-period cutoff ("accepted for one release", spec 050) remains a prose contract in the warning text and the reader doc comment; the assessment records the interpretation (one release from spec 050's introduction). A future spec must decide: extension shape graduates to canonical, or 6-col rows turn malformed (FR-011) | `test_list_reader.dart` doc comment lines 16-41 post-fix; `assessment.md` hard-constraints section |
| 4 | LOW | Same-session audit (Hard Rule 2): the tests and fix were written in this session, so the smell pass is not independent. Mitigation: the changed tests follow the file's established harness style (real-CLI subprocess, temp fixture, tearDown cleanup), and the mutant pass was executed blind against the assertions before any result was recorded | sc_019 diff; mutant log ordering in the session transcript |

## Traceability

| Issue criterion (expected behavior) | Behavior(s) | Test(s) |
| --- | --- | --- |
| The loop proceeds transparently for valid 6-column lists (spec 050) | B1 | sc_019 A6 zero-stderr assertion (real `zfa tdd run`, specs/049 list); manual repro, exit 0 + 0-byte stderr |
| The warning text gives correct migration advice (manual test-list conversion, not `zfa tdd plan`) | B2, B3 | sc_019 U3 (updated) + B1 (new): corrected-text positives, `zfa tdd plan` negative, once-per-file hasLength(1) |

Both directions covered: no criterion without a test, no new test tracing to
nothing. Every criterion is exercised through the REAL entry point
(`bin/zfa.dart` as a subprocess), not only through in-process doubles —
stderr is only observable there.

## What was not audited

- Mutation tooling: none in the profile; deliberate-mutant sampling only
  (3/3 caught), scoped to the changed gate. The reader's parse paths were
  not mutated (out of the fix's scope by the bug's hard constraints).
- Repo-wide slow tiers (`--preset=all` across the whole tree, plus the
  `regression`/`property`/`benchmark` presets): not run. The repo's own
  `dart_test.yaml` guidance forbids full `--preset=all` on small/disposable
  agents (multi-GB temp projects); an attempt scoped beyond
  `test/plugins/tdd` exceeded the session's command timeout while still
  COMPILING (its 32 "failures" were load-timeout artifacts of the kill — the
  same suites are green in the fast chunks). The slow suites that consume the
  changed file (tdd driver, tdd scenarios) were run individually and are
  green.
- Coverage: opt-in in this repo, not a gate; not run.
- The `tdd/verification.md` audit itself is committed alongside the fix per
  the repo convention; no remediation tasks section is appended (no feature
  `tasks.md` exists for a bug slug; findings 1/2 are environment notes for
  the repo's tooling owners, recorded here).
