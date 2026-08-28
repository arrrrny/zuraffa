# Bug Assessment: id-neutral `--test` regeneration skips test generation when native-mock/datasource infra is absent

- **Slug**: make-id-neutral-query-field-preserved
- **Created**: 2026-08-28
- **Source**: pasted text (failing Linux test report)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Failing test (Linux): `test/commands/make_command_test.dart:888`
Test name: "MakeCommand #508 id-neutral regeneration #508 — explicit --query-field is preserved on the id-neutral path"
Assertion failure:
```
  Expected: true
    Actual: <false>
```
Generator output captured during the failing run:
```
  ⚠️  Skipping test generation for GetChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found.  (x3)
  ✅ Generation complete:
    ⏭ Skipped: 3 files
```
The id-neutral regeneration skips test generation ("Native mock file not found") and the test expects an explicit `--query-field` to be preserved on the id-neutral path.
Environment: Linux x64, Dart SDK 3.13.1. Reference: macOS suite = 1640 pass / 1 skip / 9 fail; this Linux run = 1681 pass / 1 skip / 8 fail.

## Symptom

On `zfa make ChatMessage --test --force [--query-field timestamp]` for an id-less entity whose usecases already exist as fixtures, the test generator silently **skips** producing `test/domain/usecases/chat_message/get_chat_message_usecase_test.dart` because the "native mock" infrastructure (`chat_message_datasource.dart`) is not present. The test then asserts `getTest.existsSync()` is `true` and fails (`Expected: true / Actual: <false>`). The `--query-field` preservation assertion never even runs because the file is missing.

## Reproduction

1. `dart test test/commands/make_command_test.dart -n "explicit --query-field is preserved on the id-neutral path"` (or run the whole `make_command_test.dart` group).
2. The fixture (`writeIdLessEntity` + `writeExistingUseCases`) writes only `domain/entities/chat_message/chat_message.dart` (id-less: `role` enum, `content` String, `timestamp` DateTime) and three FIXTURE-STUB usecase files (`get`/`update`/`toggle_chat_message_usecase.dart`). It deliberately creates **no** `chat_message_datasource.dart`, `chat_message_mock_datasource.dart`, `chat_message_mock_data.dart`, or `data_chat_message_repository.dart`.
3. The command runs `make ChatMessage --test --force` (the failing case also passes `--query-field timestamp`).
4. The test builder logs the 3 "Skipping test generation … Native mock file not found" warnings and emits `get_chat_message_usecase_test.dart` only if it also generated the native-mock infra — which it did not. `expect(getTest.existsSync(), isTrue)` at line 888 fails.

## Suspected Code Paths

- `lib/src/plugins/test/builders/test_builder_entity.dart:130-142` — **primary suspect**. `generateForMethod` builds a map of the four required native-mock files (`{entitySnake}_datasource.dart`, `{entitySnake}_mock_datasource.dart`, `{entitySnake}_mock_data.dart`, `data_{entitySnake}_repository.dart`) and, if the **first missing** one is `null`, prints the exact "Skipping test generation for $className: Native mock file ($missingNativeMockFile) not found." message and returns `action: 'skipped'`. This is the message in the failing run. The fixture provides none of these files, so the guard always trips.
- `lib/src/plugins/test/builders/test_builder_entity.dart:188-215` (approx) — the generated test body imports and wires the native-mock infra (`Throwing{Entity}DataSource`, `{Entity}MockDataSource`, `{Entity}MockData`, `Data{Entity}Repository`), which is why the guard assumes those files must pre-exist; on the id-neutral/`--test`-only path they generally do not.
- `lib/src/commands/make_command.dart:509-609` — the #508 id-neutral handling that **drops** the id-dependent `usecase` plugin for id-less entities when intent is `--test`/`--mock`, then resolves a representative `query-field`. This path is intentionally id-neutral, but it does **not** ensure the native-mock datasource/repository infra exists before handing off to the test plugin, so the test plugin's guard at `test_builder_entity.dart:130` still skips.
- `lib/src/utils/entity_field_resolver.dart` (`resolveIdField` / `resolveRepresentativeField`) — resolves the `query-field` default for id-less entities (the "real field" rule from the sibling test). Relevant to the `--query-field timestamp` assertion, but **not** the cause of the skip.
- `test/commands/make_command_test.dart:770-800` (`writeIdLessEntity`, `writeExistingUseCases`) — the fixture that omits the native-mock files, reproducing the skip.
- `test/commands/make_command_test.dart:802-857` — **sibling test** `#508 — --test only on an id-less entity succeeds and references a real field`. It uses the identical fixture and the identical `expect(getTest.existsSync(), isTrue)` assertion (line 838), so it very likely fails for the same reason on the same runs. This bug probably affects the whole #508 id-neutral/`--test`-only cluster, not just the single reported case.

## Root Cause Hypothesis

The native-mock requirement guard in `test_builder_entity.dart:130-142` is too strict for the id-neutral `--test`-only regeneration path. The test builder unconditionally requires the datasource/mock_datasource/mock_data/repository files to exist before generating a usecase test, because the generated test body injects and wires those native-mock types. On the #508 id-neutral path, however, the usecases already exist (as fixtures here, or from a prior generation in real usage) but the datasource/mock/repository infra was never generated — the command only asked for `--test`. The guard therefore skips all three test files, so `get_chat_message_usecase_test.dart` is never written and line 888's `existsSync()` assertion fails. The explicit `--query-field timestamp` is **not** what triggers the skip; it is only the test's secondary correctness assertion. Confidence: **high** that the skip-guard at `test_builder_entity.dart:130-142` is the mechanism; **medium** on which exact remediation is correct (see below).

## Proposed Remediation

**Preferred**: Relax the native-mock guard for the id-neutral/`--test`-only regeneration path. When the usecase file already exists and the only missing artifacts are the native-mock infra, `make ... --test` should generate that infra (or generate the test against inline `Throwing{Entity}DataSource`/`Data{Entity}Repository` declarations) instead of silently skipping. Concretely: in `make_command.dart` around the #508 id-neutral block (lines 585-609), ensure the datasource + mock + repository generators run (or are triggered) as prerequisites of the test plugin when `--test` is requested without `--mock`; and/or in `test_builder_entity.dart:130-142`, only skip when the usecase file itself is missing — i.e., make the native-mock requirement a generate-and-continue rather than a hard skip.

**Alternatives**:
- Have the test plugin generate the missing native-mock infra on demand (it already knows the entity/file names), so the produced test compiles without a separate `--mock` pass.
- Adjust the test fixture (`writeExistingUseCases`) to also write a minimal `chat_message_datasource.dart` + mock/repository, but this only fixes the test and would mask the real CLI gap for real id-less `--test` users.

**Files likely to change**:
- `lib/src/plugins/test/builders/test_builder_entity.dart` (the `130-142` skip guard)
- `lib/src/commands/make_command.dart` (the #508 id-neutral plugin/datasource ordering, lines 509-609)
- possibly `lib/src/plugins/test/test_plugin.dart` (test-plugin prerequisite wiring)
- `test/commands/make_command_test.dart` (assertions / fixture, only if the chosen fix changes the contract)

**Tests to add or update**:
- Lock the fix with a regression test asserting that `make <IdLessEntity> --test` regenerates `get_<entity>_usecase_test.dart` even when no datasource/mock infra exists, and that an explicit `--query-field` is honored (the reported case).
- Verify the sibling `(#508 — --test only on an id-less entity …)` test also passes after the fix (likely currently failing too).

## Risks & Considerations

- The guard at `test_builder_entity.dart:130-142` exists for a reason: the generated test body references native-mock types that must compile. Any relaxation must still emit compilable tests — generating the infra (or inline declarations) is safer than merely emitting a test that imports missing files.
- Changing the test plugin's prerequisites could affect the `--mock`/`--test` combined path and the mixed `#508/#307` loud-failure paths (see `make_command_test.dart:899-940`); keep the id-dependent loud failure intact.
- No production/runtime data impact — purely a code-generator + test behavior issue. Blast radius: `make … --test` (and `--test`-only regeneration) for id-less entities.
- The reported Linux/macOS fail counts differ (8 vs 9), suggesting platform or subset variance in this failing cluster; the fix should be validated on both.

## Open Questions

- [NEEDS CLARIFICATION: are the sibling #508 `--test`-only tests (e.g. `make_command_test.dart:802`) also failing on the reported Linux run, or only the `--query-field` variant? The identical fixture/assertion suggests they share the root cause.]
- [NEEDS CLARIFICATION: is the intended contract that `make <Entity> --test` with no `--mock` silently drops tests (current behavior), or that it generates the native-mock infra it needs (desired by the test)?]
