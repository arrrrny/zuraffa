# Quickstart: validate `zfa make engine` (issue #1109)

Prerequisites: the `zfa` CLI built from this branch (`dart pub get` at repo root); a
sandbox project (e.g. `~/zik_zak_test`) with Flutter installed for its test lane.

## 1. Unit-level validation (this repo, fast)

```bash
dart test test/plugins/di/          # idempotency + resetDependencies behavioral tests
dart test test/engine/              # receipt v2, engine check legs (if suite split differs: dart test test/ --tags=fast, scoped)
dart analyze lib/src/engine lib/src/plugins/di lib/src/commands
```

Expected: all green, analyzer clean.

## 2. Sandbox end-to-end (the issue's proof)

```bash
cd ~/zik_zak_test
zfa make engine User --methods=get,create
zfa engine check User
```

Expected:

- `zfa make engine User` exits 0; the full slice exists (usecase, service, repository,
  datasource, mock, DI, tests); output names every generated file.
- `specs/<feature>/tdd/engine.receipt.json` exists with `mock_certified: true` and a
  `mock_class` for `get` and `create`.
- `zfa engine check User` exits 0 (analyze leg green, receipt certified, zero UI imports).
- The sandbox test lane passes for the engine slice's tests.

## 3. Idempotency proof

```bash
cd ~/zik_zak_test
zfa make engine User --methods=get,create   # second run
```

Expected: exit 0, no "already registered" failure; the receipt is overwritten (same shape,
no duplicates); a test that calls `setupDependencies()` twice, and one that calls
`resetDependencies()` then `setupDependencies()`, both pass.
