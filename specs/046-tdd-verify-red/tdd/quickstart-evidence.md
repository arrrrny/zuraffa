# Quickstart Evidence — `zfa tdd verify-red`

Executed verbatim from [quickstart.md](../quickstart.md) on
2026-08-30, branch `046-tdd-verify-red`, commit `5232a80b`+
(after cycle 7). Manual fixture at a fresh temp project
(`/tmp/verify-red-demo-*`), driven through the REAL CLI entry point
(`dart run bin/zfa.dart tdd verify-red ...`), not the test suite.

## Scenario 1 — unit suite

```
$ dart test test/plugins/tdd/red_classifier_test.dart \
          test/plugins/tdd/runner_test.dart \
          test/plugins/tdd/verify_red_command_test.dart
01:41 +57: All tests passed!      # exit 0
```

## Scenario 2 — fixture-based certification (honest red)

Fixture: registry with `B-001` whose test asserts `returns 42` against a
stub returning `0`.

```
$ dart run bin/zfa.dart tdd verify-red B-001
zfa tdd verify-red: behavior B-001
   feature: 046-tdd-verify-red
   test: /tmp/verify-red-demo-8It0/test/b_001_test.dart
   command: dart test {file} --plain-name "{name}"
   runner exit: 1
   classification: assertion
   red evidence appended to specs/046-tdd-verify-red/tdd/cycle-log.md
verify-red: behavior=B-001 classification=assertion certified=true feature=046-tdd-verify-red
# EXIT: 0
```

Appended entry carries all 9 serialized fields (8 evidence fields plus the
required structural `kind` marker):

```
## Cycle: B-001 (red)
- behavior: B-001
- kind: red
- classification: assertionFailure
- criterion: FR-004
- test: /tmp/.../test/b_001_test.dart
- command: `dart test /tmp/.../test/b_001_test.dart --plain-name "returns 42 when invoked with no args"`
- exit: 1
- at: 2026-08-30T09:58:32.014523Z
- output:
  00:00 +0 -1: returns 42 when invoked with no args [E]
    Expected: <42>
    Actual: <0>
```

## Scenario 3 — dishonest-red rejection matrix

Five fixtures added to the same registry; the cycle log had B-001's
entry before the run and was byte-identical after (`cmp` → IDENTICAL).

```
B-003 (compile error in test)        -> exit=1  classification=compile-error     certified=false
B-004 (registry → missing file)      -> exit=1  classification=load-error       certified=false
B-005 (test already passes)          -> exit=1  classification=unexpected-green certified=false
B-006 (test skipped)                 -> exit=1  classification=skipped          certified=false
B-007 (name matches two tests)       -> exit=1  classification=runner-error     certified=false
```

## Scenario 4 — read-only guarantee

```
$ find test lib -type f -name "*.dart" | sort | xargs sha256sum > before.sums
$ dart run bin/zfa.dart tdd verify-red B-001
$ find test lib -type f -name "*.dart" | sort | xargs sha256sum > after.sums
$ diff before.sums after.sums && echo READ-ONLY-OK
READ-ONLY-OK
```

## Scenario 5 — ambiguity guard

Two gen'd behaviors (`B-001`, `B-002`) with no red evidence:

```
$ dart run bin/zfa.dart tdd verify-red
zfa tdd verify-red: ambiguous invocation: multiple behaviors have gen artifacts and no red evidence: B-001 (046-tdd-verify-red), B-002 (046-tdd-verify-red). Pass an explicit behavior id.
verify-red: behavior=- classification=unresolved certified=false feature=unknown
# EXIT: 1
```

## Result

All five scenarios behave exactly as quickstart.md specifies: exit 0
only on certification, named classifications with remediation hints on
every rejection, no evidence written for rejected runs, `test/`+`lib/`
untouched (sha256-verified), ambiguity never silently resolved.
