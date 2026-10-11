# Contract: `zfa engine check <Entity>` (extended for #1109)

## Invocation

```
zfa engine check <Entity> [options]
```

## Checks (all must pass for exit 0)

1. **Static analysis** — `dart analyze` scoped to the entity's engine-tree files
   (`lib/**` and `test/**` paths containing the entity snake) reports no issues.
   Each finding becomes a failure entry with the file and analyzer message.
2. **Receipt certification** — `specs/<feature>/tdd/engine.receipt.json` exists for the
   entity and contains no `mock_certified: false`. A missing receipt is a failure
   ("run `zfa make engine <Entity>` first").
3. **Import boundary** — zero UI-framework imports across the engine tree (existing
   flutter-import guard).

## Output

- On success: summary of resolved getIt types, certified methods, and the three green legs; exit 0.
- On failure: one `--> fix:` hint per failure, naming the offending file / uncertified method /
  analysis finding; exit non-zero (64 on usage error, 1 on check failure).
- `--format=json`: machine-readable result including the failure list.

## Generated DI contract (pairs with the check)

- `setupDependencies(getIt)` — idempotent: unregister-before-register per type; callable repeatedly.
- `resetDependencies(getIt)` — unregisters every type the file registered; for test teardown.
  Calling `resetDependencies()` then `setupDependencies()` must not throw and must leave all
  types resolvable.
