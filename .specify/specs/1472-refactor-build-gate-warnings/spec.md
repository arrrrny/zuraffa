# 1472-refactor-build-gate-warnings

- **Spec ID**: 1472-refactor-build-gate-warnings
- **Created**: 2026-09-13
- **Source**: GitHub issue #1472 (SPEC 1472 — refactor build gate treats warnings as compile failures — hand-implemented files deadlock the refactor pass)
- **Type**: bug (P1 — every refactor step behind a hand-implemented subject carrying a lint warning exits `runner-error`; the pass that would clean the lint never runs)
- **Branch**: feat/1472-refactor-build-gate-warnings
- **Related**: #1407 (make's analyze gate is errors-only — the precedent this spec extends to the refactor pass registry), #1308 (hand-delta seam — untouched), #912 (widget lane — untouched), #717 (build pass executes the system zfa on PATH), #1184 (stale-binary warning — the silence-rule model)

## Problem

`zfa tdd run`'s refactor step executes the fixed pass registry
(`RefactorPasses.defaultPassSpecs`, spec 048): **build → format → fix**, with
misfire-stop on the first non-zero exit (FR-010). The `build` pass runs
`zfa build`, whose post-build analyze gate (issues #395/#1035) refuses the
tree on **errors OR warnings**. A hand-implemented subject with one unused
import therefore fails the build pass with a **warnings-only refusal**
(`0 error(s) and N warning(s)`), the registry misfire-stops, and the
`dart fix --apply` pass — the only pass that would remove exactly that lint —
never runs. Every subsequent refactor step exits `runner-error`. The loop
cannot refactor itself out of a warning: a deadlock.

The codebase already resolved the identical coupling for `zfa tdd make`
(issue #1407): the make re-grades the failed terminal build step and treats
a 0-errors/N-warnings gate refusal as non-blocking, logged accurately,
cross-checked through the shared `BuildCommand.countAnalyzerIssues` parser.
The refactor pass registry never received the same treatment — that is the gap.

Secondary: the build pass resolves its zfa entrypoint with the #717
package-tier suppression, so when the running-from-source tiers fail to
resolve (e.g. the global `-C` chdir re-anchoring `Platform.script`, issue
#1371), a **stale system zfa on PATH** executes the build pass with a
different gate than the CLI driving the run. Nothing pins the executed binary
to the driving version.

## Goal

The refactor pass's build gate refuses on **errors only** — warnings are the
`dart fix` pass's input, not compile failures — and the executed zfa binary is
pinned to the version driving the run. Warnings-only refusals no longer
deadlock the refactor pass; actual compile errors keep the honest misfire-stop.

## Success criteria (measurable)

1. **SC-1 (errors-only gate)**: When the refactor `build` pass exits non-zero
   and its output is the analyze gate's own warnings-only refusal (0 error(s)
   and ≥1 warning(s), cross-checked: no `error -` severity lines in the raw
   output), the registry does NOT misfire-stop — `format` and `fix` still run
   and the refactor proceeds through its normal flow (re-proof decides the
   outcome, never the warning).
2. **SC-2 (errors still block)**: When the build pass's refusal carries ≥1
   analyzer ERROR (or the failure is any non-gate class: build_runner crash,
   spawn failure, timeout), the misfire-stop is unchanged — `outcome=runner-error`,
   remaining passes do not run.
3. **SC-3 (accurate counts)**: The tolerated verdict is logged with the gate's
   own counts (`0 error(s), N warning(s)`) and names warnings non-blocking for
   the refactor build pass; the registry never claims the tree "did not
   compile cleanly" for a warnings-only refusal. The recorded `RefactorAction`
   keeps the honest exit code and output (auditability).
4. **SC-4 (safe-failure on disagreement)**: When the gate message claims 0
   errors but the raw output carries `error -` lines (message/parser
   disagreement), the honest misfire-stop stands — never a silent pass.
5. **SC-5 (profile opt-out)**: A project whose TDD profile sets
   `analyze-gate: warnings-blocking` (the #1407 machine-readable Keys block)
   restores the legacy warnings-blocking refusal for the refactor build pass.
6. **SC-6 (binary pinning)**: When the build pass's resolved zfa entrypoint
   (the #717 chain) reports a `--version` that differs from the driving CLI's
   version, the build pass is pinned to the driving CLI's own entrypoint and
   the pin is logged; when the version matches, is absent, or is unprovable,
   the #717 resolution is unchanged (silence rules — never re-route on
   unprovable input).
7. **SC-7 (no regression)**: `zfa build` standalone keeps its warnings-blocking
   gate (#1035 contract), the pass registry order stays build → format → fix,
   the refactor pass scope, hand-delta seam (#1308), and the tdd run state
   machine are untouched, and `dart analyze` reports no new warnings.

## Out of scope

- The `zfa build` gate itself (issues #395/#1035) — unchanged for standalone
  `zfa build` and for make (#1407 grading unchanged).
- Pass registry re-ordering (the spec's alternative OR-arm): the errors-only
  gate alone removes the deadlock completely; ordering cannot (a warning
  `dart fix` cannot clean would still refuse the gate after any reorder).
- Refactor pass scope, hand-delta seam, state machine, re-proof, evidence.
