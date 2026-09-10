# TDD Verification — Spec 1468 (BehaviorState forward-compatibility)

- **Feature**: `1468-behavior-state-forward-compat` (issue #1468 — degrade
  unknown `BehaviorState` values to `pending` on deserialization)
- **Generated**: FRESH from the actual run in this session (2026-09-11) —
  not a copy of a prior verification.
- **Command path**: `/speckit.tdd.plan` → `/speckit.tdd.run` (red → green,
  evidence logs recorded) → `/speckit.implement` (non-behavioural tasks) →
  this audit.
- **Scope note**: single-point fix in `RunStateStore._validated()` only;
  `RunState.fromJson` (model-side `byName`) is out of scope per the spec's
  hard constraint.

## Verdict: **PASSED** (gate green, 2/2 mutants killed)

| Gate | Result |
|------|--------|
| Preflight (suite green before audit) | ✅ `dart test test/plugins/tdd/services/run_state_store_test.dart` → 9/9 pass on untouched code (baseline) |
| Test-first evidence | ✅ red log captured with the fix NOT yet written (`tdd/red-1468.log`, exit 1, `+11 -3`) |
| Red-phase evidence | ✅ U1/U2/U3 failed for the RIGHT reason: `corrupted run-state.json … (unknown behavior state "shelved"/"archived")` raised at `run_state_store.dart:216` — the pre-fix corrupt branch |
| Green | ✅ `tdd/green-1468.log` — exit 0, `+14: All tests passed!` (11 pre-existing + 5 new) |
| Test-smell rubric | ✅ no sleeps/order deps; isolated `Directory.systemTemp` fixtures with `tearDown` deletion; stderr captured via `IOOverrides.runZoned` (repo pattern from `route_explain_test.dart`); exact receipt asserted, no process spawning |
| Mutation testing (changed file) | ✅ 2/2 mutants killed (M1 corrupt-on-unknown restored → U1/U2/U3 fail; M2 silent degrade, warning dropped → U2/U3 fail) |
| Acceptance-criteria coverage | ✅ SC-1→U1, SC-2→U2, SC-3→U3, SC-4→U4, SC-5→U5+B1 (see §4) |
| `dart analyze` (changed files) | ✅ No issues found (scoped to the 2 changed files); repo baseline unchanged: 0 errors / 0 warnings / 112 pre-existing infos |
| `dart format` | ✅ `Formatted 2 files (0 changed)` for both changed files; zero remaining formatting diffs in this branch's diff. Pre-existing drift on master in `example/test/tdd/004-login-ui/u1_test.dart` and `tool/generate_openwiki_cli_docs.dart` was left untouched (unrelated files, not this fix's scope) |

## 1. Test-first evidence (this session, branch `feat/1468-behavior-state-forward-compat`)

Order of operations, before any implementation existed:

1. Wrote the `spec 1468: BehaviorState forward-compatibility` group
   (5 tests: U1–U5) against the spec's success criteria, and amended the
   legacy `U9: shape violations are corruption` list (removed the
   `{"B-1": "blue"}` row — an unknown state NAME is no longer corruption
   per SC-1).
2. First run: **3 failures, all for the right reason** —
   `corrupted run-state.json at … (unknown behavior state "shelved")`
   thrown from the pre-fix `_validated()` branch (`run_state_store.dart`
   178:34 → 216:26). U4 (all-known unchanged) and U5 (non-string value
   still corrupt) passed as characterization guards, as expected.
   Reproducible artifact: `tdd/red-1468.log` (exit 1, `+11 -3`).
3. Applied the single-point fix in `_validated()`'s for loop only:
   unknown name → `stderr.writeln('[run-state] unknown state "<name>" for
   behavior "<id>" → degraded to pending')` + `BehaviorState.pending`.
4. Suite went green: `+14: All tests passed!` (`tdd/green-1468.log`,
   exit 0). Related suite touching the store
   (`realize_command_1193_test.dart`) re-run: 11/11.

## 2. Red → green (cycle log)

- **RED (evidence `tdd/red-1468.log`):** exit 1 — U1, U2, U3 fail on the
  `RunStateCorruptException('unknown behavior state …')` path; the degrade
  behavior did not exist.
- **GREEN (evidence `tdd/green-1468.log`):** exit 0 — `+14: All tests
  passed!` after the for-loop branch was added.
- **Refactor:** none required — the fix is the spec-mandated single point;
  post-green the implementation and tests were formatted (0 changed) and
  re-analyzed (no issues).

## 3. Mutation testing (changed file — real runs, each mutant killed)

Each mutant was applied by editing the working tree, running the pinned
test file, and restoring the pristine fix (`cp` of the pre-mutation file).

- **M1 — revert the degrade branch** (restore
  `corrupt('unknown behavior state "$value"')` ahead of the loop body):
  exit 1 — U1, U2, U3 fail with the corruption error; the mutant is
  caught because every degrade assertion requires a successful load.
  Evidence: `tdd/mutation-M1-1468.log`.
- **M2 — silent degrade** (drop the `stderr.writeln` warning, keep the
  pending fallback): exit 1 — U2 and U3 fail on the missing degrade
  receipt; U4 (which requires an EMPTY warning for all-known state)
  correctly still passes, proving the mutant killed is specifically the
  warning behavior. Evidence: `tdd/mutation-M2-1468.log`.

## 4. Acceptance-criteria coverage

| Criterion (spec.md) | Behavior | Test | Result |
|---------------------|----------|------|--------|
| SC-1 unknown state degrades to pending, no throw | U1 | `U1: unknown state name degrades that entry to pending` | ✅ |
| SC-2 warning names state + behavior + fallback | U2 | `U2: the warning names the state, the behavior, and the fallback` | ✅ exact receipt `[run-state] unknown state "shelved" for behavior "B-001" → degraded to pending` |
| SC-3 downgraded binary reads newer state (mixed map) | U3 | `U3: mixed map keeps known values, degrades only unknown ones` | ✅ done/red retained, archived → pending |
| SC-4 all-known state unchanged (backwards compatible) | U4 + original U7 round-trip | `U4: all-known state loads unchanged, no warning` | ✅ values identical, no spurious warning |
| SC-5 state machine + shape contract unaffected | U5 + B1 + original U8/U9/U10/U11 | `U5: non-string state value is still corruption` + amended U9 | ✅ non-string values, wrong feature, unknown `in_flight_step` still corrupt; enum/`_kSteps` untouched |

Not proved by tests (by design, per scope): the model-side
`RunState.fromJson` still throws on unknown names — explicitly out of
scope per the spec's single-point constraint.
