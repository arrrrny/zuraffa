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

## Cycle: U1-U4 (red)

- behavior: U1, U2, U3, U4-U7 pins
- kind: red
- test: test/core/lean_core_pin_test.dart (U1: manifest still carried the
  four heavy packages; U2: lib/ still imported them + barrel re-exported
  otel api), test/core/trace_observer_test.dart (compile red — no seam),
  test/plugins/plugin_gate/* (missing gate/command; the pre-existing
  `zfa plugin enable graphql` wrote generation-plugin state only, output
  `Enabled plugin: graphql` — no `already enabled`, no capabilities)
- at: 2026-09-15

## Cycle: U1-U7 + A1-A4 (green)

- kind: green
- fix: TraceObserver seam + de-typed hook/usecase/stream_usecase;
  PluginCatalog/PluginGate + `capabilities:` persistence + extended
  `zfa plugin` command; heavy code MOVED to packages/zuraffa_graphql
  (12 files incl. slice_orchestrator + generate command),
  packages/zuraffa_storage (MinioClient + both MinIO hooks),
  packages/zuraffa_observability (otel tracer/reporter/TelemetryHook +
  OtelAdapter); core barrel slimmed (otel api re-export, MinioClient,
  TelemetryHook, moved graphql exports removed; facade conveniences
  enableOtelReporting/enableMinIOArtifacts moved to companions; core
  gains registerOtelLogExporter); pubspec trimmed; graphql capability
  command gated via PluginGate.refusalFor
- evidence:
  - `dart test test/core/lean_core_pin_test.dart test/core/trace_observer_test.dart`
    → `+9: All tests passed!`
  - `dart test test/plugins/plugin_gate/` → `+13: All tests passed!`
  - companions (A4): zuraffa_graphql `+47: All tests passed!`,
    zuraffa_storage `+14 ~1: All tests passed!`,
    zuraffa_observability `+19: All tests passed!` (+ init pin)
  - root regression: test/plugins/tdd/commands `+541: All tests passed!`;
    test/commands + test/graphql + test/simulation `+734: All tests
    passed!`; test/core + remaining test/plugins verified in the full
    background lane (+3297 before the disk-space kill; the 6 apparent
    failures were `No space left on device` kernel-cache load errors,
    re-verified green after cache cleanup)
  - A1: fresh consumer (path dep) → lockfile has 0 of
    graphql/gql/minio/opentelemetry, no protobuf/xml (only core's own
    `uuid` remains of the secondary set)
  - `dart analyze lib` → 0 errors; companions → 0 errors
- at: 2026-09-15
