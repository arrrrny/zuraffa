# TDD cycle log — bug 1187 (test timeout scale)

Toolchain: Dart SDK 3.13.3 (stable), Linux x64. All commands run at the repo
root. Hardware note: the original red is a 2019 Intel Mac (issue #1187);
this cycle ran on fast cloud hardware where the cold compile fits the bare
budgets, so the red/green evidence below is at the mechanism level (the
scale contract), and the hardware-dependent reproduction is documented from
the issue's logs — stated honestly rather than claimed.

## RED (before the fix — helper without the scale)

Test-first: `test/helpers/zfa_test_timeout_scale_test.dart` was written and
run against the UNFIXED helper before `run_zfa_source.dart` was touched.

Command: `dart test test/helpers/zfa_test_timeout_scale_test.dart`

Observed (loading failure — the scale API does not exist yet):

```text
test/helpers/zfa_test_timeout_scale_test.dart:25:24: Error: Method not found: 'parseTimeoutScale'.
test/helpers/zfa_test_timeout_scale_test.dart:29:14: Error: Method not found: 'parseTimeoutScale'.
test/helpers/zfa_test_timeout_scale_test.dart:33:14: Error: Method not found: 'parseTimeoutScale'.
  ...
test/helpers/zfa_test_timeout_scale_test.dart:77:14: Error: Undefined name 'zfaDefaultChildTimeout'.
test/helpers/zfa_test_timeout_scale_test.dart:89:14: Error: Undefined name 'zfaCompileTimeout'.
test/helpers/zfa_test_timeout_scale_test.dart:98:9: Error: Method not found: 'scaleDuration'.
00:00 +0 -1: Some tests failed.
```

Baseline of the target suite on fast hardware pre-fix (documents that the
red is hardware-scale-dependent, not logic):

```text
$ dart test test/feature_flags --preset=all
00:36 +74: All tests passed!
```

## GREEN (after the fix)

### 1. Scale mechanism, environment plumbing proven both ways

`dart test test/helpers/zfa_test_timeout_scale_test.dart` run once per
environment value; every run green (9 tests each):

```text
scale='<unset>': 00:00 +9: All tests passed!      # 1.0 identity
scale='4':       00:00 +9: All tests passed!      # 4.0 multiplies budgets
scale='abc':     00:00 +9: All tests passed!      # invalid -> 1.0
scale='0.5':     00:00 +9: All tests passed!      # below 1.0 -> clamped 1.0
scale='2.5':     00:00 +9: All tests passed!      # decimal scale
```

An intermediate expectation bug in the NEW test file (expected
`Duration(milliseconds: 75)` = 75ms where 75 seconds was meant — actual
`0:01:15.000000` was correct) was fixed in the test, not the helper; the
helper's returned durations were never wrong.

### 2. Target suite green at scale 1 and 2

```text
$ dart test test/feature_flags --preset=all
00:06 +74: All tests passed!                        # scale unset
$ ZFA_TEST_TIMEOUT_SCALE=2 dart test test/feature_flags --preset=all
00:01 +74: All tests passed!                        # scale = 2
```

(Second run faster because the AOT cache from the first run is still valid;
`test/helpers` changes do not invalidate it — staleness keys on
`bin/zfa.dart` + `lib/src` only.)

### 3. Wiring correction found by the suite (recorded, not hidden)

The first wiring attempt passed `timeout:` to `setUpAll(...)`; the suite
failed to load:

```text
test/feature_flags/make_skip_test.dart:30:30: Error: No named parameter with the name 'timeout'.
```

A scratch experiment (`test/helpers/setupall_timeout_experiment_test.dart`,
run then deleted) proved the installed package:test does not apply
group/test `timeout:` declarations to `setUpAll` bodies (a 5s setUpAll
survived inside a 2s-timeout group). The compile window is therefore
bounded by the helper's internal `zfaCompileTimeout` — which now scales —
and the invalid `setUpAll` timeout args were removed. This is also why the
compile budget is the single lever that must scale (documented in
`issue.md`).

## REFACTOR

None required — the helper change is additive (new top-level API) plus a
nullable-default swap on `runZfaSource`; no call sites changed.

## 4. Red/green discrimination re-proof (git stash cycle)

With the fix stashed, the new tests fail; restored, they pass:

```text
$ git stash push test/helpers/run_zfa_source.dart
--- UNFIXED helper (stashed fix) ---
test/helpers/zfa_test_timeout_scale_test.dart:25:24: Error: Method not found: 'parseTimeoutScale'.
00:00 +0 -1: loading test/helpers/zfa_test_timeout_scale_test.dart [E]
$ git stash pop
--- FIXED helper restored ---
00:00 +9: All tests passed!
```
