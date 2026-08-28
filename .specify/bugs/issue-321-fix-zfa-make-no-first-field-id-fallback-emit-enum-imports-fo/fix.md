# Bug Fix: fix(zfa make): no first-field id fallback + emit enum imports for signature types (supersedes #307; coordinates with #320 autoId)

- **Slug**: issue-321-fix-zfa-make-no-first-field-id-fallback-emit-enum-imports-fo
- **Fixed**: 2026-08-22T00:00:00+00:00
- **Assessment**: ./assessment.md
- **Status**: applied (source fix already merged in master; regression lock added)

## Summary

The source fix for #321 is already present in `origin/master` (merged as #324):
the `EntityFieldResolver` no longer silently falls back to the first declared
field as the id (id-less entities now fail loudly via `zfa make`, coordinated with
the #322 identity contract), and `PresenterPlugin._computeImports` now includes
`config.idFieldType` / `config.queryFieldType` in the import resolution so a
legitimate enum-typed id emits its barrel import (`domain/entities/enums/index.dart`).
Primitive id types are filtered out by `KnownTypes.isExcluded`.

This PR does not modify `lib/src`. It adds a focused, fast plugin-level regression
test that drives the presenter plugin directly and asserts the generated import set
reacts to the id-field type: an enum id emits the enum barrel import, a primitive
(`String`) id does not. The existing slow regression test
(`test/regression/issue_321_no_first_field_id_fallback_enum_import_test.dart`)
covers the resolver + loud-error + full `zfa make` integration; this unit test
complements it without needing a flutter SDK or subprocess.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `test/plugins/presenter/presenter_enum_id_import_test.dart` | added | Drives `PresenterPlugin.generate` with an enum id-field type and asserts the enum barrel import is emitted (and the enum-typed id appears in `UpdateParams`/`ToggleParams`); plus a primitive-id negative case asserting no enum import. |

No `lib/src` changes were required; the fix already ships in master.

## Diff Highlights

```dart
// test/plugins/presenter/presenter_enum_id_import_test.dart (new)
final config = GeneratorConfig(
  name: 'MessageLog',
  methods: const ['update', 'toggle'],
  idField: 'messageTypeId',
  idFieldType: 'MessageType',      // enum id field
  queryField: 'messageTypeId',
  generatePresenter: true,
  outputDir: outputDir,
);
final content = (await plugin.generate(config)).first.content ?? '';
expect(content, contains('domain/entities/enums/index.dart'), ...);  // enum import emitted
expect(content, contains('UpdateParams<MessageType,'), ...);
// negative: String id → no enum import
expect(content, isNot(contains('enums/index.dart')), ...);
```

## Tests Added or Updated

- `test/plugins/presenter/presenter_enum_id_import_test.dart` — group asserts enum
  id type → barrel import emitted; primitive id type → no enum import.

## Local Verification

- `dart analyze lib` → no `error` lines (no lib changes).
- `dart test test/plugins/presenter/presenter_enum_id_import_test.dart` →
  `All tests passed!` (2 tests, exit 0).

## Deviations from Assessment

None. The assessment's remediation is already merged in master; this PR only adds
the regression lock and closes the ticket.

## Follow-ups

- None. The existing `test/regression/issue_321_...` continues to guard the
  resolver + loud no-id-error path and the full integration scenario.
