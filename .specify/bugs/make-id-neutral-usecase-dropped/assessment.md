# Bug Assessment: id-neutral `--test` regeneration skips usecase tests (native mock files not found)

- **Slug**: make-id-neutral-usecase-dropped
- **Created**: 2026-08-28
- **Source**: pasted text (automated triage, no human in the loop)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Failing test on Linux: `test/commands/make_command_test.dart:1022`
Test name: "MakeCommand #508 id-neutral regeneration #514 — no-id entity with usecase default-enabled: --test regenerates id-neutrally (drops the implied usecase)"
Assertion failure: `Expected: true` / `Actual: <false>`

Generator output captured during the failing run:
```
ℹ️  "ChatMessage" has no id field — dropping id-dependent plugins implied by config defaults (usecase) so id-neutral (--test/--mock) regeneration can proceed.
  ⚠️  Skipping test generation for GetChatMessageUseCase: Native mock file (chat_message_datasource.dart) not found.  (x3)
✅ Generation complete:
  ⏭ Skipped: 3 files
```
The no-id entity drops the implied usecase as expected, but the test expects `--test` to regenerate id-neutrally and the test generation is skipped because the native mock file is not found.

Environment: Linux x64, Dart SDK 3.13.1. Reference counts: macOS suite = 1640 pass / 1 skip / 9 fail; this Linux run = 1681 pass / 1 skip / 8 fail.

## Symptom

The id-neutral `--test` regeneration path for a no-id entity no longer produces the per-usecase test files (`get/update/toggle_chat_message_usecase_test.dart`). Instead the test generator prints `⚠️ Skipping test generation for <UseCase>: Native mock file (<entity>_datasource.dart) not found.` and skips all three, so the test's `expect(getTest.existsSync(), isTrue)` fails. The same skip behavior also breaks the two sibling #508 tests (lines 802 and 878), not just the reported #514 test at line 1022.

## Reproduction

1. In `test/commands/make_command_test.dart`, run the test group "MakeCommand #508 id-neutral regeneration".
2. The fixtures `writeIdLessEntity()` (writes `lib/src/domain/entities/chat_message/chat_message.dart`, an id-less entity) and `writeExistingUseCases()` (writes only `get/update/toggle_chat_message_usecase.dart` STUBS) seed a minimal workspace.
3. The test runs `zfa make ChatMessage --test --force` (and, for #514, with a `.zfa.json` enabling `usecase` by default).
4. For a no-id entity, the `#514` drop logic removes the implied `usecase` plugin, leaving only `test` active. The `test` plugin iterates `config.methods` (`get`,`update`,`toggle`) and asks `test_builder_entity.dart` to generate each usecase test.
5. `test_builder_entity.dart:130-142` hard-requires the native mock datasource files (`*_datasource.dart`, `*_mock_datasource.dart`, `*_mock_data.dart`, `data_*_repository.dart`). They were never generated (only usecase stubs exist), so all three are skipped → assertion fails.

I reproduced this locally:
```
$ dart test test/commands/make_command_test.dart -n "id-neutral|regenerates id-neutrally"
...
Failing tests:
  test/commands/make_command_test.dart: MakeCommand #508 ... --test only on an id-less entity succeeds and references a real field   (line 838)
  test/commands/make_command_test.dart: MakeCommand #508 ... explicit --query-field is preserved on the id-neutral path            (line 888)
  test/commands/make_command_test.dart: MakeCommand #514  ... no-id entity with usecase default-enabled ... drops the implied usecase (line 1022)
```
All three fail with identical `Skipped: 3 files` + "Native mock file ... not found" output. The other #508/#514 tests that expect a LOUD failure (mixed/--methods, bare make) still pass.

## Suspected Code Paths

- `lib/src/plugins/test/builders/test_builder_entity.dart:130-142` — **primary suspect**. The block computes `missingNativeMockFile` and **skips** test generation when any of `*_datasource.dart`, `*_mock_datasource.dart`, `*_mock_data.dart`, `data_*_repository.dart` is absent. `git blame` attributes this exact block to commit `5b2655bf` ("Remove mocktail; generate native zuraffa mocks in all tests", #524).
- `lib/src/plugins/test/test_plugin.dart:88-93` — `GeneratorConfig.methods` defaults to `['get', 'update', 'toggle']` when `context.data['methods']` is unset, so the test plugin always attempts to regenerate the three usecase tests even in id-neutral test-only mode.
- `lib/src/commands/make_command.dart:534-546` — the `#514` no-id logic drops the implied `usecase` plugin from `activePlugins`, leaving only `test` active. With `usecase`/`datasource` dropped, the required native-mock datasource files are never produced, so the test plugin's skip at the line above fires.
- `test/commands/make_command_test.dart:790-800` (`writeExistingUseCases`) and `:770-785` (`writeIdLessEntity`) — the fixtures seed ONLY usecase stubs, not the datasource native-mock layer that #524 now requires, so the affected tests cannot satisfy the new hard dependency.

## Root Cause Hypothesis

A regression introduced by commit `5b2655bf` (#524, "Remove mocktail; generate native zuraffa mocks in all tests"). Before #524, per-usecase tests were generated with `mocktail` and did **not** require the generated native-mock datasource files to exist. #524 reworked `test_builder_entity.dart` to emit native zuraffa mocks and added a hard gate (lines 130-142) that **skips** test generation whenever any of the four native-mock datasource files is missing.

The three id-neutral `--test` regeneration tests (#508 @802, #508 @878, #514 @1022) were authored under the pre-#524 model, where a minimal fixture (id-less entity + usecase stubs only) was sufficient for `--test` to regenerate the usecase test files. After #524, the same fixtures no longer satisfy the new hard dependency, so all three usecase tests are skipped and the assertions expecting the generated files fail. `make_command_test.dart` was only touched by ±2 lines in #524, so these fixtures were never updated.

Confidence: **high** — confirmed by `git blame` (the skip block is entirely from #524) and by local reproduction showing all three tests fail with the identical skip message.

## Proposed Remediation

**Preferred (test-fixture fix, lowest risk):** Update the id-neutral `#508`/`#514` test fixtures in `test/commands/make_command_test.dart` so the seeded "pre-existing architecture" also includes the native-mock datasource layer that #524 now requires. Add a helper (e.g. `writeExistingDataLayer()`) that writes `chat_message_datasource.dart`, `chat_message_mock_datasource.dart`, `chat_message_mock_data.dart`, and `data_chat_message_repository.dart` alongside the existing usecase stubs, mirroring the real `zfa make --preset=crud` output. This matches the feature's actual premise ("the architecture already exists; `--test` only regenerates test files") and keeps the #514 assertions valid (test file regenerated; usecase stub left untouched because the implied `usecase` plugin is dropped).

**Alternative (production relaxation):** Relax the hard skip at `test_builder_entity.dart:130-142` so the id-neutral `--test` regeneration still emits a usecase test when native-mock datasource files are absent — using the already-generated `Throwing{Entity}DataSource` path (which the test file defines itself and does not need external files) for the failure case, and only skipping the success-path mock import when the native mocks are truly missing. This preserves id-neutral regeneration as a documented feature even when only the usecase layer pre-exists, but it reduces test coverage for the success path and needs care to keep generated tests compilable.

**Files likely to change**:
- `test/commands/make_command_test.dart` (fixtures for the three failing tests) — preferred.
- `lib/src/plugins/test/builders/test_builder_entity.dart` (lines 130-142) — only if the production-relaxation alternative is chosen.

**Tests to add or update**:
- The three failing tests themselves should be healed by the fixture change; add a focused regression test asserting that id-neutral `--test` regeneration on a fully-seeded architecture (entity + usecases + datasource native mocks) regenerates the usecase test files with the representative real query field and without `ChatMessageFields.id`.

## Risks & Considerations

- The production-relaxation alternative changes generated test structure and could affect compilation of other usecase tests; it must be validated against the full `test/plugins/test_builder_test.dart` suite (#524 added `test/plugins/test_builder_test.dart`).
- The fix must keep the #514 "implied usecase dropped → usecase stub untouched" assertion intact; the fixture change must NOT cause the `usecase` plugin to run.
- Scope is broader than the single reported test: three tests (#508 @802, #508 @878, #514 @1022) share the same root cause and should be fixed together.
- In real `zfa make --preset=crud --test` workflows the datasource native-mock files exist, so end users are unlikely to hit the silent skip; the impact is primarily the test suite / the narrow "regenerate tests for usecases-only" scenario.

## Open Questions

- [NEEDS CLARIFICATION: intended behavior] Is id-neutral `--test` regeneration meant to work when ONLY the usecase layer pre-exists (no datasource native mocks), or must the full datasource layer be present? The test premise says "usecases already exist; --test only regenerates their test files", which favors the production-relaxation fix; the real-world workflow favors the fixture fix. This determines which remediation is "correct".
- [NEEDS CLARIFICATION] Was the #514 test (commit `d9816459`, #515) green after its own merge and only broken by #524, or was it already flaky? (Local reproduction shows it fails now; confirming the before/after would pin the regression to #524.)
