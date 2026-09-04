# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: A1 (red)

- behavior: A1
- kind: red
- classification: assertionFailure
- evidence: A1 (AC-1) A1 — the host's route barrel is regenerated to include the feature's routes.
- criterion: AC-1
- test: /workspace/zuraffa/.worktrees/074-plugin-merge-contract/test/tdd/074-plugin-merge-contract/a1_test.dart
- command: `dart test /workspace/zuraffa/.worktrees/074-plugin-merge-contract/test/tdd/074-plugin-merge-contract/a1_test.dart --plain-name "the host's route barrel is regenerated to include the feature's routes."`
- exit: 1
- at: 2026-09-04T06:17:07.080113Z
- output:
```
00:00 +0: loading /workspace/zuraffa/.worktrees/074-plugin-merge-contract/test/tdd/074-plugin-merge-contract/a1_test.dart
00:00 +0: A1 (AC-1) A1 — the host's route barrel is regenerated to include the feature's routes.
00:00 +0 -1: A1 (AC-1) A1 — the host's route barrel is regenerated to include the feature's routes. [E]
  Expected: not <Instance of 'UnimplementedError'>
    Actual: UnimplementedError:<UnimplementedError: subject_a1 not implemented>
  
  package:matcher                                       expect
  test/tdd/074-plugin-merge-contract/a1_test.dart 30:7  main.<fn>.<fn>
  
00:00 +0 -1: Some tests failed.

Failing tests:
  /workspace/zuraffa/.worktrees/074-plugin-merge-contract/test/tdd/074-plugin-merge-contract/a1_test.dart: A1 (AC-1) A1 — the host's route barrel is regenerated to include the feature's routes.

Consider enabling the flag chain-stack-traces to receive more detailed exceptions.
For example, 'dart test --chain-stack-traces'.
```

- schema: 1
- prev-hash: genesis
- hash: 47801c41a4ad52bdbb2e2611c346923136c3e5488de6773658fa5cde595b7bff

