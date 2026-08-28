# TDD Test List — bug-make-id-neutral-524

## Acceptance behaviors (outer)

### A1 — id-neutral `--test` regeneration writes the usecase test instead of silently skipping
When `zfa make <IdLessEntity> --test` is run against an entity whose usecases
already exist as fixtures but whose native-mock data layer (datasource / mock
datasource / mock data / data repository) was never generated, the per-method
usecase test file must be **written** (not skipped), so the usecase test exists
and references the resolved representative field.

**Traced to tests** (all in `test/commands/make_command_test.dart`, group
"MakeCommand #508 id-neutral regeneration"):

- **#529** — `MakeCommand #508 id-neutral regeneration #508 — --test only on an
  id-less entity succeeds and references a real field`
  asserts `get_chat_message_usecase_test.dart` exists and contains
  `ChatMessageFields.content` (the first real scalar, never a synthetic id or the
  enum `role`).
- **#530** — `MakeCommand #508 id-neutral regeneration #508 — explicit
  --query-field is preserved on the id-neutral path`
  asserts the file exists and contains `ChatMessageFields.timestamp` (the
  user-provided `--query-field` wins over auto-resolution).
- **#535** — `MakeCommand #508 id-neutral regeneration #514 — no-id entity with
  usecase default-enabled: --test regenerates id-neutrally (drops the implied
  usecase)`
  asserts the file exists, contains `ChatMessageFields.content`, the implied
  `usecase` plugin was dropped (the pre-existing usecase stub is untouched), and
  no loud `#307` failure fired.

## Unit behaviors (inner)

### U1 — `TestPlugin` fills the native-mock gap before regenerating tests
For an entity-based `--test` run, `TestPlugin._ensureNativeMockInfra` writes a
minimal placeholder for any of the four required native-mock artifacts that are
absent, so `test_builder_entity`'s `missingNativeMockFile` guard passes.

### U2 — the hard skip guard is preserved for direct builder calls
`generateForMethod` still returns `action: 'skipped'` when the native-mock infra
is genuinely missing and it is invoked directly (the `test_builder_test`
"skips generation when native mock infrastructure is missing" case). This guards
against crashing when files are genuinely missing while keeping id-neutral
regeneration functional through the plugin path.

## Status
- A1 / #529 / #530 / #535: RED before fix (silent skip → `existsSync() == false`),
  GREEN after fix.
- U2: covered by existing `test_builder_test` assertion (unchanged, still green).
