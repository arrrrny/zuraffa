# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- subject-hash: 97abbf42f6594698e2a0c2bd2f16e3429e7a4097e089a4d499a1109827f15712
- criterion: AC-1
- test: test/tdd/dart-core-lane-timeout-overflow/a1_test.dart
- command: `dart test /Users/arrrrny/Developer/zuraffa/test/tdd/dart-core-lane-timeout-overflow/a1_test.dart --plain-name "it reports the untagged heavyweight offenders — including"`
- exit: 1
- at: 2026-09-15T12:08:22.630675Z
- output:
```
00:00 +0: loading /Users/arrrrny/Developer/zuraffa/test/tdd/dart-core-lane-timeout-overflow/a1_test.dart                                                                                               
00:00 +0: A1 (AC-1) A1 — it reports the untagged heavyweight offenders — including                                                                                                                     
00:00 +0 -1: A1 (AC-1) A1 — it reports the untagged heavyweight offenders — including [E]                                                                                                              
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                             expect
  test/tdd/dart-core-lane-timeout-overflow/a1_test.dart 37:7  main.<fn>.<fn>
  

To run this test again: /usr/local/share/flutter/bin/cache/dart-sdk/bin/dart test /Users/arrrrny/Developer/zuraffa/test/tdd/dart-core-lane-timeout-overflow/a1_test.dart -p vm --plain-name 'A1 (AC-1) A1 — it reports the untagged heavyweight offenders — including'

00:00 +0 -1: Some tests failed.                                                                                                                                                                        

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 0cb1a739421b99736677b6100c788023f153d158be38c8aca294a0cdf37d31fa

## Loop mode: LLM-guided fallback (recorded 2026-09-15)

The deterministic driver stopped honestly at `A1:make`
(`result=stopped stopped_at=A1:make outcome=vacuous-green` — the acceptance
scenarios of a CI-budget bug are criterion-routed and carry no renderable
contract assertion; the same ZFA_MISSING engine-detection contract routed the
#1585 bug to this path). The A1 red entry above is the driver's certified
guard-only scaffolding; its `test/tdd/<feature>/` pair was removed from the
tree when the loop moved to the fallback path. The behaviors below were
driven red → green by hand on the real assertion surface
(`test/tier_integrity_test.dart`).

## Cycle: B5/B6 census pin (red)

- behavior: A1/U1/U2/U3 (FR-001..FR-003)
- kind: red
- classification: assertionFailure
- test: test/tier_integrity_test.dart (B5 + B6 added; B1–B4 untouched)
- command: `dart test test/tier_integrity_test.dart`
- exit: 1
- at: 2026-09-15 (pre-tag tree)
- evidence: ./red-evidence.md — `+5 -2`; B5 enumerated the untagged
  heavyweight offenders (spawn drivers, `*_compile_test` gates,
  self-hosting gates); B6 enumerated the tier-only regression files.

## Cycle: B5/B6 census pin (green)

- behavior: A1/U1/U2/U3 (FR-001..FR-003)
- kind: green
- command: `dart test test/tier_integrity_test.dart`
- exit: 0
- at: 2026-09-15 (post-tag tree)
- output:
```
00:00 +5: B5: the fast-lane budget census — no untagged heavyweight suite rides the dart_core lane (#1632)
00:00 +6: B6: every regression-tagged file is kept off the CI fast lane by `slow` or `e2e` (#1632)
00:00 +7: All tests passed!
```
- change applied: 124 tier-honest tag edits (72 `e2e`, 52 `slow`) per
  ./tag-plan.tsv + the B6-discovered tier-only leaks;
  `ci.yaml` dart_core step: `--concurrency=4` + truthful budget comment.

## Cycle: U4 / FR-004 (green)

- behavior: U4
- kind: green
- command: `dart analyze lib test --no-fatal-warnings`
- exit: 0
- output: 0 errors, 0 warnings (106 pre-existing style infos = master
  baseline); `dart format lib test` clean.

## Repairs driven while green (pre-existing master RED, blocking the lane)

- bug_1388_gen_traces_fingerprint_test.dart — born-red on master (single
  `stash` commit; red on every recent CI run). Test-side repair: guard-only
  pre-drift seed, faithful UnimplementedError stub, declared Layer Contracts
  surface, registered namespaced path read, B2 as idempotent two-gen reuse.
  → 2/2 green. Details in ./fix-notes-1388.md.
- pubignore_export_guard_test.dart — false positive on directive-shaped
  lines inside `_render(r'''…''')` template barrels (#1621). Repair: strip
  triple-quoted regions before scanning. → 3/3 green.
- Self-inflicted `library;` template corruption (first insertion pass was
  not string-aware; 223 files) — caught by the bug_1517 canary failing only
  on the dirty tree (clean stash-check passed), fully reverted to HEAD, tags
  re-applied string-aware; zero `-library;` removals vs HEAD in the final
  diff.


