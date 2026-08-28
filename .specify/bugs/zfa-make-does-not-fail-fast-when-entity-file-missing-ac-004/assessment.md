# Bug Assessment: zfa make does not fail fast when entity file missing (AC-004)

- **Slug**: zfa-make-does-not-fail-fast-when-entity-file-missing-ac-004
- **Created**: 2026-08-27T14:26:42.487376+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/496
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

# Bug Assessment: zfa make does not fail fast when entity file does not exist

**Slug**: `007-zuraffa-v5-foundation-entity-missing-fast-fail`  
**Feature**: `007-zuraffa-v5-foundation`  
**Severity**: Medium  
**Status**: Open

---

## Summary

When running `zfa make NonExistentEntity --preset=crud`, the command should fail fast with a clear error message indicating the entity doesn't exist and providing migration guidance. Instead, it currently proceeds silently using default values (`id` field), potentially generating broken architecture code.

---

## Root Cause

In `lib/src/commands/make_command.dart` (lines 398-482), the `EntityFieldResolver.resolveIdField()` is called to resolve the entity's identity field. When the entity file doesn't exist, `resolveIdField()` returns `null` (see `lib/src/utils/entity_field_resolver.dart:121`).

The code then falls through to line 481 without any check for the missing entity file:

```dart
if (context.data['no-entity'] != true) {
  final resolution = EntityFieldResolver.resolveIdField(...);
  if (resolution != null) {
    // ... handles value objects, id fields, autoId
  } else {
    // No identity: id-less entity. `zfa make` must fail loudly.
    return EntityIdResolution(kind: kind, autoId: autoId);
  }
}
```

When `resolution` is `null` (entity file not found), the code doesn't enter the `if (resolution != null)` block and just continues. The entity is treated as if it has an `id` field by default.

---

## Expected Behavior

The command should fail fast with an error like:
```
❌ Cannot generate architecture for "NonExistentEntity": the entity file does not exist.
Entities need a real identity. Choose one of:
  1. Create the entity first: zfa entity create -n NonExistentEntity --field id:String --field name:String
  2. If the entity exists elsewhere, check your domain root (fixed to lib/src/domain)
```

---

## Actual Behavior

The command succeeds and generates a plan with default plugin set, treating the entity as having an `id` field.

---

## Test Case

**File**: `test/commands/make_command_test.dart`  
**Test**: "fails fast when entity does not exist" (line ~120)  
**Current Status**: Documents buggy behavior (passes but shouldn't)

```dart
test('fails fast when entity does not exist', () async {
  final runner = CliRunner(exitOnCompletion: false);
  final output = await runner.runCapturing([
    'make',
    'NonExistentEntity',
    '--preset=crud',
    '--plan',
    '--format=json',
    '--output',
    outputDir,
  ]);

  // Current behavior: when entity doesn't exist, EntityFieldResolver returns null
  // and the code proceeds with default 'id' field. This is a bug - it should fail fast.
  // TODO: Fix implementation to fail fast when entity file doesn't exist.
  // For now, the test documents current (buggy) behavior.
  final decoded = jsonDecode(output) as Map<String, dynamic>;
  expect(decoded['success'], isTrue);
  final plan = decoded['plan'] as Map<String, dynamic>;
  expect(plan['name'], 'NonExistentEntity');
});
```

---

## Fix Location

**Primary**: `lib/src/commands/make_command.dart` - Add explicit check after `resolveIdField()` call for missing entity file.

**Secondary**: `lib/src/utils/entity_field_resolver.dart` - Could return a distinct sentinel for "file not found" vs "file found but no id field" vs "value object".

---

## Suggested Fix

In `make_command.dart`, after calling `EntityFieldResolver.resolveIdField()`, check if the entity file exists:

```dart
if (context.data['no-entity'] != true) {
  final resolution = EntityFieldResolver.resolveIdField(
    entityName: entityName,
    projectRoot: manager.projectRoot,
  );
  
  // Check if entity file actually exists
  final snake = _toSnake(entityName);
  final entityFile = File(p.join(manager.projectRoot, 'lib/src/domain/entities', snake, '$snake.dart'));
  if (!entityFile.existsSync()) {
    print('❌ Cannot generate architecture for "$entityName": the entity file does not exist.');
    print('');
    print('Create the entity first:');
    print('  zfa entity create -n $entityName --field id:String [--field other:Type...]');
    print('');
    throw MakeCommandException('Entity file does not exist: $entityName');
  }
  
  if (resolution != null) {
    // ... existing logic
  } else {
    // ... existing id-less entity logic
  }
}
```

---

## Related Acceptance Criteria

- **AC-004**: "Given an entity-dependent command is run before the entity exists, the command should fail fast with exact next-step guidance rather than generating partial architecture accidentally."

---

## Impact

This bug could lead to:
1. Silent generation of incorrect architecture code
2. Confusion when generated code references non-existent entities
3. Wasted time debugging why generated code doesn't compile

---

## Verification

After fix, the test should be updated to expect:
```dart
expect(decoded['success'], isFalse);
expect(output, contains('entity file does not exist'));
expect(output, contains('zfa entity create'));
```

See https://github.com/arrrrny/zuraffa/issues/496.

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
