# Spec 1002 — zfa make engine <Entity>: one-shot engine-slice generation

GitHub issue: arrrrny/zuraffa#1002

## Problem

`zfa make Entity --preset=crud --with=vpc --state --di --mock --test
--route --append --cache --sync --datasource` chains seven generators
but:

- (a) it has no single verb — the engine-only path must be assembled by
  hand from preset + flags, and `entity create` is a separate
  precondition (`zfa make` fails fast when the entity file is missing);
- (b) it does not auto-certify mocks — nothing verifies that every
  requested method actually landed on the generated mock datasource with
  seeded data;
- (c) it does not write a receipt — no machine-checkable record of what
  was generated, certified, and wired;
- (d) it includes UI in the same run (`--with=vpc` pulls view /
  presenter / controller / state, which import `package:flutter`).

Additionally, any make run combining the `mock` and `di` plugins in ONE
transaction failed on master with a `Multiple operations for
lib/src/di/index.dart` commit conflict: the topological sort kept the
request order (… datasource, di, mock), `di` wrote `di/index.dart`, and
the mock plugin's simulation-index sync then appended to the same path
inside the same transaction.

## Deliverables

1. `zfa make engine <Entity>
   [--methods get,getList,create,update,delete]
   [--type future|stream|completable|background|os_background]
   [--cache] [--sync] [--datasource]` — a new top-level preset chaining
   entity create → usecase create → service create → repository create
   → datasource create → provider create → mock create --certify →
   di create → engine check. No Flutter-importing plugins. No route, no
   view, no presenter, no state, no controller.
2. `zfa engine check <Entity>` (new verb): resolves all `getIt<T>()`
   calls in the generated engine against generated classes; fails with
   `--> fix:` on any dangling reference.
3. Auto-receipt: `engine.receipt.json` with entity digest, methods
   generated, mocks certified (per-method), DI wired, file paths.

## Design

### The engine preset

`PresetRegistry` gains an `engine` entry chaining the engine-slice
generators:

```text
engine = [usecase, service, provider, repository, datasource, mock, di]
```

No view, no presenter, no controller, no state, no route (and no test —
the engine slice is the non-UI data+domain engine). The `zfa make
engine <Entity>` grammar is a mode token in `MakeCommand.run()`: the
exact lowercase `engine` as the first positional, the entity as the
second. An entity literally named `Engine` (PascalCase) still routes
through the classic grammar — no existing invocation changes meaning
(hard constraint: existing make semantics for non-engine presets are
untouched; all pre-existing presets and flags behave identically).

The engine path in `MakeCommand`:

1. **entity create (auto)** — when the entity file is missing (and
   `--no-entity` is not set), the engine chain generates it first via
   the same zorphy `EntityCreator` path `zfa entity create` uses, with
   a minimal `id: String` identity (the id-dependent generator
   signatures and the seeded mock data need a real identity). Plan-only
   mode never writes files, so the entity guard is skipped there.
2. **plugin chain** — the preset plugins run in one
   `PluginManager.run` transaction, topologically sorted. The
   `--methods` / `--type` / `--cache` / `--sync` / `--datasource` flags
   keep their existing make semantics. The default method set for a
   bare `zfa make engine <Entity>` is `get,getList,create,update,delete`
   (applied only when neither `--methods` nor `--from-json` supplies
   one). Flutter-importing plugins are hard-dropped from the active
   plan with a notice, even when a config default or alias pulled them
   in.
3. **mock create --certify** — after the transaction commits,
   `MockCertifier` verifies per requested method that the mock
   datasource implements the method AND the seeded mock data file
   exists. The same certifier powers the new `--certify` flag on
   `zfa mock create <Entity>`.
4. **di create** — part of the preset (di runs last via its `runAfter`
   edges).
5. **engine check** — `EngineChecker` resolves every `getIt<T>()`
   found in the entity's DI wiring against (a) the conventional DI
   registration file (`<snake>_di.dart` under `lib/src/di/`, reusing
   the spec-043 `ServiceLocatorAnalyzer`) and (b) any top-level type
   declaration under `lib/`. Dangling references fail with `--> fix:`
   hints. The check also enforces the purity exit criterion: zero
   `package:flutter` imports in the engine slice's lib files and test
   tree.
6. **receipt** — `EngineReceiptWriter` writes `.zfa/engine.receipt.json`
   (schema `engine.v1`): entity digest (sha256), methods with
   `mock_certified` per method, mock artifact paths, DI files +
   resolved getIt types, engine-check outcome, and all generated file
   paths.

### The `zfa engine check <Entity>` verb

A new top-level `EngineCommand` (registered in `CliRunner` alongside
`make`) with a `check` subcommand. It runs the same `EngineChecker`
and exits 0 / 1 (64 on usage errors). The requested method set for
mock certification is read from the engine receipt when one exists.
Every failure prints an actionable `--> fix:` line.

### The di+mock ordering fix

`DiPlugin.runAfter` gains `'mock'`, so di always runs AFTER the mock
plugin when both are active: the mock plugin writes the simulation
binding + `di/simulation/index.dart` first, and di's own main-index
regeneration then wires `registerSimulationBindings(getIt)` through
its simulation-index detection (spec 893 FR-002) — `di/index.dart` is
written exactly once. The mock plugin's redundant `syncMainIndex()`
append is skipped when the di plugin is co-active in the same run
(`PluginContext.isActive('di')`); standalone `zfa mock create` and
mock-only make runs keep the append exactly as before.

## Exit criteria

- `zfa make engine Login` produces a runnable engine slice in a single
  command. ✅ (e2e test: entity auto-created, full slice generated, no
  transaction conflict)
- `zfa engine check Login` exits 0. ✅ (e2e test, subprocess exit code)
- The engine slice's test tree contains zero `package:flutter`
  references. ✅ (e2e scan of `lib/` + `test/`; additionally enforced
  by `engine check` as a failure with a fix hint)
- `engine.receipt.json` lists all methods with `mock_certified: true`.
  ✅ (e2e receipt assertions)

## Acceptance (against 004-login-ui)

`zfa make engine Login` → `zfa engine check Login` exits 0;
`dart analyze lib/src/domain/ lib/src/data/ lib/src/services/` exits 0
in the generated tree.

Reproduced in-repo (see `tdd/verification.md`): `make engine` →
`dart pub get` (zuraffa path dep) → `zfa build` (the entity's concrete
part classes are generated by build_runner per the canonical v5
workflow) → `dart analyze lib/src/domain lib/src/data lib/src/di`
exits 0 with zero errors. Two honest notes:

- Services live under `lib/src/domain/services/` in the zuraffa fixed
  layout (not a separate `lib/src/services/` root); the analyze set
  above covers the same generated surface.
- `dart analyze` reports warnings for the pre-existing defensive
  `hide <Entity>, <Entity>Patch` clauses on framework-barrel imports
  (issue #942 guard) on ANY zuraffa-generated file, including on
  master. The acceptance gate `zfa build` itself applies the same
  errors-only standard; the in-repo acceptance run passes
  `--no-fatal-warnings` and asserts zero errors.

## Hard constraints

- Existing make semantics for non-engine presets are unchanged: the
  engine token is only the exact lowercase `engine` first positional;
  every other invocation routes through the classic grammar. All
  pre-existing presets, flags, and the entity-exists fail-fast behave
  identically (covered by the plan tests).
- One PR for this spec.
