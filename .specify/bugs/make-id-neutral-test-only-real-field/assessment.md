# Bug Assessment: id-neutral `--test` regeneration silently skips on id-less entity (native mock file not found)

- **Slug**: make-id-neutral-test-only-real-field
- **Created**: 2026-08-28
- **Source**: pasted text (failing test report)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Failing test (Linux): `test/commands/make_command_test.dart:838`
Test name: "MakeCommand #508 id-neutral regeneration #508 — --test only on an id-less entity succeeds and references a real field"

Assertion failure:
```
Expected: true
  Actual: <false>
```

Generator output captured during the failing run:
```
the get usecase test must be regenerated
output:
  ⚠️  Skipping test generation for GetChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found.
  ⚠️  Skipping test generation for UpdateChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found.
  ⚠️  Skipping test generation for ToggleChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found.
✅ Generation complete:
  ⏭ Skipped: 3 files
```

The id-neutral regeneration (entity with no id field) skips test generation because the
native mock file is "not found", but the test expects the get-usecase test to be regenerated
and to reference a real field (`ChatMessageFields.content`).

Environment: Linux x64, Dart SDK 3.13.1. Reference: macOS suite = 1640 pass / 1 skip / 9 fail;
this Linux run = 1681 pass / 1 skip / 8 fail.

## Symptom

`zfa make ChatMessage --test --force` on an id-less entity (ChatMessage: `role`, `content`,
`timestamp`, no id) is supposed to regenerate the usecase test files id-neutrally and reference
a real representative field (`content`). Instead, the test plugin silently skips all three
usecase test files because the native mock infrastructure (`chat_message_datasource.dart`) is
"not found", so `test/domain/usecases/chat_message/get_chat_message_usecase_test.dart` is never
written and the test's `expect(getTest.existsSync(), isTrue)` fails.

## Reproduction

1. Create an id-less entity `ChatMessage` whose first field is an enum (`role`), plus `content`
   (String) and `timestamp` (DateTime) — `test/commands/make_command_test.dart:770-785`
   (`writeIdLessEntity`).
2. Write pre-existing usecase source stubs only (`get_/update_/toggle_chat_message_usecase.dart`)
   — `test/commands/make_command_test.dart:790-800` (`writeExistingUseCases`). No datasource,
   mock datasource, mock data, or repository is written (matching the #508 premise: usecases
   already exist, `--test` only regenerates their tests).
3. Run `zfa make ChatMessage --test --force --output <dir>`.
4. Observe the warnings "Native mock file (chat_message_datasource.dart) not found" and 3 skipped
   files; `get_chat_message_usecase_test.dart` is absent → assertion at line 838 fails.

## Suspected Code Paths

- `test/commands/make_command_test.dart:838-842` — the failing assertion
  (`getTest.existsSync()` must be true, "the get usecase test must be regenerated").
- `test/commands/make_command_test.dart:770-800` — the fixture: seeds only the entity file and
  usecase **stubs** (no datasource / mock datasource / mock data / repository). This is what
  makes the native-mock prerequisite unavailable.
- `lib/src/plugins/test/builders/test_builder_entity.dart:130-142` — the `missingNativeMockFile`
  guard: when any of `chat_message_datasource.dart`, `chat_message_mock_datasource.dart`,
  `chat_message_mock_data.dart`, `data_chat_message_repository.dart` is missing it `print`s a
  warning and returns `GeneratedFile(..., action: 'skipped')` **without writing the test**. This
  is the silent skip that breaks the assertion.
- `lib/src/plugins/test/builders/test_builder_entity.dart:111-121` — `discovery.findFileSync`
  for the four native-mock files; all resolve to `null` in the fixture, so the guard fires.
- `lib/src/plugins/test/builders/test_builder_entity.dart:123-128` — the earlier `useCaseFile`
  guard passes (the stub usecase exists), so generation reaches the native-mock guard.
- `lib/src/plugins/test/test_plugin.dart:55-70` — `runAfter` lists `usecase`, `repository`,
  `service`, `datasource`, `provider`, `view`, `presenter`, `controller`, `di`, `feature`, `gql`,
  `cache`, `route`, `shadcn` but **NOT `mock`**. So a `--test`-only invocation does not generate
  the native mock infrastructure the test builder requires.
- `lib/src/commands/make_command.dart:585-610` — the id-neutral path that resolves the
  representative REAL query field (`content`) for id-less entities. This part works and the
  resolved `query-field` is passed into `GeneratorConfig`; the gap is downstream in the test
  builder's hard prerequisite, not in field resolution.
- `lib/src/commands/make_command.dart:509-583` — the #508/#514 id-neutral id-dependent-plugin
  drop logic; works correctly (no loud #307 failure is raised for `--test`).

## Root Cause Hypothesis

High confidence on location; medium on where the fix belongs.

The id-neutral `--test` regeneration path (#508) correctly suppresses the #307 loud "no id
field" failure and resolves a representative real field (`content`) for id-less entities
(`make_command.dart:585-610`). However, the test plugin's per-method builder
(`generateForMethod`) hard-requires the **native mock infrastructure** files
(`chat_message_datasource.dart`, `chat_message_mock_datasource.dart`,
`chat_message_mock_data.dart`, `data_chat_message_repository.dart`) to be present and silently
skips generation when any are absent (`test_builder_entity.dart:130-142`). Because `--test` alone
is id-neutral and `TestPlugin.runAfter` does not include `mock` (`test_plugin.dart:55-70`), those
files are never generated, so the get/update/toggle usecase test files are never written —
contradicting the test's expectation that `--test` regenerates the get usecase test referencing
the real field (`ChatMessageFields.content`). The skip is silent (returns
`action: 'skipped'`), so `make` reports "Generation complete" with 3 skipped, hiding the gap.

## Proposed Remediation

**Preferred**: Make the id-neutral `--test` regeneration self-sufficient for native-mock tests.
The test builder emits a `Throwing{Entity}DataSource` plus a `Data{Entity}Repository` backed by
`{Entity}MockDataSource`/`{Entity}MockData`, so it needs those types to import. On the id-neutral
`--test` (or `--test` + id-less) path, detect the missing native mock infrastructure and generate
the minimal mock datasource interface + mock datasource + mock data + `Data*Repository` (as the
normal CRUD + `--mock` workflow would), then emit the test file. This both satisfies the failing
test and matches real-world behavior where `--mock` precedes `--test`.

**Alternatives**:
- Relax the `missingNativeMockFile` guard (`test_builder_entity.dart:130-142`) to emit the test
  file (with a warning) when the usecase file exists and a representative field is resolved —
  but the generated test still won't compile without the mock types, so only viable together with
  the generate-on-the-fly option above.
- If `--test`-only is genuinely unsupported for id-less / native-mock-dependent entities, replace
  the silent `skipped` return with a loud, actionable diagnostic (e.g. "run `zfa make <Entity>
  --mock` first, or use `--preset=crud --with=...,mock,test`") instead of a silent skip.
- Test-fixture fix: seed the native mock infrastructure in `writeExistingUseCases`
  (`make_command_test.dart:790-800`) so the fixture mirrors a real CRUD+mock project. This would
  make the test pass, but it papers over the generator gap (a real `--test`-only run still
  silently skips), so it should not be the sole fix.

**Files likely to change**:
- `lib/src/plugins/test/builders/test_builder_entity.dart` (the `missingNativeMockFile` guard,
  lines 130-142, and/or generating missing mock infra before emitting the test)
- `lib/src/plugins/test/test_plugin.dart` (optionally add `mock` to `runAfter`, or coordinate
  mock-infra generation on the id-neutral path)
- `test/commands/make_command_test.dart` (only if the fixture is also corrected — see above)

**Tests to add or update**:
- The existing `make_command_test.dart:802-857` (#508 id-neutral regeneration) should regreen once
  the test file is actually written. Consider adding an assertion that the run output does NOT
  contain "Skipping test generation ... Native mock file" for this id-neutral path, to lock the
  fix against silent skips.

## Risks & Considerations

- Generating mock infrastructure on the id-neutral `--test` path changes generator output; ensure
  it does not overwrite user-edited mock datasources/repositories (respect `force` and `revert`).
- The native-mock test imports `zuraffa_flutter` / `flutter_test` vs pure-`test` based on
  `isFlutterProject` (`test_builder_entity.dart:144-147`); any generated mock infra must match the
  same target.
- Be careful not to re-arm the #307 loud failure for id-neutral intent (`--test`/`--mock`); the
  fix must stay on the id-neutral branch already established at `make_command.dart:509-583`.
- Blast radius is limited to id-less entities on the `--test`-only (or `--mock`-only) path; full
  CRUD stacks that include `--mock` are unaffected because the mock files already exist.

## Open Questions

- [NEEDS CLARIFICATION] Is `--test`-only on an id-less entity an officially supported workflow, or
  is it expected that `--mock` (or a full `--preset=crud --with=...,mock,test`) always runs first?
  This determines whether the fix belongs in the generator (generate missing mock infra) or the
  test fixture (seed it). The bug report frames it as a generator gap.
- Whether the macOS 9-fail / Linux 8-fail difference includes this exact test or a parallel one.
