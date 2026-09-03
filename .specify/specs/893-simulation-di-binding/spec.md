# 893-simulation-di-binding

- **Spec ID**: 893-simulation-di-binding
- **Created**: 2026-09-03
- **Source**: GitHub issue #914 (ROADMAP P1)
- **Type**: feature
- **Priority**: P1

## Problem

Every feature reaching `complete(mocked)` should be immediately DEMOABLE — shipping value before a single real adapter exists. Today there is no way to boot the app end-to-end on certified mocks with fixture data. DI registration is hand-wired, flavor switching is manual, and no isolation guard prevents real socket access in simulation mode.

## Goal

Generated DI registers mock datasources under a simulation flavor: `flutter run --dart-define=SIMULATION=true` boots the whole app on mocks with fixture data. Every feature reaching `complete(mocked)` is immediately demoable.

## Command contract

`zfa make --di / zfa mock create`:

1. **Simulation input**: generated registration reads the compile-time `SIMULATION` value exactly once. The literal `true` selects mock DI; the literal `false` or an absent value selects production DI; any other value is malformed, fails startup before registration, and selects neither graph. Persisted `ZfaConfig.mockByDefault` is a generation-time default only and MUST NOT influence runtime DI selection.
2. **Generated DI and mock discovery**: simulation binding is generated, not hand-wired; flavor switch is a single `--dart-define=SIMULATION=true`. Each `zfa make --di` / `zfa mock create` result MUST keep at least one canonical static-discovery contract: generated code imports `package:zuraffa/mock.dart`, generated code references `zuraffaMockLibrary`, or `.zfa.json` retains the canonical `mocking` block. Runtime flavor selection MUST NOT remove or replace that discovery signal.
3. **Fixture data**: every mock datasource uses committed fixtures from `specs/<feature>/tdd/fixtures/` (extends #832 simulate adapters).
4. **Isolation guard**: simulation mode never opens real sockets; `NetworkIsolationGuard` blocks every outbound socket attempt, including loopback, with no allowlisted lane (landed with #832).
5. **Feature completeness**: any feature reaching `complete(mocked)` is immediately DEMOABLE — no real adapter required.

## Why this matters

The demo-build dividend of mock-first: every feature is demoable before a single real adapter exists. This is the proof that mock-first delivers real value, not just test value.

## Success criteria

- `flutter run --dart-define=SIMULATION=true` boots the whole app on mocks with fixture data
- Generated DI is flavor-switched via single `--dart-define`, not hand-wired
- Simulation mode never opens real sockets (isolation guard)
- Every `complete(mocked)` feature is immediately demoable

## References

- #914 (GitHub issue, ROADMAP P1)
- #908 (Mock-First Realization parent)
- #832 (simulate adapters, isolation guard)
- #807 (proof-carrying)

## Out of scope

- Real adapter registration (separate concern)
- Multi-flavor simulation (single SIMULATION=true only)
