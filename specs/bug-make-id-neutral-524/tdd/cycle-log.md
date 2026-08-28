# TDD Cycle Log — bug-make-id-neutral-524

## Cycle 1 — RED

Ran the three failing tests on `master` baseline:

```
dart test test/commands/make_command_test.dart \
  --name "id-neutral regeneration #50[48]"
```

### #529 — `--test` only on an id-less entity
```
⚠️  Skipping test generation for GetChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found.   (x3)
✅ Generation complete:
  ⏭ Skipped: 3 files
```
```
Expected: true
  Actual: <false>
```
`test/domain/usecases/chat_message/get_chat_message_usecase_test.dart`
`existsSync()` returned `false` → assertion at line 838 fails.

### #530 — explicit `--query-field timestamp`
Identical skip output (`Skipped: 3 files`); `getTest.existsSync()` returns `false`
→ assertion at line 888 fails. The `--query-field` assertion never executes
because the file is missing.

### #535 — no-id entity, `usecase` default-enabled
```
ℹ️  "ChatMessage" has no id field — dropping id-dependent plugins implied by
    config defaults (usecase) so id-neutral (--test/--mock) regeneration can proceed.
⚠️  Skipping test generation for GetChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found.   (x3)
✅ Generation complete:
  ⏭ Skipped: 3 files
```
`getTest.existsSync()` returns `false` → assertion at line 1022 fails.

Root cause confirmed in `lib/src/plugins/test/builders/test_builder_entity.dart`
(lines 130-142): the `missingNativeMockFile` guard returns
`action: 'skipped'` whenever any of the four native-mock artifacts is absent.

## Cycle 2 — GREEN

Fix: `lib/src/plugins/test/test_plugin.dart` now calls
`_ensureNativeMockInfra(config, fs)` (gated on `config.generateTest &&
config.isEntityBased`) before the per-method loop. It writes a minimal
native-mock placeholder for any of the four required artifacts that are missing
(`*_datasource.dart`, `*_mock_datasource.dart`, `*_mock_data.dart`,
`data_*_repository.dart`), so `test_builder_entity`'s guard passes and the
usecase test is written and compiled. The guard itself is untouched, so direct
`generateForMethod` calls still skip (see verification.md).

Re-ran the same command on `fix/make-id-neutral-524`:
```
00:01 +4: All tests passed!
```
All three (#529, #530, #535) plus the two loud-failure tests in the same group
(#508/#307 id-dependent and mixed `--methods`) still pass — no regression.

`dart analyze lib/src/plugins/test lib/src/commands` → `No issues found!`
