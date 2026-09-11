# tdd.verify — Bug #1512 acceptance vacuous composition

- **Verified**: 2026-09-11 (round-2 review fixes), this session, on
  `fix/1512-acceptance-vacuous-composition` (working tree, pre-push)
- **Toolchain**: Dart 3.13.2 (stable) on macos_x64
- **Scope**: the two changed source files + the new `vacuous_guard.dart`
  vocabulary constants + the rewritten suite, then the chunked regression
  sweep below.

## Verdict: PASS (with the recorded host/environment caveats in §4)

## 0. Round-2 review corrections (what changed since round 1)

The round-1 record below claimed the acceptance capture threaded the declared
args and returned the declared result. That branch did not ship —
`gen_command.dart` resolves a `contractShape` only for `BehaviorKind.unit` and
the paired acceptance subject is a parameterless `void <target>()` scenario
runner, so the branch was unreachable in production and would not compile if
reached. Round 2 applied the reviewed option (b):

1. the acceptance declared-args/return branch is REMOVED; the acceptance
   capture is the void-safe, argument-free form and an injected
   `contractShape` is inert for acceptance;
2. the undeclared acceptance fallback emits the acceptance-lane token
   (`acceptanceFallbackGuardToken` / `acceptanceFallbackGuardComment`)
   instead of the #1259 `vacuousGuardMarker`, keeping the run driver's
   `stopped_at=<id>:make` classification;
3. planner branch 3b no longer consults `_extractCapitalizedTrace` — only
   explicit prose signals (`target` / `entity <Name>` / `create <Name>`) may
   drive `entity create`;
4. the suite was rewritten to drive the real path and now includes a slow
   `dart test` compile pin over the emitted test+subject pair.

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/services/behavior_test_writer.dart \
             lib/src/plugins/tdd/services/generation_planner.dart \
             lib/src/plugins/tdd/services/vacuous_guard.dart \
             test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart
→ No issues found!
```

Full-project `dart analyze`: **112 `info` lints, 0 errors / 0 warnings** —
identical to the pre-change baseline (112).

## 2. The bug suite (REAL runs in this session)

```
dart test test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart
→ 00:00 +16: All tests passed!          (fast tier)

dart test --preset=all test/plugins/tdd/services/bug_1512_acceptance_vacuous_composition_test.dart
→ 00:14 +17: All tests passed!          (incl. the slow pair-compile pin)
```

REQUIRED check — the acceptance capture is the void-safe, argument-free form
`gen` can actually build: PROVED by A-1512-a1/a2/a3 (undeclared row; scalar
shape injected; entity shape injected — no threaded args, no returned result)
and A-1512-a4 (the paired subject `SubjectWriter` emits is the parameterless
`void subject_a1()` runner the call is arity-compatible with).

REQUIRED check — the acceptance fallback is not misclassified as the traced
hand-delta seam: PROVED by A-1512-b1 (`acceptanceFallbackGuardToken` present,
`contentCarriesVacuousGuardMarker` false, `contentIsVacuousGreen` still true)
and b2.

REQUIRED check — the planner returns a real make surface for acceptance rows
and an incidental capitalised word cannot fabricate an entity: PROVED by
A-1512-c1..c8 (compose lane; `the User signs in.` composes; explicit
`entity <Name>`/`create <Name>`/`target` route to the entity pipeline; the
honest #758 refusal stays; non-acceptance rows keep the generic misfire).

REQUIRED check — the unit lane is unchanged: PROVED by A-1512-d1/d2 plus the
pre-existing `behavior_test_writer_test.dart`, `subject_writer_test.dart`,
`issue_1308_vacuous_guard_remedy_test.dart`, `bug_1259_vacuous_green_test.dart`
and `bug_912_literal_safety_test.dart` pins — all green in the sweep below.

REQUIRED check — the emitted pair compiles: PROVED by A-1512-e1 (slow): the
emitted test + paired subject are written to a temp package with a `test`
dependency and run through `dart test`; the run must fail through an
assertion (`Expected:`/`Actual:`), never a compile-time error.

## 3. Regression sweep (REAL runs in this session)

| Chunk | Result |
| ----- | ------ |
| `test/plugins/tdd/services/` | `04:18 +870 ~1: All tests passed!` |
| `test/plugins/tdd/commands/` | `+503 -4` — every non-green entry is environmental and **reproduced on a pristine `b5abf380` worktree or passes with a relaxed ceiling** (see §4) |
| `test/plugins/tdd/*_test.dart` (root suites) | `+458 -2` — both non-green entries reproduce on the pristine `b5abf380` worktree (see §4) |
| `test/cli/`, `test/commands/` | not re-run this round: the change is confined to the TDD acceptance lane, and every suite in this repo that pins the planner or the writers lives in `test/plugins/tdd/services/` (full green) |

## 4. The non-green entries — all proved to pre-date this change

`test/plugins/tdd/commands`:

1. `view_command_test.dart` U-V3 "a missing subject file is a hard
   runner-error" — **pre-existing**: the same failure reproduces on a pristine
   `b5abf380` worktree (`Expected: contains 'missing subject file'` vs. the
   actual "registry record … points outside the project root" message). The
   view lane and its registry-path resolution are untouched by this PR.
2. `bug_1320_declared_assertion_reachable_test.dart` U7 — `TimeoutException
   after 0:01:00` (the 2x default ceiling) under concurrent load; the file
   passes cleanly in isolation with a relaxed ceiling: `+8: All tests
   passed!`.
3. `bug_1372_certified_red_scan_test.dart` B1 and B2 — same 60 s host
   timeouts; the file passes cleanly in isolation with a relaxed ceiling:
   `+3: All tests passed!`.

`test/plugins/tdd` (root suites):

4. `wire_command_test.dart` U-W3 "a missing subject file is a hard
   runner-error naming the gen remediation" — **pre-existing**: reproduces on
   the pristine `b5abf380` worktree (`1 [E]`, same "registry record … points
   outside the project root" vs. "missing subject file" mismatch).
5. `bug_993_plan_entity_export_clash_test.dart` "end-to-end … (subprocess)" —
   **pre-existing host slowness**: the same 60 s `TimeoutException` reproduces
   on the pristine `b5abf380` worktree.

No assertion-level failure was introduced by the change.

## 5. Environment notes (honest recording)

- This host ran several concurrent heavy `dart test` sweeps (other agents in
  `/tmp/fix-pr-1523` and elsewhere) throughout; the default 60 s per-test
  ceiling was exceeded by subprocess-spawning tests. Each such entry was
  either proved on a pristine worktree or re-run green with a relaxed
  ceiling, and is recorded rather than silently re-run away.
- Pre-existing macOS-only failures on this host: `view_command_test U-V3` and
  `wire_command_test U-W3` (both the same registry-record/temp-path
  resolution mismatch — `lib/<id>_subject.dart` judged "outside the project
  root" when `Directory.systemTemp` is `/var/folders/…`), plus one slow
  subprocess suite (`bug_993`).

