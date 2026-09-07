# TDD Verification — tdd-run-widget-lane-stalls-engine (issue #1271)

- **Date**: 2026-09-07
- **Branch**: fix/1271-tdd-run-widget-lane-stalls-engine (base d3679e0f)
- **Engine**: LLM-guided fallback (bug dir not under `specs/`; the
  `zfa tdd verify --feature` artifacts.json flow requires
  `specs/<feature>/`. The dispatch was actually attempted this session:
  `dart run bin/zfa.dart tdd verify --feature
  tdd-run-widget-lane-stalls-engine` returned
  `gate: not_assessed / reason: no behavior artifacts registered /
  mutation_was_run: false` — it assessed nothing, its empty shell dir was
  discarded, and this fallback audit was produced from the REAL runs below.
  Same fallback precedent as bug 1060's verification.md.)
- **Scope**: `lib/src/plugins/tdd/commands/run_driver_core.dart` (the only
  lib change), `test/plugins/tdd/commands/bug_1271_widget_lane_engine_deferral_test.dart`
  (new), `.specify/bugs/tdd-run-widget-lane-stalls-engine/*` (records)
- **Gate verdict**: **PASSED** (with disclosed deviations, below)

## 1. Test-first evidence

- Baseline RED reproduced against the unmodified runner BEFORE any
  implementation change: `bug_1271_widget_lane_engine_deferral_test.dart`
  (3 tests) run with
  `dart test --preset=all test/plugins/tdd/commands/bug_1271_widget_lane_engine_deferral_test.dart`
  → **0 passed / 3 failed**, each for the RIGHT reason:
  - T1: `run-engine` drives the widget-kind `[both]` row through the engine
    steps and stalls exactly as filed — `A1 gen -> ok` → `A1 verify-red ->
    unexpected-green` → `A1 verify-red -> skipped (already green)` →
    `A1 make -> not-certified-red` → `result=stopped … stopped_at=A1:make`,
    exit 1 (full transcript in `red-evidence.md`).
  - T2: the engine receipt owned the widget-kind row
    (`{U1, U2, A1}` instead of `{U1, U2}`) — engine-lane routing.
  - T3: an untagged widget-kind row (CORE default bucket) was driven by
    `run-engine` (`gen W2 … refactor W2`).
- Implementation landed only after those failing tests existed.

## 2. Suite status (scoped, per the cloud-agent constraint)

Only suites covering the changed file were run — never the full suite:

| Command | Result |
| --- | --- |
| `dart test --preset=all test/plugins/tdd/commands/bug_1271_widget_lane_engine_deferral_test.dart` (post-fix) | **3/3 pass** |
| `dart test --preset=all test/plugins/tdd/two_cycle_run_commands_test.dart test/plugins/tdd/run_command_test.dart` | **70/70 pass** (6:39) |
| `dart test test/plugins/tdd/commands/run_engine_command_test.dart test/plugins/tdd/commands/run_skin_command_test.dart` (fast tier) | **12/12 pass** |
| `dart test --preset=all test/plugins/tdd/commands/run_skin_command_test.dart` | **5/5 pass** |
| Post-mutation-restore re-run: bug tests + `two_cycle_run_commands_test.dart` | **24/24 pass** |

**No new failures.** The two-cycle spec-1008 contract (U1–U15, including the
legacy byte-compat U12 and the plan-file precedence U15) stays green —
engine-lane CORE processing and skin-lane widget processing are unbroken
(hard constraints 3 and 4). Full suite NOT run (kernel-cache/disk constraint
for cloud agents; the standing chunked runner was intentionally not used for
the same scoped-suite reason bug 1060 disclosed).

## 3. Analyzer

`dart analyze lib/src/plugins/tdd/commands/run_driver_core.dart
test/plugins/tdd/commands/bug_1271_widget_lane_engine_deferral_test.dart`
→ **No issues found!** (re-checked after the mutation restore)

## 4. Formatting

`dart format .` run before delivery: formatted 2520 files, 5 changed — the
branch's own two files plus three PRE-EXISTING drift files on master
(`specs/1142-adaptive-layout-contract/tdd/evidence/a1143_subject.dart`,
`a1144_subject.dart`, `generated_subject_004_login_ui.dart`). The three are
unrelated committed drift (not touched by this branch) and were REVERTED to
keep the bug PR minimal. `dart format --set-exit-if-changed` over the
branch's changed Dart files → **0 changed** (exit 0);
`git diff --stat` shows only `run_driver_core.dart` (+34).

## 5. Mutation spot-checks (test strength)

Three hand-applied mutants on the routing block, each reverted after the
run (post-restore suite re-run green — section 2, last row):

| Mutant | Change | Result |
|--------|--------|--------|
| M1 | engine-lane widget filter disabled (widget rows keep riding the engine bucket) | **Killed** — T1 red (the filed stall returns, exit 1 at `A1:make`) |
| M2 | skin-lane deferral queue disabled (deferred widget rows lost, not queued) | **Killed** — T3 red (untagged widget row never picked up by `run-skin`); note T2 alone does NOT kill M2 (a `[both]` row still reaches the skin bucket through its own tag — the queue is what guarantees CORE-default/plan-only widget rows survive) |
| M3 | queue kind-check inverted (`!=` widget) — non-widget engine rows leak into the skin bucket | **Killed** — T2 red (skin receipt `{U1, U2, A1, W1, W2}` ≠ `{A1, W1, W2}`) |

No surviving mutants in scope.

## 6. Success criteria (issue #1271 hard constraints)

| Criterion | Evidence | Status |
|-----------|----------|--------|
| (1) detect widget-kind behaviors in the engine lane bucket | M1 mutant killed by T1; T3 pins detection through the CORE-default route | PROVED |
| (2) defer them to skin lane (mark pending, skip engine steps) | T1: zero engine steps spawned for A1, state stays pending, exit 0; T2: A1's steps land in the skin phase after the last engine step | PROVED |
| (2b) queue them for run-skin behind a green engine receipt | T2: skin receipt `{A1, W1, W2}` green after engine `{U1, U2}` green; T3: standalone `run-skin` drives the deferred row after `run-engine` completes green | PROVED |
| (3) not break existing engine-lane CORE processing | `two_cycle_run_commands_test.dart` U1–U4 + U12 green (70/70 run); engine receipt names exactly the driven behaviors | PROVED |
| (4) not break existing skin-lane widget processing | `two_cycle_run_commands_test.dart` U5–U8 + U15 green; `run_skin_command_test.dart` 5/5 (conformance cycle untouched) | PROVED |
| Fix ONLY the two-cycle routing logic | `git diff` = one lib file, +34 lines inside the lane-resolution block; engine step semantics, skin conformance cycle, receipts schema untouched | PROVED |
| One PR per bug | Branch carries exactly the fix + test + bug records | PROVED |

## 7. Honest disclosures (not proved / pre-existing)

- The issue's **secondary observation** (unexpressible acceptance behaviors
  leaving `done=0` accounting) is explicitly OUT of scope here; NOT fixed,
  NOT proved.
- The fix was exercised through the spec-1008 lane mode (tags / plan pair /
  split receipt / CORE default) with the scripted fake zfa harness; the
  spec-1005 skin **conformance mode** path (`_runConformanceMode`, declared
  `adaptive_slots`) was not re-driven this session — it is outside the
  routing block and its own suite (5/5) stays green.
- `zfa tdd verify` engine dispatch assessed nothing (see Engine note) — the
  mutation evidence above is the fallback hand-applied mutant protocol, all
  runs real, all reverts verified.
- Environment notes: Dart SDK 3.13.3 linux_x64; `example/` requires a
  Flutter SDK and was not resolved (pure-Dart root package resolved and
  tested; the fix surface is pure Dart).
