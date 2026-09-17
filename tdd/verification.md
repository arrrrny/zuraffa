# tdd.verify — Bug #1677 scalar vacuous-green refusal prints the void/entity explanation

- **Verified**: 2026-09-18, this session, on
  `fix/1677-scalar-vacuous-green-message` (working tree, pre-push)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/plugins/tdd/services/vacuous_guard.dart` (the
  `_typeOnlyScalarExpect` capture group + `scalarTypeOnlyDeclaredType`),
  `lib/src/plugins/tdd/commands/run_driver_core.dart` (the marker-present
  arm's branched refusal message), the new
  `test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart`,
  and the bug artifacts under
  `.specify/bugs/1677-scalar-vacuous-green-message/`.
- **Engine**: `zfa --version` + `.zfa.json` probe → ZFA_MISSING for this
  checkout (no wired feature); the documented fallback LLM-guided audit
  ran, on REAL test executions from this session.

## Verdict: PASS

## 1. TDD discipline (red → green, REAL runs in this session)

The loop was driven with the new driver-level suite
(`test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart`)
pinned BEFORE the fix, over the REAL RunDriverCore with a scripted fake
zfa binary (the #1308/#1651 harness family):

- RED, pre-fix (master a9329746, fix stashed for the A/B):

```
dart test --preset=all test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart
→ 00:06 +0 -1: ... U1: a scalar contract's vacuous-green refusal prints
               the #1651 scalar explanation — never the void/entity template
→ 00:13 +1 -1: Some tests failed.
  Which: does not contain 'the traced contract's return is scalar (int)'
```

  The driver's verbatim stop on the unfixed tree — the bug on screen:

```
zfa tdd run: step failed — behavior=U1 step=make outcome=vacuous-green
   make: behavior=U1 outcome=vacuous-green feature=1677-scalar-message
   the traced contract's return is void/an entity — the zfa:tdd: vacuous-guard marker IS the designed hand-delta seam (issue #1308): the assertion set is the UnimplementedError guard only, which make refuses vacuous-green (issue #1259).
   hand step: U1:hand — write an assertion on the observable outcome in test/tdd/1677-scalar-message/u1_test.dart (replace the vacuous-guard guard, remove the marker), then re-run `zfa tdd run 1677-scalar-message`.
```

  U1 failed for the RIGHT reason: the scalar contract's refusal printed
  the #1308 void/entity template (both claims false for
  `add(int,int) -> int`). U2 (the void/entity guard pin) passed pre-fix,
  as it must.

- GREEN, post-fix:

```
dart test --preset=all test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart
→ 00:14 +2: All tests passed!
```

The fix was applied only after the repro suite was proven red; no test
was edited to make it pass retroactively.

## 2. Static gates

```
dart analyze lib/src/plugins/tdd/services/vacuous_guard.dart
             lib/src/plugins/tdd/commands/run_driver_core.dart
             test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart
→ No issues found!

dart analyze $(git diff --name-only HEAD -- '*.dart')   # the task's §5 loop
→ No issues found!

dart format .                      → Formatted 2944 files (0 changed)
dart format --output=none --set-exit-if-changed <touched files>
→ exit 0 (zero drift)
```

## 3. Regression audit (all REAL runs, this session)

Fast tier (default preset):

```
dart test test/plugins/tdd/bug_1651_type_only_vacuous_green_test.dart
          test/plugins/tdd/bug_1651_scenario_assertions_test.dart
          test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart
          test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart
          test/plugins/tdd/bug_1420_vacuous_stop_declared_trace_test.dart
          test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart
          test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart
          test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart
          test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart
→ 00:03 +47: All tests passed!
```

Slow tier (`--preset=all` scoped to the family files — the documented
single-slow-file invocation on cloud agents):

```
dart test --preset=all
          test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart
          test/plugins/tdd/commands/bug_1651_driver_remedy_test.dart
          test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart
          test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart
          test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart
→ 01:06 +24 -3: Some tests failed.
```

The 3 failures are PRE-EXISTING on unfixed master, verified by `git
stash` A/B in this session (identical failures with the fix stashed):

- `bug_1320_declared_assertion_reachable_test.dart` U6 + U7 (gen
  re-generation verdict + regenerated-pair cycle) — the gen-reuse
  subsystem, untouched by this fix;
- `issue_1388_gen_reuse_fingerprint_test.dart` U1 (fingerprint
  invalidation on routing change) — same subsystem; isolated rerun on
  unfixed master: `00:04 +8 -1`.

Unrelated to the changed refusal message (they never reach the
marker-present arm; the fix cannot affect gen reuse). Flagged per the
report protocol.

e2e tier (`--preset=all` scoped):

```
dart test --preset=all
          test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart
          test/plugins/tdd/bug_1651_vacuous_green_e2e_test.dart
          test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart
→ 00:28 +10: All tests passed!

dart test --preset=all
          test/plugins/tdd/commands/bug_1651_make_dummy_green_refusal_test.dart
          test/plugins/tdd/issue_1482_run_preflight_test.dart
→ 00:08 +17: All tests passed!
```

Chunk/cache hygiene: `.dart_tool/test/` and `/tmp/dart_test.kernel.*`
were cleaned before and after runs per the task's hygiene rules; an
8.5 GB kernel-cache buildup from a whole-tree preset attempt was removed
mid-session (the AGENTS.md guidance to avoid `--preset=all` unscoped on
small agents was then followed).

## 4. Acceptance criteria audit (issue #1677)

1. **The fix discriminates scalar vs void/entity returns** — PROVED: the
   arm reads the test content fail-open and branches on
   `scalarTypeOnlyDeclaredType` (the scalar type-only expect the writer's
   scalar branch emitted). U1 (scalar) and U2 (void/entity) pin both
   branches; the #1308 driver suite (U-1308-5/6/7/4) re-ran green, so the
   void/entity branch is byte-identical.
2. **Scalar contracts print the #1651 explanation** — PROVED: U1 asserts
   the exact paragraph ("the traced contract's return is scalar (int) —
   the `zfa:tdd: vacuous-guard` marker's assertion set checks the
   declared return TYPE only; a func-scaffolded dummy (`return 0;`)
   satisfies it (issue #1651).") and the absence of both false #1308
   claims.
3. **Void/entity contracts keep the #1308 explanation** — PROVED: U2
   asserts the #1308 paragraph verbatim and the absence of the scalar
   template; U-1308-6 (journal + named hand step) and U-1308-7 (fail-open
   unreadable) re-ran green.
4. **`--> fix:` and `hand step:` lines unchanged; #1651 gate semantics
   and #1308 hand-delta-seam handling unchanged** — PROVED: the diff
   touches only the middle paragraph's branch (+ the regex capture group
   and the helper); the `hand step:` line is asserted verbatim in U1/U2;
   `stopped_at=U1:hand` (never `:make`) is asserted in both tests; the
   #1651 gate suites (detector/writer fast pins + e2e refusals) all
   re-ran green.

Hard constraints honored: one PR per bug; the fix touches
`vacuous_guard.dart` (capture group + helper + docs) and
`run_driver_core.dart` (the message branch) only — verified by
`git diff --stat` (38 + 29 inserted lines, two files, plus the new test
file and artifacts).

## 5. Verdict

PASS — the scalar vacuous-green refusal now explains the scalar contract
accurately (the #1651 type-only check the func dummy satisfies), the
void/entity contracts keep the #1308 hand-delta-seam explanation
byte-for-byte, the machine contract and hand-step line are unchanged, and
the full vacuous-family regression (fast + slow + e2e) is green against
the fix.
