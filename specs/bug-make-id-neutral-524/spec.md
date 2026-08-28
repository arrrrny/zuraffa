# Bug: id-neutral `--test` regeneration silently skips usecase tests when native-mock infra is absent

Three id-neutral `zfa make <Entity> --test` regeneration tests fail with
`Expected: true / Actual: <false>`:

- **#529** — `--test` only on an id-less entity succeeds and references a real field.
- **#530** — explicit `--query-field` is preserved on the id-neutral path.
- **#535** — no-id entity with `usecase` default-enabled: `--test` regenerates
  id-neutrally and drops the implied `usecase`.

**Symptom:** `test/commands/make_command_test.dart` asserts that
`test/domain/usecases/chat_message/get_chat_message_usecase_test.dart` is
regenerated, but the generator prints
`⚠️ Skipping test generation for GetChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found`
and reports `✅ Generation complete: ⏭ Skipped: 3 files`, so the file is never
written and `existsSync()` returns `false`.

**Root cause:** commit `5b2655bf` (#524, "Remove mocktail; generate native zuraffa
mocks in all tests") added a hard skip in
`lib/src/plugins/test/builders/test_builder_entity.dart` (the
`missingNativeMockFile` guard at lines 130-142). It skips per-method usecase test
generation whenever any of the four native-mock artifacts
(`*_datasource.dart`, `*_mock_datasource.dart`, `*_mock_data.dart`,
`data_*_repository.dart`) is missing. The id-neutral `#508`/`#514` fixtures seed
only the entity file and the usecase stubs (matching the documented premise:
"usecases already exist; `--test` only regenerates their test files"), so the
guard always fires and hides the gap.

**Fix:** `lib/src/plugins/test/test_plugin.dart` now ensures the four native-mock
artifacts exist before regenerating usecase tests — emitting a minimal
placeholder for any that are missing on the id-neutral path. This lets the guard
in `test_builder_entity.dart` pass and the usecase test is actually written and
compiled, instead of being silently skipped. The hard guard is preserved for
direct `generateForMethod` calls, so the existing `test_builder_test`
"skips when native mock missing" assertion is unaffected. A full CRUD+mock stack
already has these files, so the change is a no-op there.
