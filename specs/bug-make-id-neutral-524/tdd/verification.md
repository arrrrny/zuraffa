# Verification — bug-make-id-neutral-524

## Verdict
**FIXED / GREEN.** All three id-neutral `--test` regeneration tests pass on the
`fix/make-id-neutral-524` branch at `master` HEAD:

- `test/commands/make_command_test.dart` `--name "id-neutral regeneration #50[48]"`
  → `All tests passed!` (the three target tests + the two loud-failure tests in
  the same group, confirming no regression in the `#307` id-dependent paths).
- `dart analyze lib/src/plugins/test lib/src/commands` → `No issues found!`
- The existing `test/plugins/test_builder_test.dart` assertion
  "skips generation when native mock infrastructure is missing" still passes
  (`+1: All tests passed!`), confirming the hard guard in `generateForMethod` is
  preserved for direct builder calls.

## What was changed
- `lib/src/plugins/test/test_plugin.dart`: added `_ensureNativeMockInfra` +
  `_nativeMockPlaceholder`, called from `generate()` (gated on
  `config.generateTest && config.isEntityBased`) before the per-method loop. It
  fills any missing native-mock artifact with a minimal placeholder so the
  per-method test builder's guard no longer silently skips.
- No change to `test_builder_entity.dart`'s guard (kept intact), no change to the
  test fixtures, no change to `test_builder_helpers.dart` / `test_command.dart`.

## Deliberate-mutant note
To prove the fix is load-bearing (not green by accident), reintroduce the old
hard skip so that `TestPlugin` does NOT fill the gap — i.e. revert the
`_ensureNativeMockInfra` call in `test_plugin.dart` (leave
`test_builder_entity.dart` exactly as on `master`). With the plugin no longer
seeding the native-mock artifacts, `generateForMethod`'s
`missingNativeMockFile` guard fires again and emits:

```
⚠️  Skipping test generation for GetChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found.   (x3)
✅ Generation complete:
  ⏭ Skipped: 3 files
```

Re-running `dart test test/commands/make_command_test.dart --name "id-neutral
regeneration #50[48]"` then fails exactly as before:

- #529 → `Expected: true / Actual: <false>` at the `existsSync()` assertion.
- #530 → `Expected: true / Actual: <false>` at the `existsSync()` assertion.
- #535 → `Expected: true / Actual: <false>` at the `existsSync()` assertion.

Thus removing the fix makes the three tests fail again, confirming the fix is the
cause of the green state.
