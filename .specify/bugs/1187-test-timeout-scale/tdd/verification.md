# TDD verification — bug 1187 (test timeout scale)

- **Feature/bug dir:** `.specify/bugs/1187-test-timeout-scale/`
- **Branch:** `fix/1187-test-timeout-scale`
- **Toolchain:** Dart SDK 3.13.3 (stable), Linux x64
- **Engine dispatch note:** `zfa tdd verify` requires a pinned feature
  (`spec.md` + `tdd/test-list.md` synthesized by `bug.fix` in TDD mode).
  This fix was driven directly on the bug branch, so per
  `speckit.tdd.verify` the fallback LLM-guided audit applies. Every claim
  below is backed by an actually executed command and its real output
  (nothing is projected or assumed). Hardware caveat, stated up front: the
  original red is a 2019 Intel Mac; this cycle ran on fast cloud hardware
  where the cold compile fits the bare budgets, so the suite-level red
  could not be reproduced locally — the red/green evidence is at the
  mechanism level (the scale contract), which is what the fix adds, plus
  the issue's own hardware logs as the reported symptom.

## 1. Preflight — suite state

Fast-tier suite state at audit time (chunked runner semantics,
`--exclude-tags flutter`, kernel-cache cleaning between chunks):

| Suite | Command | Result |
|---|---|---|
| target suite (slow tier) | `dart test test/feature_flags --preset=all` | 74/74 passed (scale unset; re-run green with `ZFA_TEST_TIMEOUT_SCALE=2`) |
| scale mechanism (fast tier) | `dart test test/helpers/zfa_test_timeout_scale_test.dart` | 9/9 passed, ×5 environment values (unset, `4`, `abc`, `0.5`, `2.5`) |
| full fast suite | chunked runner semantics, resumed via identical-semantics driver (`run_chunked_resume_1187.sh`: same per-chunk command `dart test "$d" --exclude-tags flutter < /dev/null`, same `clean_kernel`) | **90/90 chunks: 83 PASS + 7 SKIP** (folders whose tests are all slow-tagged — by-design skips, e.g. `test/benchmark`, `test/integration`, `test/tdd/077-make-engine-preset`) |
| `dart analyze` | `dart analyze` | 0 issues in the changed files; all 31 errors are pre-existing `uri_does_not_exist` in `examples/todo_tdd/` (missing generated artifacts, needs Flutter; unchanged from baseline) |
| `dart format .` | `dart format .` | 2333 files formatted, 3 changed: the new test file + 2 edited suite files (committed with the fix) and 1 pre-existing drift file (`examples/mcp_demo/lib/src/mcp/tools.dart`, committed separately as `style:` so the gate "zero remaining formatting diffs after `dart format .`" holds) |

## 2. Test-first evidence

- `test/helpers/zfa_test_timeout_scale_test.dart` (9 tests, fast tier) was
  written and run against the UNFIXED helper before
  `test/helpers/run_zfa_source.dart` was modified; it failed to load
  (RED evidence in `tdd/cycle-log.md` §RED).
- Red/green discrimination was re-proven after the final test edits by
  `git stash push test/helpers/run_zfa_source.dart` → run (loading
  failure: `Method not found: 'parseTimeoutScale'`) → `git stash pop` →
  run (9/9 passed).
- Commit layout: test + fix land in one commit on the bug branch; the
  cycle log is the test-first evidence record.

## 3. Red-phase evidence (what the tests catch)

Pre-fix run of the new test file (the scale API does not exist):

```text
test/helpers/zfa_test_timeout_scale_test.dart:25:24: Error: Method not found: 'parseTimeoutScale'.
test/helpers/zfa_test_timeout_scale_test.dart:77:14: Error: Undefined name 'zfaDefaultChildTimeout'.
test/helpers/zfa_test_timeout_scale_test.dart:89:14: Error: Undefined name 'zfaCompileTimeout'.
test/helpers/zfa_test_timeout_scale_test.dart:98:9: Error: Method not found: 'scaleDuration'.
00:00 +0 -1: Some tests failed.
```

The hardware symptom this mechanism addresses (from issue #1187's own
logs, not reproducible on fast hardware): `TimeoutException after
0:00:30.000000` and `TimeoutException after 0:01:15.000000: zfa
subprocess exceeded its 75s child timeout` across 9+ feature_flags tests
with no logic failures. A baseline pre-fix run here (`dart test
test/feature_flags --preset=all` → 74/74 in 36s) documents that the red is
environment-scale-dependent, consistent with the issue's framing.

## 4. Mutation check (real run)

Mutant — clamp removed from `parseTimeoutScale`
(`sed 's|  if (value < 1.0) return 1.0;|  // MUTANT: clamp removed|'`):

- Run: `dart test test/helpers/zfa_test_timeout_scale_test.dart`
- Result: **1 test FAILED → mutant KILLED**:

```text
00:00 +3 -1: parseTimeoutScale values below 1.0 clamp up to 1.0 (never tighten budgets) [E]
  Expected: <1.0>
    Actual: <0.5>
```

- Restore fixed file → run → `00:00 +9: All tests passed!`

Mutants not pursued (recorded honestly):

- *budget base change (75s→76s in `zfaDefaultChildTimeout`)*: the B7 test
  asserts the exact 75s×scale product, so it would catch this; not run
  because the clamp mutant already demonstrates kill power for the parser
  surface and the budget product is asserted literally by B7/B8.
- *remove env read (`Platform.environment` lookup)*: would fail B6
  (`matches the environment the test process started with`) in the
  `ZFA_TEST_TIMEOUT_SCALE=4` run; not run for the same reason — the
  multi-environment runs (§5) already exercise the env plumbing end-to-end
  five times.

## 5. Green-phase evidence

### 5.1 Scale mechanism — environment plumbing proven both ways

`dart test test/helpers/zfa_test_timeout_scale_test.dart` per environment
value; 9/9 green each:

```text
scale='<unset>': 00:00 +9: All tests passed!      # 1.0 identity
scale='4':       00:00 +9: All tests passed!      # 4.0 multiplies budgets
scale='abc':     00:00 +9: All tests passed!      # invalid -> 1.0
scale='0.5':     00:00 +9: All tests passed!      # below 1.0 -> clamped 1.0
scale='2.5':     00:00 +9: All tests passed!      # decimal scale
```

### 5.2 Target suite — green at scale 1 and 2, semantics unchanged

```text
$ dart test test/feature_flags --preset=all
00:06 +74: All tests passed!                        # scale unset
$ ZFA_TEST_TIMEOUT_SCALE=2 dart test test/feature_flags --preset=all
00:01 +74: All tests passed!                        # scale = 2
```

No assertion was edited in any pre-existing test; the only suite-file
changes are `Timeout` declarations routed through `scaleDuration(...)`
(3-minute base ceilings that grow with the child guard) — the diff is
reviewable as budget-only.

### 5.3 Wiring correction found by the suite (recorded, not hidden)

The first wiring attempt passed `timeout:` to `setUpAll(...)`; the suite
failed to load (`No named parameter with the name 'timeout'`). A scratch
experiment (run, then deleted) proved the installed package:test does not
apply group/test `timeout:` declarations to `setUpAll` bodies (a 5s
setUpAll survived inside a 2s-timeout group). The compile window is
therefore bounded by the helper's internal `zfaCompileTimeout` — which now
scales — and the invalid args were removed. Full narrative in
`tdd/cycle-log.md` §3.

## 6. Test-smell rubric (new tests)

- No conditional/skipped assertions; all 9 tests assert hard values
  (identities, clamps, exact products, monotonic lower bounds).
- The new test file is fast-tier and subprocess-free (pure functions +
  process-wide finals), so it cannot flake on hardware or AOT-cache state.
- Environment-dependent expectations are computed from the environment the
  process actually started with (`processScale`), which is what makes the
  same file a valid green in both the unset and scaled runs.
- Assertions target the contract (parse/clamp semantics, budget products),
  not implementation details; no sleeps, no timing races.
- No test semantics changed in pre-existing tests: zero assertion edits,
  zero tag changes (all three spawning files already carried
  `@Tags(['slow'])` before this branch).

## 7. Pre-existing, out-of-scope observations (not caused by this branch)

- `dart analyze` errors (31) — all `uri_does_not_exist` in
  `examples/todo_tdd/` (generated artifacts absent; the example needs the
  Flutter SDK). Identical on the unfixed baseline.
- `examples/mcp_demo/lib/src/mcp/tools.dart` — pre-existing `dart format`
  drift (const-map indentation from an older formatter), caught by the
  verify gate's format step; committed separately as a `style:` commit so
  the bug diff stays scoped.
- `examples/todo_tdd` fails `dart pub get` without the Flutter SDK
  (`flutter_test from sdk which doesn't exist`); unrelated to the root
  package, which resolves and tests fully on Dart alone.

## 8. Acceptance-criteria coverage

| Acceptance criterion (issue #1187) | Evidence |
|---|---|
| Read `ZFA_TEST_TIMEOUT_SCALE` (or similar) env multiplier in `test/helpers/run_zfa_source.dart` | `parseTimeoutScale` + `zfaTestTimeoutScale` + `scaleDuration` + `zfaDefaultChildTimeout` + `zfaCompileTimeout`; wired into `runZfaSource` default and the compile budget (§5.1 plumbing proof across 5 env values) |
| …and in the suite's `Timeout` declarations | `feature_flag_cli_test.dart` / `make_skip_test.dart` / `build_flavor_filter_test.dart` ceilings now `Timeout(scaleDuration(const Duration(minutes: 3)))` (§5.2, budget-only diff) |
| Document it for slow machines | `test/README.md` §"Slow machines: `ZFA_TEST_TIMEOUT_SCALE`" (values, clamping, what scales, `dart_test.yaml` limitation + `--timeout xN` pairing) |
| Consider `@Tags(['slow'])` for subprocess-spawning tests so the fast tier stays meaningful | Verified already present on all three `feature_flags` spawning files pre-branch; fast tier excludes `slow` via `dart_test.yaml` — no change needed, recorded in `issue.md` |
| Fix timeouts; do not change test semantics | §5.2 (74/74 at scale 1 and 2, zero assertion edits); default behavior when the variable is unset is byte-for-byte the old budgets (B1/B6/B7 at scale 1.0) |
| feature_flags suite green on older hardware | Cannot be executed on 2019 Intel Mac hardware from this environment (stated honestly): green proven on fast hardware at scale 1 and 2; the mechanism multiplies every budget that the issue's logs show exceeded (75s child / 100s compile / 30s→180s ceilings); an operator on that hardware runs `ZFA_TEST_TIMEOUT_SCALE=2 dart test test/feature_flags --preset=all` per the README |
| One PR for the bug | Branch `fix/1187-test-timeout-scale`, single bug commit + separate pre-existing-format `style:` commit |
| Red → green cycle | §2/§3 (RED) and §5 (GREEN); discrimination re-proof via stash cycle in §2 |
| `tdd/verification.md` real | This file; every result in it was actually executed |

## Verdict

**passed** — the scale mechanism is test-first (red on the unfixed tree,
green on the fixed tree), kills its targeted mutant, proves its
environment plumbing five ways, and leaves the target suite green with
byte-identical semantics at every scale; the full fast chunked suite
(90/90 chunks) and `dart analyze` (no new issues) are clean. The one thing
this environment cannot do is run the suite on the original 2019 Intel Mac
hardware; that residual is stated rather than claimed, and the deliverable
(the multiplier + documentation) is exactly the lever the issue requested
for it.
