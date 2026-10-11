# Issue 1719 — provider create: `--force`/`--revert` flags are no-ops and generated provider has duplicate members when service has `--init` + appended methods

- **Repo:** arrrrny/zuraffa
- **Severity:** high
- **Component:** `zfa provider create` / `zfa service create` (CLI generation)
- **Status:** open

## Summary

`zfa provider create` ignores `--force` and `--revert` when the target
provider file already exists — both invocations print the same
`⏭ Skipped (use --force to overwrite)` hint, and the only escape is deleting
the file by hand. On top of that, when the service was created with `--init`
(and members appended), the generated provider carries duplicate
non-compiling members for `isInitialized`, `initialize` and `dispose`.
Finally, `zfa service create ... --force` has the same no-op overwrite bug.

## Reproduction

```bash
zfa service create Auth --params=AuthRequest --returns=User --type=usecase --init
# (append further service methods)
zfa provider create Auth --params=AuthRequest --returns=User --type=usecase --init
# ... then edit + re-run:
zfa provider create Auth --params=AuthRequest --returns=User --type=usecase --force
# ⏭ Skipped (use --force to overwrite): .../auth_provider.dart   <-- --force passed!
zfa provider create Auth --params=AuthRequest --returns=User --type=usecase --revert
# ⏭ Skipped (use --force to overwrite): .../auth_provider.dart   <-- --revert demands --force
zfa service create Auth --params=AuthRequest --returns=User --type=usecase --init --force
# ⚠️ No files were generated (nothing changed). Re-run with --force to overwrite the existing service file.
```

The provider emitted on the first run contains, for the interface members
declared by the `--init` service:

- `Stream<bool> isInitialized(NoParams params)` (method) **and**
  `Stream<bool> get isInitialized` (getter) — duplicate name; the method
  does not implement the interface getter
- `Future<void> initialize(InitializationParams params)` **twice** — same
  signature, compile error
- `Future<void> dispose(NoParams params)` **and** `Future<void> dispose()` —
  duplicate name with mismatched signatures

`dart analyze` on the fixture reports three `duplicate_definition` errors.

## Expected behavior

1. `--force` actually overwrites the existing provider/service file.
2. `--revert` deletes the generated file without demanding `--force`.
3. Provider generation emits **exactly one implementation member per
   interface member, matching the interface signature**: a getter for
   `Stream<bool> get isInitialized`, one `initialize(InitializationParams)`,
   and a parameter-less `dispose()`.
