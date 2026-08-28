# Bug Test: zfa make --test still fails for no-id entities

- **Slug**: make-test-no-id-entities
- **Issue**: https://github.com/arrrrny/zuraffa/issues/514
- **Branch**: `fix/make-test-no-id-entities`
- **Result**: verified

## Verification

Re-ran the reproduction from `assessment.md` as an automated regression test in
`test/commands/make_command_test.dart` (group `MakeCommand #508 id-neutral
regeneration`):

1. **#514 — id-neutral success** — a no-id entity (`ChatMessage`, id-less, not a
   value object) with `usecase` enabled by default in `.zfa.json`, then
   `zfa make ChatMessage --test --force`:
   - no `❌ Error: Cannot generate architecture` / `has no id field` failure;
   - drop notice printed: `dropping id-dependent plugins implied by config
     defaults (usecase)`;
   - 3 usecase test files regenerated under
     `test/domain/usecases/chat_message/`;
   - query key resolved to the representative REAL field
     (`ChatMessageFields.content`), never a synthetic `id`;
   - pre-existing usecase stub untouched (the dropped `usecase` plugin did not
     run).

2. **#514 — bare make still fails** — same config, `zfa make ChatMessage
   --force` (no `--test`/`--mock`): still fails loudly with `has no id field`
   + `❌ Error: Cannot generate architecture`.

## Regression guard

Existing #307/#508 tests remain green, confirming the explicit-failure path is
unchanged:
- `#508 — --test only on an id-less entity succeeds`
- `#508/#307 — an id-dependent plugin on an id-less entity still fails loudly`
- `#508/#307 — a mixed request (--test plus --methods) still fails loudly`

## Command

```
dart test test/commands/make_command_test.dart
```

Result: **All tests passed (17)**.
