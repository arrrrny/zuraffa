# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 1653-init-opt-in (red)

- behavior: 1653-init-opt-in
- kind: red
- criterion: FR-001, FR-002, FR-003, FR-004, FR-005
- test: test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart`
- exit: 1
- at: 2026-09-16T00:10:00.000Z
- output:
```
test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart:20:8: Error: Error when reading 'lib/src/plugins/tdd/services/pub_pre_resolver.dart': No such file or directory   test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart:69:57: Error: Cannot invoke a non-'const' factory where a const expression is expected.   test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart:124:11: Error: No named parameter with the name 'includeMutationTest'.   test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart:139:11: Error: No named parameter with the name 'includeMutationTest'.   test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart:201:24: Error: Method not found: 'PubPreResolver'.   test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart:201:11: Error: No named parameter with the name 'preResolver'.   test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart:222:24: Error: Method not found: 'PubPreResolver'.   test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart:222:11: Error: No named parameter with the name 'preResolver'.
```
- schema: 1
- prev-hash: genesis
- hash: 81ec9e07c776b5a65aa820aacfd21c5e0fe6c6cd9f8b25b26e1e4fbad7f1655b

## Cycle: 1653-refactor-timings (red)

- behavior: 1653-refactor-timings
- kind: red
- criterion: FR-006, FR-007, FR-008
- test: test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart`
- exit: 1
- at: 2026-09-16T00:11:00.000Z
- output:
```
test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart:121:13: Error: No named parameter with the name 'duration'.   test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart:124:9: Error: No named parameter with the name 'phaseDurations'.   test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart:162:17: Error: No named parameter with the name 'duration'.   test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart:165:13: Error: No named parameter with the name 'phaseDurations'.   test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart:68:20: Error: The getter 'duration' isn't defined for the type 'RefactorAction'.   test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart:75:20: Error: The getter 'duration' isn't defined for the type 'RefactorAction'.
```
- schema: 1
- prev-hash: genesis
- hash: 58ed829ee474f262e27411bc4a4fb52d02f0caa7a6fd5db5c5cf33df2ea3b24f

## Cycle: 1653-init-opt-in (green)

- behavior: 1653-init-opt-in
- kind: green
- criterion: FR-001, FR-002, FR-003, FR-004, FR-005
- test: test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart`
- exit: 0
- at: 2026-09-16T01:30:00.000Z
- output:
```
16/16 passed (+16: All tests passed!) — default init injects no mutation_test; --mutation injects ^1.8.0; pre-resolve fires on newly-added deps (dart pub get --no-example, duration printed), skips on idempotent pass, misfires on non-zero resolver exit, warns on missing binary; unavailable-semantics hardening test added from the mutation survivor.
```
- schema: 1
- prev-hash: 81ec9e07c776b5a65aa820aacfd21c5e0fe6c6cd9f8b25b26e1e4fbad7f1655b
- hash: 15298455abbcb5de96697bb6d9ee0e0922d4987dcd30d894621b8cd3e0b1e61e

## Cycle: 1653-refactor-timings (green)

- behavior: 1653-refactor-timings
- kind: green
- criterion: FR-006, FR-007, FR-008
- test: test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart
- command: `dart test --preset=all test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart`
- exit: 0
- at: 2026-09-16T01:31:00.000Z
- output:
```
5/5 passed (+5: All tests passed!) — per-pass duration recorded (>= the programmed delay), null for scheduling-skipped; - phases: + duration: render additively; legacy entry chain hash unchanged; E2E green refactor prints 'phase timings: preflight=6.8s registry=0.3s re-proof=...' and the receipt carries them; FR-009 summary line byte-unchanged.
```
- schema: 1
- prev-hash: 58ed829ee474f262e27411bc4a4fb52d02f0caa7a6fd5db5c5cf33df2ea3b24f
- hash: 6012d626b8afeffba9e7cc13cba625b1edaccdac1e7adaf045cfee5066fa8d94

