# Test — Bug 1719 (provider create: `--force`/`--revert` no-ops + duplicate members)

## Regression suite

`test/fixes/bug_1719_provider_force_revert_duplicate_members_test.dart`
(fast tier — capability-level, temp-dir fixtures, no subprocesses). The
fixtures construct the plugins with the DEFAULT `GeneratorOptions()`, i.e.
the configuration the CLI actually uses; earlier suites that passed
`GeneratorOptions(force: true)` masked the options-vs-config flag drop.

| # | Defect | Assertion |
|---|--------|-----------|
| B1 | D1 `--force` | provider `execute({..., force: true})` on an existing file → action `overwritten`, hand-edited content replaced |
| B2 | D1 `--revert` | provider `execute({..., revert: true})` on an existing file → action `deleted`, file gone, no `--force` required |
| B3 | D2 duplicates | provider `--init` vs `--init` service → exactly one `Stream<bool> get isInitialized` (getter), zero `isInitialized(` method shapes, one `initialize(`, one `dispose(`, `Future<void> dispose()` present, no `dispose(NoParams` |
| B4 | D2 signatures | provider without `--init` vs `--init` service → same signature-faithful shapes with stub bodies |
| B5 | D3 service `--force` | service `execute({..., force: true})` on an existing file → action `overwritten`, content replaced |
| B6 | D3 service `--revert` | service `execute({..., revert: true})` → action `deleted`, file gone |

## TDD cycle

- **RED:** `tdd/red-T001-bug1719.log` — `00:00 +0 -6: Some tests failed.`
  (all six fail with the defect signatures: `skipped` instead of
  `overwritten`/`deleted`; duplicate member counts).
- **GREEN:** `tdd/green-T001-bug1719.log` — `00:00 +6: All tests passed!`
- **Refactor:** none needed beyond the fix itself (formatter run recorded
  in `verification.md`).

## Live CLI verification (scratch fixture, zuraffa path dependency)

```
zfa service create Auth --params=AuthRequest --returns=User --type=usecase --init
zfa provider create Auth --params=AuthRequest --returns=User --type=usecase --init
zfa provider create Auth ... --init --force   →  📝 <provider> (overwritten, exit 0)
zfa provider create Auth ... --revert         →  🗑 <provider> (deleted, exit 0)
zfa service create Auth ... --init --force    →  📝 <service> + conformance pass
zfa service create Auth --revert              →  ✅ Reverted (deleted): 🗑 <service>
dart analyze lib/src                          →  No issues found!
```

The final generated provider implements the `--init` interface with exactly
one member per interface member (`get isInitialized` → getter with
`const Stream.empty()`, `initialize(InitializationParams params)`,
parameter-less `dispose()`).

## Out-of-scope behavior verified unchanged

- `dart test test/plugins/provider test/plugins/service test/fixes` —
  93 passed / 0 failed (before fix: same suites green on master).
- `dart test test/commands` — 306 passed / 0 failed.
- Full fast suite via the repo's disk-safe chunked runner — recorded in
  `verification.md`.
