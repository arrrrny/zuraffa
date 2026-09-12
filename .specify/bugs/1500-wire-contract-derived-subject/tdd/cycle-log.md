# Cycle Log: 1500-wire-contract-derived-subject

## Cycle: U-1500 red (contract-derived stub refused)

- behavior: U-1500a..l
- kind: red
- classification: assertionFailure / runner-error
- test: test/plugins/tdd/bug_1500_wire_contract_subject_test.dart
- command: `dart test test/plugins/tdd/bug_1500_wire_contract_subject_test.dart`
- exit: 1
- at: 2026-09-11
- output:
```
Expected: <0>
  Actual: <1>
out: zfa tdd wire: behavior U2
   feature: 090-tdd-fixture
   entity: Task
zfa tdd wire: subject at "lib/u2_subject.dart" carries an UnimplementedError
in an unrecognized shape — refusing to rewrite a file this command did not
generate.
```
- result: 8 red (U-1500a,b,c,d,e,f,k,l) for the RIGHT reasons; 4 regression
  pins green pre-fix (U-1500g,h,i,j)

## Cycle: U-1500 green (declared-return wiring + MockData binding)

- behavior: U-1500a..l
- kind: green
- classification: pass
- test: test/plugins/tdd/bug_1500_wire_contract_subject_test.dart
- command: `dart test test/plugins/tdd/bug_1500_wire_contract_subject_test.dart test/plugins/tdd/wire_command_test.dart`
- exit: 0
- at: 2026-09-11
- output:
```
00:09 +27: All tests passed!
```
- result: 12/12 bug-1500 behaviors green; 15/15 pre-existing wire pins green

## Cycle: chunked suite (no new failures)

- behavior: regression sweep over the affected plugin surface
- kind: verify
- command: chunked `dart test` per folder with kernel-cache cleanup between
  chunks (disk-safe runner strategy per dart_test.yaml)
- at: 2026-09-11
- output:
```
test/plugins/tdd/commands  -> 02:13 +503: All tests passed!
test/plugins/tdd/services  -> 01:37 +855: All tests passed!
test/plugins/tdd (root)    -> 01:04 +472: All tests passed!
test/plugins/tdd/scenarios -> fully slow-tagged; excluded from the fast tier
                              by dart_test.yaml (exclude_tags: slow)
```
- result: 1,830 fast-tier tests, 0 failures

## Cycle: U-1500 review round (pull/1516 findings applied)

- behavior: U-1500m..u (+ U-W3 re-proved on macOS)
- kind: green
- classification: pass
- test: test/plugins/tdd/bug_1500_wire_contract_subject_test.dart +
  test/plugins/tdd/wire_command_test.dart
- command: `dart test test/plugins/tdd/bug_1500_wire_contract_subject_test.dart test/plugins/tdd/wire_command_test.dart`
- exit: 0
- at: 2026-09-11 (macOS)
- output:
```
05:16 +36: All tests passed!
```
- result: 21 bug-1500 behaviors (12 original + 9 review-round) green and
  15/15 wire pins green — including U-W3, which previously failed here
  (`+26 -1`) because a missing subject path was compared UNRESOLVED at a
  symlinked temp root (`/var` vs `/private/var`) and took the
  "outside the project root" branch. `dart analyze` over the wired
  mismatch fixtures is clean (no `cast_from_null_always_fails`).
