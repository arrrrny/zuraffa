---
feature: .specify/bugs/942-entity-name-collides-framework-export (bug #942, pinned per bug extension TDD mode)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: f3e46925
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 4/4 caught # scope: the #942 analyze-error gate + the green-with-failed-build outcome in make_command.dart, the mock-datasource hide clause, the entity create preflight — manual deliberate mutants, each killed by a named test
mutants_survived: 0
suite: "bug-737 group +4 (2 new #942 tests, 1 amended to the honest label); regression/issue_942 file +6; targeted generator regressions (354/417/463/294) +19; chunked fast suite: all 68 chunk dirs passed plus the two folders the chunker's >40-file split skips (test/commands 132 passed / 1 pre-existing pristine-identical failure, test/plugins/tdd/services 479 passed); dart analyze: identical to master (0 new issues, 47 pre-existing incl. 22 Flutter-dependent example/ errors); dart format: 0 diffs on every touched file (4 unrelated files carry pre-existing master format drift — left untouched)"
---

# TDD Verification: bug #942 — entity named Credentials collides with the framework export surface; make tolerates the failing build and records green

**Verdict: PASS.** The red→green cycle is real, every acceptance criterion is
covered by a test that failed against the pre-fix tree with the exact #942
signature, all four deliberate mutants were killed, and the generated-code
constraint ("generated code must compile") is proven end-to-end against a real
scratch package that depends on zuraffa and runs the real CLI.

Provenance note (honest): the runbook asserted `.specify/bugs/<slug>/issue.md`
and `assessment.md` were already committed for #942; no such records exist in
the tree (203 slugs searched) and GitHub issue #942 is not reachable via the
API from this session. The bug context was taken from the runbook's section-3
record itself (root cause, remediation menu, hard constraints) and verified
against the code; the two sibling records (`issue-337` entity/Flutter
collision, `issue-302` field/Value collision) supplied the repo's record
conventions. This file is the only artifact created under the slug.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| B1 — generated datasource/mock files hide the entity's own symbols (`<Name>`, `<Name>Patch`) from the framework barrel they import alongside the entity file | PROVEN | RED captured (pre-fix run, this session): all 4 generator-level tests failed — `Expected: contains 'import 'package:zuraffa/mock.dart' hide Credentials'` / `Actual: <emitted file without hide>`. GREEN post-fix: 6/6 in `test/regression/issue_942_entity_name_collides_framework_export_test.dart`. End-to-end proof: a scratch package (`dart create` + path dep on zuraffa) with `entity create -n Credentials` + `datasource create` + `make Credentials mock` produced **6 `ambiguous_import` errors** from `dart analyze` pre-fix and **0 errors / 0 ambiguous_import** post-fix on the regenerated tree. |
| B2 — a failed terminal `build` step whose output reports analyzer errors is NOT tolerated: the make stops with `generation-error` and appends no green entry | PROVEN | RED captured verbatim (pre-fix run): `stdoutByArgv` build failure carrying `error - ... ambiguous_import` lines + passing target test → `make: behavior=U3 outcome=skipped` + `## Cycle: U3 (green)` appended (the green-wash). GREEN post-fix: `outcome=generation-error`, exit non-zero, report line `terminal build step failed with 2 analyzer error(s) — a non-compiling generated tree is not tolerable noise (issue #942)`, no green entry. The gate reads the SAME parser (`BuildCommand.analyzeReportsError`, promoted from `@visibleForTesting` to the shared single contract for the analyzer error-line format) the build command's own post-build guard uses, so the two verdicts cannot drift. |
| B3 — a #737-tolerated build failure WITHOUT analyzer errors is recorded honestly as `green-with-failed-build` (never conflated with the #694 skip) | PROVEN | RED captured (pre-fix run): the amended bug-737 test failed — `Which: does not contain 'make: behavior=U3 outcome=green-with-failed-build'`, actual `outcome=skipped`. GREEN post-fix: `outcome=green-with-failed-build`, exit 0, green evidence appended; `StepRunner`'s make-success set accepts the new label (exit 0 + label agreement) so `zfa tdd run` flows past tolerated noise while the accounting stays distinguishable. |
| B4 — `entity create` preflights the name against the framework's export surface and refuses with a `--> fix:` rename suggestion before any file is written | PROVEN | RED captured (pre-fix run): `Expected: <1> Actual: <0>` — the colliding name was accepted (exit 0). GREEN post-fix: subprocess run via the real CLI exits 1, prints the collision source (`package:zuraffa/src/core/params/credentials.zorphy.dart`) and the `--> fix: rename the entity, e.g. 'zfa entity create CredentialsEntity --fields=...'` line (VISION §4), and writes no entity file; the non-colliding control (`UserCredentials`) still creates normally. Surface resolution is fail-open (package_config of the target project → CLI's own package root → skip): an unresolvable surface can never produce a false refusal. |
| B5 — non-colliding entity generation is unchanged in shape | PROVEN | The Order-control test: barrel import still emitted (with the entity's own symbols hidden — uniform deterministic codegen), `class OrderMockDataSource implements OrderDataSource` intact; targeted pre-existing generator regressions (issue 354/417/463/294, 19 tests) all pass against the modified builders. |

No assertion was weakened. One existing test was amended deliberately: the
bug-737 skip-transition test's expected outcome `skipped` →
`green-with-failed-build`, with the issue reference inline in the test name
and body (following the #694/#737 amendment precedents). The fixture helper
gained an additive `stdoutByArgv` knob (default empty — all pre-existing
callers unaffected).

## Deliberate mutants (all killed, run against the fixed tree)

| Mutant | Change | Killing test | Observed |
| --- | --- | --- | --- |
| M1 | make: `if (false && BuildCommand.analyzeReportsError(...))` — gate disabled | B2 (`analyzer errors is NOT tolerated`) | FAIL — make green-washed with `outcome=green-with-failed-build` instead of stopping |
| M2 | make: tolerated outcome `MakeOutcome.greenWithFailedBuild` → `MakeOutcome.skipped` | B3 (`green-with-failed-build` label) | FAIL — summary conflated the tolerated failure with the skip transition |
| M3 | mock datasource builder: `hide: barrelHide` dropped from the barrel import | B1 (`mock datasource hides Credentials`) | FAIL — emitted file lost the hide clause |
| M4 | entity command: refusal condition `if (false && ...)` — preflight disabled | B4 (`refuses a framework-exported name`) | FAIL — colliding name accepted (exit 0) |

## Acceptance criteria (from the #942 record)

1. **Generated code must compile** — proven end-to-end: scratch package,
   real CLI, real `dart analyze`: 6 `ambiguous_import` errors pre-fix → 0
   post-fix (0 errors of any kind on the generated tree).
2. **Green accounting must be honest** — the #737 tolerance now refuses
   analyzer-error build failures outright (B2) and records tolerated noise
   under a distinct, run-loop-recognized label (B3). The summary line can no
   longer say `skipped` for a make whose generated tree does not compile.
3. **One PR for this bug only** — 13 source/test files touched, all scoped to
   the two defects plus the errors-are-an-API preflight; the 4 unrelated
   files that `dart format` flagged carry pre-existing master drift and were
   reverted, not folded in.

## Suite accounting (real runs, this session)

- Chunked fast suite (`tools/run_tests_chunked.sh` semantics, chunk list from
  its `DRY_RUN`): **all 68 chunk dirs passed** (chunker restart-resilient
  driver, same kernel-cache hygiene; `test/plugins/tdd/scenarios` and
  `test/property` contain no fast-tier tests — 0 selected, exit 0, identical
  under the official runner).
- Chunker gap folders (its `>THRESHOLD` split skips dirs whose only subdir is
  a fixtures dir): `test/commands` → 132 passed, 1 failed —
  `corpus_command_test A2 loop-plannability`, verified **pristine-identical**
  (fails the same way on stashed master: spec-template `Template Version`
  marker contract drift, unrelated to this fix); `test/plugins/tdd/services`
  → 479 passed.
- `dart analyze`: byte-identical output to stashed master (47 issues, incl.
  22 `error -` lines from the Flutter-dependent `examples/`+`apps/` trees
  that cannot resolve the Flutter SDK on this agent — pre-existing, not
  introduced).
- `dart format`: 0 diffs on every file this PR touches.
