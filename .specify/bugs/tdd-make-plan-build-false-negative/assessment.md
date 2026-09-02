# Bug Assessment: fix(tdd) — make plan's terminal build step false-negatives on a pre-existing red suite (generation-error instead of skipped)

- **Slug**: tdd-make-plan-build-false-negative
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/737
- **Verdict**: valid
- **Severity**: high

## Report (summarized)

`zfa tdd make` plans a 2-step generation for unit behaviors: `[zfa tdd func <id>, build]`. When the project's suite carries pre-existing red tests (pending `U*` stubs that throw `UnimplementedError`) or other build-state noise, the plan's terminal `build` step exits non-zero, the pipeline grades the plan failed, and the make reports `outcome=generation-error` — even though every generation step (the func scaffold) succeeded and the CURRENT behavior's own test passes. Direct `zfa tdd func` / `zfa tdd make` invocations succeed (the direct re-run hits the #694 skip transition); only the run driver's invocation of the plan fails, deadlocking `zfa tdd run` on a healthy behavior.

## Symptom

Spec 004 (forklift) run: A1-A5 done, U1-U2 done, `U3:make` → `generation-error` from a pre-existing red test elsewhere in the suite. The run stops on the false negative.

## Reproduction (this session, minimal fixture)

Fixture project with U1-U2 implemented, U3+U4 fresh stubs; certified-red evidence for U3; real CLI:

```
$ zfa tdd make U3
   suite baseline: dart test
   baseline exit: 1, failed: 2            # U3 + U4 red at baseline
   plan: 2 step(s)                        # [tdd func U3, build]
zfa tdd make: generation step failed at index 1 (build generated code for behavior U3):
   command: `<dart> <zuraffa>/bin/zfa.dart build`
   exit: 1
make: behavior=U3 outcome=generation-error feature=090-fx   # exit 1
```

After the failed make, `lib/tdd/u3_subject.dart` contains the scaffolded `String u3() { return 'u3'; }` and `dart test test/tdd/u3_test.dart` PASSES — the scaffold achieved the behavior's goal; only the terminal build step's exit stood between the make and a green outcome.

Captured as a failing unit test (RED): `bug 737 — a unit behavior reports skipped (not generation-error) when the plan's terminal build step fails against a pre-existing red suite while the behavior's own test passes after the func scaffold` (failed against pre-fix code: Expected 0, Actual 1).

## Suspected Code Paths

- `lib/src/plugins/tdd/services/pipeline_runner.dart:93-136` — **confirmed**. `runPlan` stops the plan on the first non-zero step exit (`if (result.exitCode != 0) { firstFailure = i; break; }`). Correct per FR-006 (every invocation captured, caller decides) — the caller's grading is the bug.
- `lib/src/plugins/tdd/commands/make_command.dart` (misfire-stop on generation failure, US4.AC2) — **confirmed**. Any `!pipelineResult.completed` is graded `generation-error` with exit 1, without checking whether the CURRENT behavior's own test passes.
- `lib/src/commands/build_command.dart` — the plan's `build` step validates the WHOLE project (build_runner + `dart analyze lib/`), so its non-zero exit can reflect pre-existing suite/build state the make is not responsible for.
- The plan shape itself (`lib/src/plugins/tdd/services/generation_planner.dart`, `_functionSurfacePlan`) — every expressible plan terminates in a terminal `build` step (T005/U5); the terminal step is the one exposed to whole-project state.

## Root Cause Hypothesis

The make plan's terminal `build` step validates the whole project, so its non-zero exit is NOT attributable to this behavior's generation when the pre-existing suite/build state is already broken (pending `U*` stubs). The make's misfire-stop grades ANY plan failure as `generation-error` (US4.AC2) without a per-behavior check, so `zfa tdd run` stops on a false negative. Same root cause as #731 (pre-existing red tests misattributed to the current make) but in a different code path: the make PLAN's build-step grading vs the direct make runner's suite-guard regression check.

Confidence: **high** — deterministic fixture reproduction (RED test failed against pre-fix code; end-to-end CLI repro shows scaffold success + build exit 1 + generation-error), and the direct-call vs run-driver mismatch from the issue matches the mechanism (a direct re-run after the scaffold takes the #694 skip transition and exits 0).

## Proposed Remediation

Make the make plan's build/guard step per-behavior: when the pipeline fails at the plan's TERMINAL `build` step, run the CURRENT behavior's own test (the profile `single` command, e.g. `dart test test/tdd/u3_test.dart`) before grading the make. If it passes, the build failure is not attributable to this generation — take the #694 skip transition (`outcome=skipped`, exit 0, green evidence appended, run loop continues). Anything else (non-terminal failure, non-build step, launch failure, red target test) keeps the honest `generation-error` stop (safe-failure, never a silent pass).

Scope guard: the fix lives ONLY in the make command's plan-execution/guard logic (`make_command.dart`). The planner, the pipeline runner, the run driver, and spec 047's FR-005 plan shape are untouched. The terminal-build contract amendment applies to every plan shape (the composition path in spec 052 hits the same pre-existing-red suite in phase 2); the conflicting A15 test is amended with the issue reference, following the #694 amendment precedent.

**Files changed**:
- `lib/src/plugins/tdd/commands/make_command.dart` — terminal-build per-behavior guard (`_toleratedTerminalBuildFailure`), tolerated-path outcome (`outcome=skipped`), doc comment.
- `test/plugins/tdd/make_command_test.dart` — 3 new bug-737 tests (skip transition, safe-failure control, terminal-only scope) + A15 amended to the per-behavior contract.

**Tests added/updated**:
- Bug 737: terminal build fails against a pre-existing red suite (sibling U4 still red) + func scaffold flips the target test green → `outcome=skipped`, exit 0, green evidence appended, plan executed end to end.
- Bug 737: red target test after the failed build → `generation-error`, no green entry (the tolerance never masks a genuinely failed generation).
- Bug 737: failed `tdd func` step (index 0) → `generation-error` (only the terminal build step qualifies).
- A15 amended: failed terminal build after a successful compose + passing target test → `outcome=skipped`, green entry (was: `generation-error`).

## Risks & Considerations

- The tolerance is gated on the behavior's OWN test passing — the same per-behavior check the whole TDD loop is built on. Broken generated code fails to compile the target test, so the check refuses tolerance where it matters.
- The suite guard (step 9) still runs on the tolerated path and still grades attributable NEW failures (#731 class) as `regression` — tolerance never bypasses re-certification.
- Non-terminal or non-build step failures keep the honest stop, so real generation work that never ran is never papered over.
- The 2 pre-existing failures in `make_command_test.dart` on master (bug 657 verb-naming assertion; spec 052 SC-004) are unrelated to this fix — verified by stashing the fix and re-running on pristine master.

## Open Questions

- None blocking.
