# Research: 1645-pipeline-running-binary-tier

**Date**: 2026-09-15 | **Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## R1: How does the sibling fix (#1643, PR open) promote the running binary?

- **Decision**: Mirror its shape exactly — condition
  `!_isDartVmName(basename(resolvedExecutable)) && File(resolvedExecutable).exists()`,
  promoted ahead of the PATH tier; docs renumbered with the issue
  rationale; VM drivers untouched below.
- **Rationale**: The issue text names #1643 as the pattern to mirror,
  including its test shapes (B1–B5). Same-version/different-code hazard,
  same no-JIT directive, same backward-compatibility constraint.
- **Alternatives considered**: A pipeline-specific condition (e.g. the
  #864 equality check `script == resolvedExecutable` as the trigger) —
  rejected: it misses the stale-dill shape (unusable script) that B2
  covers, and would fork the two resolvers' semantics.

## R2: Reuse or duplicate the VM-name predicate?

- **Decision**: Duplicate privately (`PipelineRunner._isDartVmName`
  mirroring `StepRunner._isDartVmName`), cross-referenced in doc
  comments.
- **Rationale**: `StepRunner._isDartVmName` is private; exposing it
  changes the step-runner API surface and adds a services-internal
  import for a 5-line predicate. The repo's own history mirrors tiers
  between the two resolvers without coupling (#665 ↔ #690).
- **Alternatives considered**: Public `StepRunner.isDartVmName` + import
  — rejected (API surface + coupling for one predicate; extract on the
  third consumer per the #1610 precedent).

## R3: What do the existing pipeline tier tests pin, and what flips under the reorder?

- **Decision**: Re-shape U16/U17 in `test/plugins/tdd/services/
  pipeline_runner_test.dart` from the synthetic `dart-vm` fake basename
  to the real VM name `dart`; keep assertions and intent unchanged.
- **Rationale**: Verified by reading the group: U14 (native AOT, PATH
  nonexistent) unaffected; U15 (source tier) unaffected; U16 ("PATH wins
  over snapshot fallback") and U17 ("`<vm> <snapshot>` shape preserved")
  use `writeFakeZfaBin(name: 'dart-vm')`, which FAILS the VM-name check —
  under the promoted tier the running fake binary would win, flipping
  both red for a shape no production VM launch produces (a real VM is
  named `dart`/`dart.exe`/`dartaotruntime`). #1643 hit the identical
  situation in `step_runner_test.dart` and re-shaped to the realistic
  driver; the #1636 fix.md records that precedent.
- **Alternatives considered**: Loosening the promoted-tier condition to
  keep `dart-vm` falling through — rejected (weakens the fix to save a
  test rename); deleting the tests — rejected (they pin FR-002/FR-006).

## R4: How is the resolved entrypoint observed in tests?

- **Decision**: Drive `PipelineRunner().runPlan(...)` with the injected
  platform-fact seams and assert on `result.entrypoint` plus the fake-zfa
  argv log — the same harness as the bug-#864 tier group.
- **Rationale**: `_resolveEntrypoint` is private, but `runPlan` forwards
  `scriptPathOverride` / `resolvedExecutableOverride` /
  `pathEnvOverride` / `ensureCompiled`, and records the resolution in
  `PipelineResult.entrypoint`. `TddFixture.writeFakeZfaBin` provides
  executable fakes with an argv log; the tests stay in the fast tier (no
  real AOT compile — `ensureCompiled` is injected or the candidate is a
  non-`.dart` file that passes through the default seam unchanged).
- **Alternatives considered**: Making `_resolveEntrypoint` public/test-
  visible — rejected (API change for test convenience; the runPlan seams
  already reach every tier).

## R5: Does anything else read the pipeline tier order?

- **Decision**: No other caller inspects the order; the fix is confined
  to `_resolveEntrypoint` + docs.
- **Rationale**: Grep over `lib/` shows `runPlan` is the only
  `_resolveEntrypoint` call site; `zfaBinOverride` (tier 1) callers are
  unaffected; the refactor build pass resolves through `StepRunner`
  (#1643), not this chain. The #1472 gate suites
  (`test/plugins/tdd/bug_1472_refactor_gate_*.test.dart`) pin the pin
  itself and stay green untouched.
- **Alternatives considered**: Doc-only updates in neighboring files
  (the `refactor_passes.dart` doc refresh #1643 also carried) — not
  needed here: no neighbor documents the pipeline tier order.
