# Cycle Log: 1653-trim-heavy-deps (#1661)

Baseline seeded by `tdd.plan` (LLM-guided fallback — `ZFA_MISSING`, the
#1632/#1651 precedents). Loop driven by the red-green-refactor contract.

## Baseline

- at: 2026-09-15
- suite: fast tier (`dart test`, default preset) + per-companion gates
  (`dart analyze` / `dart test` under `packages/<name>/`)
- tree: `1653-trim-heavy-deps` @ master c5ed519f + specify/plan/tasks commits
- state: RED phase armed — the pin suites
  (`test/core/lean_core_pin_test.dart`, `test/core/trace_observer_test.dart`,
  `test/plugins/plugin_gate/*`) are written against the UNTRIMMED tree:
  the manifest still declares the four heavy packages, the barrel still
  re-exports them, no `TraceObserver`/plugin-gate code exists.
