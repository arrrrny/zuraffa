# Data Model: `zfa make engine` One-Shot Preset (issue #1109)

## Entities

### Engine Slice
The full vertical artifact set generated for one entity. Not persisted as a unit; its
footprint is enumerated by the receipt's `source_files`.

- **Entity name** (PascalCase, e.g. `User`) → snake-case path segment (`user`)
- Layers: entity → usecase(s) → service → repository → datasource → mock datasource +
  seeded data → DI registration → test scaffold
- Boundary invariant: zero UI-framework imports across every file in the slice

### Engine Receipt v2 (issue contract — NEW)
Written to `specs/<feature>/tdd/engine.receipt.json` after every successful
`zfa make engine <Entity>` run.

| Field | Type | Rules |
|---|---|---|
| `entity` | string | PascalCase entity name |
| `methods` | array | one entry per generated method |
| `methods[].name` | string | method id (`get`, `getList`, `create`, `update`, `delete`, …) |
| `methods[].mock_certified` | boolean | true only when the certifier passed for that method |
| `methods[].mock_class` | string | class name of the certified mock (e.g. `MockUserDataSource`) |
| `source_files` | array of string | project-root-relative paths of every file the run generated |

Validation rules: written only after the certifier runs; re-runs overwrite (never append);
created directories as needed. Consumer: #1014/CERT-GATE reads it by convention.

### Engine Receipt v1 (existing, unchanged location)
`.zfa/engine.receipt.json`, schema `engine.v1` — entity digest, per-method certification,
DI wiring, engine-check outcome, generated files, options. Kept for existing readers;
gains no breaking change.

### Engine Check Result (extended)
`EngineCheckResult` gains the analyze leg:

- `failures: List<EngineCheckFailure>` — new `EngineFindingCode` value for static-analysis
  findings; each carries the file and the analyzer's message (actionable `--> fix:` hint)
- Pass condition: zero failures across (a) getIt resolution, (b) flutter-import guard,
  (c) `mock_certified: false` in the receipt, (d) NEW: `dart analyze` clean on slice files

### Idempotent DI Registration (generated artifact, not stored data)
- `setupDependencies(getIt)`: per type — `if (getIt.isRegistered<T>()) getIt.unregister<T>();`
  then the original registration call. Callable repeatedly without throwing.
- `resetDependencies(getIt)` (NEW): unregisters every type the file registered; test-lane
  teardown. Emitted in the same DI index file as `setupDependencies`.

## State transitions

- Receipt: absent → written (first run) → overwritten (re-run). No merge, no history.
- Check: pass ⇄ fail; failure always names the offending file/method.
- DI: unregistered → registered (idempotent); registered → reset → registered.
