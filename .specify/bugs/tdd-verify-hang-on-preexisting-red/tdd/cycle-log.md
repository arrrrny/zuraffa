# Cycle Log — bug 924 (verify hangs on full-suite baseline with pre-existing red)

Feature: tdd-verify-hang-on-preexisting-red (GitHub issue #924, severity high)
Branch: fix/924-verify-hang-on-preexisting-red (base: 31b3ad62)

## Cycle: R-1 (red — product reproduction, behavioral)

- behavior: config-first-not-assessed
- kind: red
- classification: assertionFailure
- criterion: remediation 3 (`gate: not_assessed` returned immediately without running the suite)
- test: test/plugins/tdd/bug_924_red_probe_test.dart (temporary probe, existing-API only; deleted after the fix landed — the durable coverage lives in bug_924_verify_preflight_test.dart)
- command: `dart test test/plugins/tdd/bug_924_red_probe_test.dart`
- exit: 1
- at: 2026-09-03 (session, pre-fix master @ 31b3ad62)
- output:
```
Expected: contains 'mutation config'
  Actual: 'mutation audit failed: FileSystemException: Creation failed, path = '/tmp/bug924_probe_QUIRGQ/.dart_tool' (OS Error: Not a directory, errno = 20)'
   Which: does not contain 'mutation config'
```
- note: the fixture models the issue's forklift state — a registered scope
  pair and `.dart_tool` unresolvable so the scoped mutation config cannot be
  written (the `mutation-test.xml not found` per-preset lookup failure).
  On pre-fix master the auditor ran the preflight FIRST (the probe's
  runPreflight override was invoked), then surfaced the config failure as a
  generic `mutation audit failed: …` — the wasted-baseline + unreachable-
  verdict ordering bug #924 reports. The probe asserted the post-fix
  contract (reason names the config; preflight never invoked) and failed on
  both.

## Cycle: R-2 (red — contract tests, new APIs absent)

- behavior: per-behavior-preflight / preflight-scope-ran diagnostics
- kind: red
- classification: compileFailure (APIs absent)
- criterion: remediation 2 (per-behavior preflight when the feature has its own test files)
- test: test/plugins/tdd/bug_924_verify_preflight_test.dart
- command: `dart test test/plugins/tdd/bug_924_verify_preflight_test.dart`
- exit: 254 (compile)
- at: 2026-09-03 (session, pre-fix master @ 31b3ad62)
- output (the missing-API errors):
```
Error: No named parameter with the name 'runPreflightBehavior'.
Error: The getter 'preflightScopeRan' isn't defined for the type 'MutationAuditReport'.
```
- note: the same file also pins the CLI contracts (V1: config error verdict
  reached immediately even with a HANGING feature test — on master this
  showed as `gate=preflight_red` / `preflight timed out` instead of the
  config-not_assessed; V2: `preflight_scope_ran` diagnostics listing exactly
  the files the fail-fast preflight executed).

## Cycle: G-1 (green — fix applied)

- behavior: all three remediation behaviors
- kind: green
- criterion: remediation 1, 2, 3
- test: bug_924 suite (fast unit tier + CLI integration tier) + R-1 probe re-run
- command: `dart test test/plugins/tdd/bug_924_verify_preflight_test.dart` /
  `dart test --preset=integration test/plugins/tdd/bug_924_verify_preflight_test.dart`
- exit: 0
- at: 2026-09-03 (session)
- output:
```
00:00 +7: All tests passed!     (fast tier: 5 remediation + 2 M-1 classification pins)
00:08 +2: All tests passed!     (CLI integration tier: V1 + V2)
```
- note: V1 proves the config verdict is reached with a hanging feature test
  in the fixture (the suite never runs — the pre-#924 path would have hung
  until the `--timeout 0.2` budget killed it and reported `preflight timed
  out`); V2 proves the per-behavior fail-fast (red B-001 stops the run;
  verification.md lists `preflight_scope_ran` with B-001 only, never B-002).

## Cycle: G-2 (regression — no new failures elsewhere)

- behavior: full fast-tier suite, chunked
- kind: green
- command: per-folder chunks per tools/run_tests_chunked.sh (kernel cache cleared between chunks)
- exit: 0
- at: 2026-09-03 (session)
- output:
```
test/plugins/tdd/: 02:05 +831: All tests passed!   (829 pre-existing + 2 new after M-1 refactor)
all other chunks: OK (3 folders SKIP by design: every test is slow-tier-tagged)
FAIL: none
```

## Cycle: M-1 (mutation finding + in-cycle remediation)

- behavior: preflightFileResultFromProcess classification
- kind: red → green
- classification: survivedMutant (MED) → killed after refactor
- criterion: remediation 2 (the per-behavior spawn's green/red classification)
- evidence: mutation_test 1.8.0 scoped to
  `lib/src/plugins/tdd/services/mutation_auditor.dart`, mutant test command
  `dart test test/plugins/tdd/services/mutation_auditor_test.dart
  test/plugins/tdd/bug_924_verify_preflight_test.dart
  test/plugins/tdd/bug_837_mutation_verify_pipeline_test.dart` (fast tier —
  the CLI integration tier is excluded by dart_test.yaml by design)
- pre-remediation: 64/133 killed; the `exitCode == 0` → `!=` mutant at
  `_runPreflightTestFile` SURVIVED (the real spawn path is only driven by
  the integration tier, which the mutant command cannot include)
- remediation: verdict classification factored into the top-level
  `preflightFileResultFromProcess` + fast-tier pins (exit 0 → green;
  1/2/254/255 → red with exit preserved)
- post-remediation re-run: 65/133 killed (48.87%), 0 timeouts; the M-1
  mutant is killed; all 68 remaining survivors triaged LOW/equivalent:
  ~35 markdown literals + `!= null` render guards in `toMarkdown()`
  (decisive gate fields are pinned by V1/V2 exact-string asserts),
  `<=`→`<` budget boundary (equivalent verdict — a zero-remaining child is
  killed by runTimed's zero timeout → same timed-out phase),
  cosmetic `---` separator and diagnostic strings, self-consistent
  output-dir/config-path literals (writer and reader share the constant),
  XML whitespace literals in `buildScopedMutationConfig` (still parseable).
