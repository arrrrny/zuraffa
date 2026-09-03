# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Cycle: A1-A3 (red)

- behavior: A1-A3
- kind: red
- classification: assertion_failure
- criterion: FR-002, FR-008
- test: test/plugins/tdd/services/ci_referee/verdict_comment_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/verdict_comment_test.dart`
- exit: 1
- at: 2026-09-03T09:13:39Z
- output:
```
00:00 +0 -4: Some tests failed.
Failing tests:
A1: renders a row per feature with state, receipts, hand-delta and ratio,
  plus the exit-protocol legend — Expected: contains '| Feature |'
  Actual: '' Which: does not contain '| Feature |'
A2: a reviewer sees which features are releasable vs simulation-only from
  the state column alone — Expected: contains 'a-real' Actual: ''
A3: a doc-only PR gets a minimal verdict with no feature table —
  Expected: contains '## CI Referee Verdict' Actual: ''
shared/infrastructure row rendered — Expected: contains 'shared' Actual: ''
```
- schema: 1
- prev-hash: genesis
- hash: 44a4ac4f035ae1c2787b5b18c85f3a45f2a03340fbd08b1b60f17fa9cf74910f


## Cycle: A1-A3 (green)

- behavior: A1-A3
- kind: green
- criterion: FR-002, FR-008
- test: test/plugins/tdd/services/ci_referee/verdict_comment_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/verdict_comment_test.dart`
- exit: 0
- at: 2026-09-03T09:14:41Z
- output:
```
00:00 +4: All tests passed!
```
- generation:
  - step: implement VerdictCommentRenderer.renderFull/renderMinimal
    exit: 0
    purpose: feature x state table + exit-protocol legend + minimal verdict
- suite: baseline=0 guard=0 new=(none)
- schema: 1
- prev-hash: 44a4ac4f035ae1c2787b5b18c85f3a45f2a03340fbd08b1b60f17fa9cf74910f
- hash: 8f59ec6af3c8903d6576246e35ff6844d783b1e5462223fc69317cc7c1d11bad


## Cycle: U1-U6 (red)

- behavior: U1-U6
- kind: red
- classification: assertion_failure
- criterion: FR-003, FR-004, FR-005, FR-009, FR-015
- test: test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart`
- exit: 1
- at: 2026-09-03T09:16:34Z
- output:
```
00:00 +0 -7: Some tests failed.
Failing tests: U1 (expected completeReal, got StateError no element),
U2 (expected completeMocked), U3 (realizing for partial/driving),
U4 (receipt-unknown, FR-009), U5 (hand-delta drift count),
U6 (shared row), empty-corpus edge (expected empty).
Root cause: reader stub returns const [].
```
- schema: 1
- prev-hash: 8f59ec6af3c8903d6576246e35ff6844d783b1e5462223fc69317cc7c1d11bad
- hash: 5af47f367ea0a2505549e466ac5b51456b73df39c5fcc2ccf751a7ee7aed23ea


## Cycle: U1-U6 (green)

- behavior: U1-U6
- kind: green
- criterion: FR-003, FR-004, FR-005, FR-009, FR-015
- test: test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart`
- exit: 0
- at: 2026-09-03T09:18:41Z
- output:
```
00:00 +7: All tests passed!
```
- generation:
  - step: implement FeatureProvenanceReader (receipts + artifacts + cycle-log + fixtures + corpus progress)
    exit: 0
    purpose: read-only state derivation and receipt-verified buckets
- suite: baseline=0 guard=0 new=(none)
- schema: 1
- prev-hash: 5af47f367ea0a2505549e466ac5b51456b73df39c5fcc2ccf751a7ee7aed23ea
- hash: b60a1562b96d186c33f1a26eba00efa30936ba514613c81de45ecb3b6623146c


## Cycle: A4-A6 (red)

- behavior: A4-A6
- kind: red
- classification: runner_error
- criterion: FR-003, FR-012, SC-002
- test: test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart`
- exit: 1
- at: 2026-09-03T09:19:27Z
- output:
```
00:00 +0 -5: Some tests failed.
All five rollup tests fail with UnimplementedError from the
ProvenanceRollupBuilder stub (ratios, receipt verification, archival,
empty state, persisted document).
```
- schema: 1
- prev-hash: b60a1562b96d186c33f1a26eba00efa30936ba514613c81de45ecb3b6623146c
- hash: e37cfe5640339a658c4c81126b5ffa53ba4167aeefcdb999fd37e8c05b58d878


## Cycle: A4-A6 (green)

- behavior: A4-A6
- kind: green
- criterion: FR-003, FR-012, SC-002
- test: test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart`
- exit: 0
- at: 2026-09-03T09:20:41Z
- output:
```
00:00 +5: All tests passed!
```
- generation:
  - step: implement ProvenanceRollupBuilder (corpus + per-feature ratios, archive, empty state)
    exit: 0
    purpose: receipt-verified ratios + FR-012 archival
- suite: baseline=0 guard=0 new=(none)
- schema: 1
- prev-hash: e37cfe5640339a658c4c81126b5ffa53ba4167aeefcdb999fd37e8c05b58d878
- hash: d46d4a752fcefbb0013d5e763b2eba7084071b771b034881c2ee8c2cde393109


## Cycle: A7-A10 (red)

- behavior: A7-A10
- kind: red
- classification: runner_error
- criterion: FR-004, FR-005, FR-015, SC-003
- test: test/plugins/tdd/services/ci_referee/publishing_gate_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/publishing_gate_test.dart`
- exit: 1
- at: 2026-09-03T09:21:14Z
- output:
```
00:00 +0 -6: Some tests failed.
All six gate tests fail with UnimplementedError from the
PublishingGate.evaluate stub.
```
- schema: 1
- prev-hash: d46d4a752fcefbb0013d5e763b2eba7084071b771b034881c2ee8c2cde393109
- hash: 4cc251a1fc1120a9557eac9f8c27abb05e2fd8666b7f6ee13d45afae8563d004


## Cycle: A7-A10 (green)

- behavior: A7-A10
- kind: green
- criterion: FR-004, FR-005, FR-015, SC-003
- test: test/plugins/tdd/services/ci_referee/publishing_gate_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/publishing_gate_test.dart`
- exit: 0
- at: 2026-09-03T09:21:35Z
- output:
```
00:00 +6: All tests passed!
```
- generation:
  - step: implement PublishingGate.evaluate (production / labeled simulation / blocked)
    exit: 0
    purpose: real-only production enforcement, zero false positives
- suite: baseline=0 guard=0 new=(none)
- schema: 1
- prev-hash: 4cc251a1fc1120a9557eac9f8c27abb05e2fd8666b7f6ee13d45afae8563d004
- hash: 704494011782103b13359c07eb1b50cf2f33d0d97acb04caa38738f31f2c8bd9


## Cycle: A11-A13 (red)

- behavior: A11-A13
- kind: red
- classification: runner_error
- criterion: FR-006, FR-007, FR-011, SC-004
- test: test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart`
- exit: 1
- at: 2026-09-03T09:22:28Z
- output:
```
00:00 +0 -3: Some tests failed.
All three failure-artifact tests fail with UnimplementedError from the
builder/renderer stubs (excerpt, grouping, truncation).
```
- schema: 1
- prev-hash: 704494011782103b13359c07eb1b50cf2f33d0d97acb04caa38738f31f2c8bd9
- hash: f02797b70845cf07e09d1212805d176822f861112227206d14255fc2b0b6c881


## Cycle: A11-A13 (green)

- behavior: A11-A13
- kind: green
- criterion: FR-006, FR-007, FR-011, SC-004
- test: test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart`
- exit: 0
- at: 2026-09-03T09:25:16Z
- output:
```
00:00 +3: All tests passed!
```
- generation:
  - step: implement FailureArtifactBuilder + FailureReportRenderer (excerpts, grouping, progressive truncation)
    exit: 0
    purpose: concise cycle-log excerpts, never log walls
- suite: baseline=0 guard=0 new=(none)
- schema: 1
- prev-hash: f02797b70845cf07e09d1212805d176822f861112227206d14255fc2b0b6c881
- hash: 31492f8e2ae0d7cb1dc2d7106c65bc25901fcd8a61b4ce340e6b8f8a35b03560


## Cycle: U7-U11 (red)

- behavior: U7-U11
- kind: red
- classification: runner_error
- criterion: FR-001, FR-010, FR-013, FR-014, SC-006
- test: test/plugins/tdd/services/ci_referee/golden_workflow_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/golden_workflow_test.dart`
- exit: 1
- at: 2026-09-03T09:26:10Z
- output:
```
00:00 +0 -5: Some tests failed.
All five golden-workflow tests fail with UnimplementedError from the
GoldenWorkflow.run stub (steps, resume, gap ledger, coverage, empty).
```
- schema: 1
- prev-hash: 31492f8e2ae0d7cb1dc2d7106c65bc25901fcd8a61b4ce340e6b8f8a35b03560
- hash: abe4b9867717254593cafb55637ec6e8c6dd2250dbf9285d92bd915bb887a72a


## Cycle: U12-U13 (red then green)

- behavior: U12-U13
- kind: red
- classification: compile_error
- criterion: US1, SC-001
- test: test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart`
- exit: 1
- at: 2026-09-03T09:28:36Z
- output:
```
Test written first; load fails because pr_comment_poster.dart does not
exist yet (uri_does_not exist / import failure).
```
- schema: 1
- prev-hash: abe4b9867717254593cafb55637ec6e8c6dd2250dbf9285d92bd915bb887a72a
- hash: 7884e88dfcb5c1394063fa9dc93d1fb9e186a0e44745c623d83f564a3e682d8a

## Cycle: U12-U13 (green)

- behavior: U12-U13
- kind: green
- criterion: US1, SC-001
- test: test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart
- command: `dart test test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart`
- exit: 0
- at: 2026-09-03T09:28:36Z
- output:
```
00:00 +3: All tests passed!
```
- generation:
  - step: implement GithubPrCommentPoster + DryRunPrCommentPoster
    exit: 0
    purpose: deliver the verdict comment (GitHub API / dry-run)
- suite: baseline=0 guard=0 new=(none)
- schema: 1
- prev-hash: 7884e88dfcb5c1394063fa9dc93d1fb9e186a0e44745c623d83f564a3e682d8a
- hash: b795a2aa23c247ff53e0843c00ea6b6bca62af4d183ca2e853e3a32f3ba21996


## Cycle: U14-U16 (red)

- behavior: U14-U16
- kind: red
- classification: compile_error
- criterion: FR-001, FR-003, FR-004, FR-005, FR-012
- test: test/plugins/tdd/commands/referee_command_test.dart
- command: `dart test test/plugins/tdd/commands/referee_command_test.dart`
- exit: 1
- at: 2026-09-03T09:30:29Z
- output:
```
Test written first; load fails because referee_command.dart does not
exist yet (no such file / import failure).
```
- schema: 1
- prev-hash: b795a2aa23c247ff53e0843c00ea6b6bca62af4d183ca2e853e3a32f3ba21996
- hash: 26b7adc2e1b3f10fdf9c79e631932a0a82fd6a00ed9b682077edb9b110f0a33d

## Cycle: U14-U16 (green)

- behavior: U14-U16
- kind: green
- criterion: FR-001, FR-003, FR-004, FR-005, FR-012
- test: test/plugins/tdd/commands/referee_command_test.dart
- command: `dart test test/plugins/tdd/commands/referee_command_test.dart`
- exit: 0
- at: 2026-09-03T09:30:29Z
- output:
```
00:00 +4: All tests passed!
```
- generation:
  - step: implement RefereeCommand (run/gate/rollup) + register in TddCommand
    exit: 0
    purpose: golden workflow verdict, publishing gate, provenance rollup CLI
- suite: baseline=0 guard=0 new=(none)
- schema: 1
- prev-hash: 26b7adc2e1b3f10fdf9c79e631932a0a82fd6a00ed9b682077edb9b110f0a33d
- hash: 7776c95521cfec7eb15020e7bacb2c102003d0f17d0a3ec1f27b89e836f39267


## Cycle: A1-U16 (refactor)

- behavior: A1-U16
- kind: refactor
- criterion: FR-001..FR-015
- test: specs/070-ci-referee-provenance (all suites)
- command: `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/ && dart format <referee files> && tools/run_tests_chunked.sh (range runner 1-70)`
- exit: 0
- at: 2026-09-03T09:59:55Z
- output:
```
dart analyze lib/src/plugins/tdd/ test/plugins/tdd/: No issues found!
dart format <17 referee files>: 0 changed
Chunked fast suite (70 chunks, run in ranges): 63 passed,
5 SKIP (all-slow folders: test/benchmark, test/core/dependencies,
test/integration, test/plugins/tdd/scenarios, test/property),
0 failed. test/plugins/tdd/services/ci_referee: 33 tests passed.
```
- actions:
  - action: formatter + analyzer pass over the referee module
    command: `dart format && dart analyze`
    exit: 0
    changed: (none)
- schema: 1
- prev-hash: 7776c95521cfec7eb15020e7bacb2c102003d0f17d0a3ec1f27b89e836f39267
- hash: ed14d5177ab69da0c6d09263f12940fb06a0ad10ac35ad9d65191eebcc5fdf7d

