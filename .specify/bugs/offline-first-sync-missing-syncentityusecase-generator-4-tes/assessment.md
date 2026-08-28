# Bug Assessment: Offline-First Sync: Missing SyncEntityUseCase generator + 4 test files (FR-007, FR-014)

- **Slug**: offline-first-sync-missing-syncentityusecase-generator-4-tes
- **Created**: 2026-08-27T14:26:41.982292+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/497
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

# Bug Assessment: Missing SyncEntityUseCase Generator + Incomplete Test Coverage (Feature 010)

**Feature**: 010-offline-first-sync
**Slug**: `010-offline-first-sync-missing-usecase-generator`
**Severity**: High
**Status**: Open
**Detected**: 2026-08-26 (during TDD verification)
**Assessor**: TDD verification (speckit-tdd-verify equivalent)

---

## Summary

The offline-first sync plugin (Feature 010) is missing the `SyncEntityUseCase` generator specified in FR-007 and task T030. Additionally, 4 of 7 required test files from Phase 7 (Tasks T047, T048, T050, T054) are absent, violating FR-014's requirement for generated tests.

---

## Root Cause Analysis

### 1. Missing SyncEntityUseCase Generator (FR-007, T030)

**Expected**: `lib/src/plugins/sync/generators/sync_usecase_generator.dart`
- Should generate `Sync<Entity>UseCase extends UseCase<void, NoParams>`
- Should call `repository.syncPending(cancelToken)`
- Should be wired into sync plugin flow for `--sync --with=usecase` or CRUD preset

**Actual**: No such file exists in the codebase.

**Evidence**:
- `lib/src/plugins/sync/generators/` directory does not exist
- `SyncPlugin.capabilities` only includes `CreateSyncCapability` (no usecase capability)
- `lib/src/plugins/di/di_plugin.dart` registers `Sync<Entity>UseCase` in `_generateRepositoryDI()` (line ~111 of tasks.md) but the generator to create the use case class is absent
- Search for `SyncEntityUseCase`, `sync_usecase_generator`, `SyncUseCase` in lib/ returns no implementation

**Impact**:
- FR-007 violated: "framework MUST generate a Sync<Entity>UseCase"
- US3 Independent Test cannot be executed: "trigger sync via use case → verify all pending entities are transmitted"
- US4 Acceptance A4.1: "developer calls the generated Sync<Entity>UseCase" - not possible
- A3.8: "Generated Sync<Entity>UseCase allows manual sync trigger" - not testable

### 2. Missing Test Files (FR-014, Phase 7 Tasks)

| Task | Expected File | Status | FR-014 Requirement |
|------|---------------|--------|-------------------|
| T047 | `test/plugins/sync/sync_plugin_test.dart` | **MISSING** | "generated tests for... sync-enabled repository and SyncStrategy" |
| T048 | `test/plugins/sync/sync_builder_test.dart` | **MISSING** | "generated tests for... sync-enabled repository and SyncStrategy" |
| T050 | `test/plugins/sync/bidirectional_sync_strategy_test.dart` | **MISSING** | "covering: push sync success, push sync failure with retry, read from local, and bidirectional pull sync" |
| T054 | `test/regression/sync_repository_test.dart` | **MISSING** | "generated tests for the sync-enabled repository and SyncStrategy" |

**Impact**:
- FR-014 explicitly requires: "The sync plugin MUST generate tests for the sync-enabled repository and SyncStrategy, covering: push sync success, push sync failure with retry, read from local, and bidirectional pull sync."
- 57% of required test files missing
- Bidirectional sync (US5) completely untested
- Plugin/Builder/CLI infrastructure untested

---

## Specification vs Implementation Gap

| Spec Requirement | Implementation | Gap |
|------------------|----------------|-----|
| FR-007: Generate Sync<Entity>UseCase | **Missing generator** | 🔴 Critical |
| FR-014: Generated tests for bidirectional pull sync | **Missing test file** | 🔴 Critical |
| FR-014: Generated tests for plugin/builder | **Missing test files** | 🟠 High |
| T030: Create SyncEntityUseCase generator | **Not implemented** | 🔴 Critical |
| T047: sync_plugin_test.dart | **Not created** | 🟠 High |
| T048: sync_builder_test.dart | **Not created** | 🟠 High |
| T050: bidirectional_sync_strategy_test.dart | **Not created** | 🔴 Critical |
| T054: sync_repository_test.dart | **Not created** | 🟠 High |

---

## Reproduction Steps

### For Missing UseCase Generator
1. Run `zfa make Product --sync --with=usecase --data --datasource --repository`
2. Check generated output for `SyncProductUseCase`
3. **Expected**: File `lib/src/domain/usecases/sync_product_usecase.dart` (or similar) generated
4. **Actual**: No SyncUseCase generated

### For Missing Bidirectional Tests
1. Run `dart test test/plugins/sync/bidirectional_sync_strategy_test.dart`
2. **Expected**: Tests for pullRemote, conflict resolution
3. **Actual**: "No such file or directory"

### For Missing Plugin/Builder Tests
1. Run `dart test test/plugins/sync/sync_plugin_test.dart`
2. **Expected**: Plugin registration, configSchema, capability tests
3. **Actual**: "No such file or directory"

---

## Suggested Fix

### Fix 1: Implement SyncEntityUseCase Generator
Create `lib/src/plugins/sync/generators/sync_usecase_generator.dart`:

```dart
import 'package:code_builder/code_builder.dart';
import '../../../core/builder/shared/spec_library.dart';
import '../../../models/generated_file.dart';
import '../../../models/generator_config.dart';
import '../../../utils/file_utils.dart';

class SyncUseCaseGenerator {
  final String outputDir;
  final SpecLibrary specLibrary;

  SyncUseCaseGenerator({
    required this.outputDir,
    SpecLibrary? specLibrary,
  }) : specLibrary = specLibrary ?? const SpecLibrary();

  Future<GeneratedFile> generate(GeneratorConfig config) async {
    final entityName = config.name;
    final entitySnake = config.nameSnake;
    final useCaseName = 'Sync${entityName}UseCase';
    final repoName = '${entityName}Repository';

    final fileName = 'sync_${entitySnake}_usecase.dart';
    final filePath = path.join(outputDir, 'domain', 'usecases', fileName);

    // ... generate UseCase that calls repository.syncPending()
  }
}
```

Add capability to `SyncPlugin.capabilities`:
```dart
@override
List<ZuraffaCapability> get capabilities => [
  CreateSyncCapability(this),
  CreateSyncUseCaseCapability(this),  // NEW
];
```

Wire in `SyncPlugin.generate()` or `SyncBuilder.generate()`.

### Fix 2: Create Missing Test Files

**T047 - test/plugins/sync/sync_plugin_test.dart**:
```dart
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/sync/sync_plugin.dart';

void main() {
  group('SyncPlugin', () {
    test('has correct id, name, version', () { ... });
    test('runAfter includes datasource and repository', () { ... });
    test('configSchema has sync-direction, sync-batch-size, sync-max-retries', () { ... });
    test('capabilities includes CreateSyncCapability', () { ... });
    test('generateWithContext builds correct GeneratorConfig', () { ... });
  });
}
```

**T048 - test/plugins/sync/sync_builder_test.dart**:
```dart
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/sync/builders/sync_builder.dart';

void main() {
  group('SyncBuilder', () {
    test('generates sync init file with Hive.openBox', () { ... });
    test('generates metadata store wrapper', () { ... });
    test('generates PushOnlySyncStrategy factory for push direction', () { ... });
    test('generates BidirectionalSyncStrategy factory for bidirectional direction', () { ... });
    test('regenerates sync index with initAllSyncs', () { ... });
  });
}
```

**T050 - test/plugins/sync/bidirectional_sync_strategy_test.dart**:
```dart
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zuraffa/src/plugins/sync/builders/bidirectional_sync_strategy.dart';

void main() {
  group('BidirectionalSyncStrategy', () {
    test('pullRemote fetches remote and saves to local', () { ... });
    test('conflict resolution: remote wins by default', () { ... });
    test('conflict resolution: custom resolver can return local', () { ... });
    test('local records not in remote are deleted when synced', () { ... });
  });
}
```

**T054 - test/regression/sync_repository_test.dart**:
```dart
@Tags(['regression', 'slow'])
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/repository/repository_plugin.dart';
import '../regression/regression_test_utils.dart';

void main() {
  // Full regression test verifying generated repo method bodies
}
```

---

## Acceptance Criteria for Fix

- [ ] `lib/src/plugins/sync/generators/sync_usecase_generator.dart` created and functional
- [ ] `SyncPlugin.capabilities` includes use case capability
- [ ] `zfa make <Entity> --sync --with=usecase` generates `Sync<Entity>UseCase`
- [ ] `test/plugins/sync/sync_plugin_test.dart` created and passes
- [ ] `test/plugins/sync/sync_builder_test.dart` created and passes
- [ ] `test/plugins/sync/bidirectional_sync_strategy_test.dart` created and passes
- [ ] `test/regression/sync_repository_test.dart` created and passes
- [ ] All 7 Phase 7 test files exist and pass
- [ ] FR-007 and FR-014 fully satisfied

---

## Related Files

- `lib/src/plugins/sync/sync_plugin.dart` - needs usecase capability added
- `lib/src/plugins/sync/generators/` - directory needs to be created
- `lib/src/plugins/sync/capabilities/` - needs `create_sync_usecase_capability.dart`
- `lib/src/plugins/di/di_plugin.dart` - already registers SyncUseCase (line ~111 in tasks.md)
- `test/plugins/sync/` - missing 3 test files
- `test/regression/` - missing 1 test file

---

## Timeline

**Detected**: 2026-08-26 during TDD verification
**Target Fix**: Before feature 010 considered complete
**Blocking**: Feature 010 completion (FR-007, FR-014 not met)

See https://github.com/arrrrny/zuraffa/issues/497.

## Symptom

[NEEDS CLARIFICATION]

## Reproduction

[NEEDS CLARIFICATION]

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: confirm the exact code path and a safe remediation.]
