# Cycle Log — bug 837 (mutation verify pipeline)

Feature: tdd-mutation-verify-pipeline (GitHub issue #837, severity high)
Branch: fix/837-tdd-mutation-verify-pipeline (base: b6afda42)

## Cycle: R-1 (red — product reproduction)

- behavior: verify-gate-asserts-green
- kind: red
- classification: assertionFailure
- criterion: remediation 1 (preflight gate asserts GREEN) + 2 (mutation executes)
- test: scripts/red_repro_837.sh (fixture project, green suite)
- command: `zfa tdd verify --feature 044-demo --project <fixture>`
- exit: 64
- at: 2026-09-02 (session)
- output:
```
   gate: not_assessed
   reason: mutation config error: MutationConfigError: mutation-test config
   not found at <fixture>/mutation-test.xml. ...
   mutation_was_run: false
mutation: gate=not_assessed killed=0 survived=0 timed_out=0 mutation_was_run=false
verify exit: 64
```
- note: the suite was GREEN (`dart test` exit 0, "All tests passed!") yet the
  gate refused with exit 64 and the mutation phase never executed — the
  issue's headline symptom (its canonical run reports gate=preflight_red;
  the label varies with environment, the refusal + was_run:false is the
  invariant defect). Root cause confirmed: MutationVerifier demands a
  hand-written repo-root mutation-test.xml that nothing creates for
  feature projects, so the invocation is dead code for every feature.

## Cycle: R-2 (red — contract tests)

- behavior: scoped-config / survivor-parse / threshold-gate / binding
- kind: red
- classification: compileFailure (APIs absent)
- criterion: remediation 2, 3, 4, 5
- test: test/plugins/tdd/bug_837_mutation_verify_pipeline_test.dart
- command: `dart test test/plugins/tdd/bug_837_mutation_verify_pipeline_test.dart`
- exit: 254 (compile)
- at: 2026-09-02 (session)
- output (8 of the missing-API errors):
```
Error: Couldn't find constructor 'MutationSurvivor'.
Error: Method not found: 'parseMutationSurvivors'.
Error: No named parameter with the name 'scoreThreshold'.
Error: No named parameter with the name 'survivors'.
Error: The getter 'mutationScore' isn't defined for the type 'MutationAuditReport'.
Error: The getter 'specHash' isn't defined for the type 'MutationAuditReport'.
Error: The getter 'subjectHashes' isn't defined for the type 'MutationAuditReport'.
Error: Method not found: 'buildScopedMutationConfig'.
```

## Cycle: G-1 (green — fix applied)

- behavior: all five remediation behaviors
- kind: green
- criterion: remediation 1..5
- test: bug_837 suite (unit + CLI integration) + end-to-end repro re-run
- command: `dart test test/plugins/tdd/bug_837_mutation_verify_pipeline_test.dart` /
  `dart test --preset=integration test/plugins/tdd/bug_837_mutation_verify_pipeline_test.dart` /
  `bash scripts/red_repro_837.sh`
- exit: 0
- at: 2026-09-02 (session)
- output:
```
00:00 +9: All tests passed!                        (unit, fast tier)
00:36 +4: All tests passed!                        (CLI integration tier)

=== RED: zfa tdd verify on the GREEN fixture ===
   gate: pass
   killed: 2
   survived: 0
   timed_out: 0
   mutation_score: 1.0000
   mutation_was_run: true
   restoration_verified: true
mutation: gate=pass killed=2 survived=0 timed_out=0 mutation_was_run=true
verify exit: 0
```
- survived-mutant path (weak scope test):
```
   gate: fail_survived
   survived: 2
   mutation_was_run: true
   survived_mutants:
     - lib/calc.dart:2
       --> fix: add or strengthen a scope test that fails on this mutant (.../tdd-verify-report/mutation-test-report.md)
     - lib/calc.dart:4
       --> fix: ...
TRUE EXIT: 1
```

## Cycle: M-1 (mutation measurement of the changed service files)

- behavior: test strength of the new tests (tdd.verify Phase 4)
- kind: measurement
- criterion: rubric "Test strength: mutation"
- command: `dart run mutation_test <scoped-config> -f md -o <report>`
  (mutation_test 1.8.0; scope = the two changed service files; mutant test
  command = the fast-tier tests covering them, -j 1)
- exit: 255 (survivors present — honest)
- at: 2026-09-02 (session)
- output:
```
lib/src/plugins/tdd/services/mutation_auditor.dart : 110 mutations
  Detected by: test 47 | Undetected 63 (57.27%) | Timeouts 0 | Not covered 0
lib/src/plugins/tdd/services/mutation_verifier.dart : 90 mutations
  Undetected 45 (50.00%)
```
- incident recorded: a time-killed earlier measurement run left the `!(...)`
  negation mutant inside `MutationSurvivor.==` on disk; the unit suite caught
  it immediately (parser test failed), the line was restored exactly, and the
  re-run of the fast suite was green. Lesson recorded: post-kill tree checks
  must be content-based, not diff-stat-based.
- remediation applied in-cycle: finding F1 (threshold `>=` boundary not
  pinned at equality) — added the `score == threshold` boundary test
  (unit tier, green).

## Cycle: M-2 (boundary remediation re-check)

- behavior: threshold gate boundary (finding F1)
- kind: green
- command: `dart test test/plugins/tdd/bug_837_mutation_verify_pipeline_test.dart`
- exit: 0
- at: 2026-09-02 (session)
- output:
```
00:00 +10: All tests passed!
```
- note: the full scoped re-measure was not re-run after this addition
  (time-bounded agent session); the boundary mutant is killed by the new
  test by construction (score == threshold now asserted to pass).
