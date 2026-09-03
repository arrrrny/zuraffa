# Plan: 893-simulation-di-binding

- **Spec ID**: 893-simulation-di-binding
- **Created**: 2026-09-03

## Architecture

```
flutter run --dart-define=SIMULATION=true
       │
       ▼
┌─────────────────────┐
│  DI Container       │
│  (flavor: SIMULATION)│
│  ├─ MockAdapter1    │──▶ fixture.json (#832)
│  ├─ MockAdapter2    │──▶ fixture.json (#832)
│  └─ MockAdapterN    │──▶ fixture.json (#832)
│  Isolation Guard    │──▶ no real sockets (whitelist only)
└─────────────────────┘
       │
       ▼
  App boots on mocks + fixture data
  → Every feature DEMOABLE
```

## Phases

### Phase 1: simulation flavor detection
- Detect `--dart-define=SIMULATION=true` at DI registration time
- Route to simulation binding path instead of production binding

### Phase 2: generated simulation DI
- `zfa make --di` / `zfa mock create` generates DI registration code for mocks
- Flavor switch is single `--dart-define`, not hand-wired config
- Generated code registers mock datasources under simulation flavor

### Phase 3: fixture data wiring
- Each mock datasource loads committed fixtures from `specs/<feature>/tdd/fixtures/` (extends #832)
- Fixture registry from #832 reused for fixture loading
- No real network calls — all data from fixture files

### Phase 4: isolation guard
- Simulation mode never opens real sockets except through explicitly whitelisted lanes
- Guard asserts no network access at runtime
- Violations surface as runtime errors with clear messaging

### Phase 5: demoability proof
- Any feature reaching `complete(mocked)` is immediately DEMOABLE
- `flutter run --dart-define=SIMULATION=true` boots app on mocks
- No real adapter required — full feature visible in demo mode

## Files likely to change

- `lib/src/di/simulation_module.dart` (new — simulation flavor DI)
- `lib/src/di/isolation_guard.dart` (new — no real sockets)
- `lib/src/plugins/mock/mock_generator.dart` (extend — generate DI registration)
- `lib/src/simulation/fixture_registry.dart` (reuse from #832)
- `example/lib/main.dart` or `lib/main.dart` (flavor switch)

## Tests

- `simulation_di_test.dart` — mock DI registration works with SIMULATION=true
- `isolation_guard_test.dart` — real socket blocked in simulation mode
- `fixture_wiring_test.dart` — fixtures loaded from committed files
- `demo_boot_test.dart` — app boots on mocks without real adapters

## Risks

- Isolation guard must not false-positive on legitimate localhost dev
- Fixture files may go stale as APIs evolve (maintenance burden)
- Flavor detection must be reliable (not bypassed by accident)
- Generated DI code must not leak real adapter paths in simulation mode
