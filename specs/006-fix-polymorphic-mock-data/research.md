# Research: Fix Polymorphic Mock Data Generation

**Date**: 2026-05-24 | **Feature**: 006-fix-polymorphic-mock-data

## Decision 1: How to Detect Dart `sealed class` Subtypes

**Decision**: Use regex-based source scanning within `getPolymorphicSubtypes()` to detect sealed class hierarchies, falling back to the existing `@Zorphy` annotation path if sealed class is not detected.

**Rationale**:
- `analyzeEntity()` already successfully uses regex-based parsing without requiring AST compilation. The existing codebase avoids `analyzer` package dependencies for performance reasons.
- The same-file constraint (standard Dart sealed class convention) makes regex feasible: subtypes are literally in the same `.dart` file.
- The `entity_command.dart` (line 679) already references `--sealed` flag concepts, showing the project already has awareness of sealed classes at the entity level.
- Regex pattern: `sealed\s+class\s+\w+` to detect sealed base, then `class\s+(\w+)\s+extends\s+{BaseName}` to find concrete subtypes. Exclude subtypes marked `abstract` or `sealed`.

**Alternatives considered**:
1. **AST-based detection using `package:analyzer`** — Too heavy; the mock plugin intentionally avoids analyzer dependency. Would add significant overhead to what should be a fast file-generation command.
2. **DiscoveryEngine-based file search for subtypes** — Would require searching all files for `extends BaseType` patterns across the project. Slower and unnecessary since Dart sealed classes require same-file subtypes by language spec.
3. **Manual annotation required from user** — Rejected; would require users to add annotations to entities that already have native Dart sealed class declarations. Redundant and poor UX.

**Implementation approach**:
```dart
// In getPolymorphicSubtypes(), after checking @Zorphy, add:
static List<String> getPolymorphicSubtypes(...) {
  // Existing @Zorphy check first (preserve backward compat)
  // ... existing code ...
  
  // NEW: sealed class detection
  final sealedSubtypes = _detectSealedSubtypes(content, entityName);
  if (sealedSubtypes.isNotEmpty) return sealedSubtypes;
  
  return [];
}

static List<String> _detectSealedSubtypes(String content, String entityName) {
  // Check if entity is declared as sealed class
  final sealedPattern = RegExp(r'sealed\s+class\s+' + entityName);
  if (!sealedPattern.hasMatch(content)) return [];
  
  // Find concrete subtypes: class X extends EntityName
  // Exclude: abstract class, sealed class, mixin
  final subtypePattern = RegExp(
    r'(?:^|\n)\s*(?:final\s+)?class\s+(\w+)\s+extends\s+' + entityName,
    multiLine: true,
  );
  return subtypePattern.allMatches(content)
    .map((m) => m.group(1)!)
    .where((name) {
      // Exclude abstract/sealed subtypes
      final declPattern = RegExp(r'(?:abstract|sealed)\s+class\s+' + name);
      return !declPattern.hasMatch(content);
    })
    .toList();
}
```

## Decision 2: Unified Polymorphic Detection — Zorphy + Sealed

**Decision**: `getPolymorphicSubtypes()` checks `@Zorphy` first (existing path), then sealed class (new path). Returns combined, deduplicated results. No breaking changes to existing callers.

**Rationale**:
- Callers (`mock_builder.dart`, `mock_entity_graph_builder.dart`, `mock_value_builder.dart`) all check `subtypes.isNotEmpty` to decide polymorphic vs. non-polymorphic paths. The return type (`List<String>`) is unchanged.
- A single entity could theoretically use both patterns (unlikely but possible with generated code). Deduplication handles this edge case.
- The existing unit test for `getPolymorphicSubtypes` (if it exists through mock_builder_test.dart) can be extended with sealed class test cases without restructuring.

**Alternatives considered**:
1. **Separate method `getSealedSubtypes()`** — Would require all callers to check two methods. More maintenance burden and inconsistent.
2. **Unified method with strategy parameter** — Over-engineering for a single boolean distinction.

## Decision 3: Error Handling in `_collectAndGenerateNestedEntities`

**Decision**: Add try-catch around the `analyzeEntity()` and `generateMockDataFile()` calls inside `_collectAndGenerateNestedEntities()` to prevent silent hangs, logging warnings for unresolvable types while continuing generation for other entities.

**Rationale**:
- The current code has zero error handling. Any exception in file I/O, regex parsing, or DiscoveryEngine causes the entire async pipeline to fail silently.
- The fix should be defensive: catch exceptions, log a warning, and continue processing remaining entities rather than aborting everything.
- This aligns with FR-008 and FR-009 (clear error messages instead of hangs).

**Implementation approach**:
```dart
try {
  final entityFields = EntityAnalyzer.analyzeEntity(baseType, outputDir, ...);
  // existing processing...
} catch (e) {
  print('Warning: Could not analyze entity type "$baseType": $e');
  continue; // Skip this type, continue with others
}
```

**Alternatives considered**:
1. **Fail fast on first error** — Worse UX. User would need to fix errors one at a time and re-run.
2. **Collect all errors, report at end** — Good UX but adds complexity. For this fix, per-type warnings with continue is sufficient.

## Decision 4: File Path Resolution Consistency

**Decision**: Update `getPolymorphicSubtypes()` to use `DiscoveryEngine.findFileSync()` for entity file resolution, matching the approach used in `analyzeEntity()` (commit `481d275`).

**Rationale**:
- `analyzeEntity()` uses `DiscoveryEngine(projectRoot: outputDir).findFileSync('$entitySnake.dart')` for glob-based search.
- `getPolymorphicSubtypes()` uses a hardcoded path: `$outputDir/domain/entities/$entitySnake/$entitySnake.dart`.
- This inconsistency means `analyzeEntity` could find an entity but `getPolymorphicSubtypes` would miss it, treating a polymorphic entity as non-polymorphic and triggering the bug.
- Fixing this provides defense-in-depth even if the main fix (sealed class detection) is the primary solution.

**Alternatives considered**:
1. **Keep hardcoded path** — Simple but fragile. Non-standard project layouts would break.
2. **Extract shared file resolution** — Good refactoring but out of scope for this bug fix.

## Decision 5: Deduplication of Subtypes

**Decision**: When both `@Zorphy(explicitSubTypes: [...])` and sealed class patterns are present, merge and deduplicate by subtype name (case-insensitive comparison for safety, though Dart class names are case-sensitive).

**Rationale**:
- Edge case from spec: "when an entity uses both sealed class and @Zorphy patterns, subtypes from both detection paths are included without duplication."
- Simple `Set<String>` conversion deduplicates naturally.
- No need for complex merging logic since same-name subtypes represent the same class.

## Summary

| Decision | Approach | Files Modified |
|----------|----------|---------------|
| Sealed class detection | Regex scan in `getPolymorphicSubtypes()` | `entity_analyzer.dart` |
| Unified detection | Check @Zorphy then sealed, deduplicate | `entity_analyzer.dart` |
| Error handling | try-catch in `_collectAndGenerateNestedEntities` | `mock_entity_graph_builder.dart` |
| Path resolution | Use DiscoveryEngine in `getPolymorphicSubtypes` | `entity_analyzer.dart` |
| Subtype deduplication | Set-based merge | `entity_analyzer.dart` |
