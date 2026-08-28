# Bug Fix: zfa make: generated code hardcodes EntityFields.id (breaks entities without id) + mock datasource empty (methods default [])

- **Slug**: issue-294-zfa-make-generated-code-hardcodes-entityfields-id-breaks-ent
- **Fixed**: 2026-08-22T00:00:00+00:00
- **Assessment**: ./assessment.md
- **Status**: applied (source fix already merged in master; regression lock added)

## Summary

The source fix for #294 is already present in `origin/master` (merged as #295):
`lib/src/plugins/mock/mock_plugin.dart` now defaults the mock datasource method
list to `['get','update','toggle']` (matching the other CRUD plugins), and the
presenter/toggle/get generators consume the MakeCommand-resolved id field via
`GeneratorConfig.idField` / `queryField` instead of hardcoding `EntityFields.id`.

This PR does not modify `lib/src` — there is nothing to re-fix. It adds a focused,
fast **plugin-level** regression test that directly locks the fixed behaviour in
`lib/src`: the generated presenter references the resolved field name (e.g.
`depotId`) and never a hardcoded `id`. The existing slow regression test
(`test/regression/issue_294_entity_without_id_test.dart`) covers the resolver +
usecase-test side via the full `zfa make` subprocess; this unit test complements
it without needing a flutter SDK or subprocess.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `test/plugins/presenter/presenter_resolved_id_field_test.dart` | added | Drives `PresenterPlugin.generate` with `idField: 'depotId'` and asserts the generated presenter uses `depotId` (signature + `StorePriceFields.depotId` query + `UpdateParams`/`ToggleParams` ids) and never a hardcoded `id`. |

No `lib/src` changes were required; the fix already ships in master.

## Diff Highlights

```dart
// test/plugins/presenter/presenter_resolved_id_field_test.dart (new)
final config = GeneratorConfig(
  name: 'StorePrice',
  methods: const ['get', 'update', 'toggle'],
  idField: 'depotId',            // resolved id field, not hardcoded 'id'
  idFieldType: 'String',
  queryField: 'depotId',
  generatePresenter: true,
  outputDir: outputDir,
);
final files = await plugin.generate(config);
final content = files.first.content ?? '';
expect(content, contains('String depotId'), ...);
expect(content, contains('StorePriceFields.depotId'), ...);
expect(content, isNot(contains('StorePriceFields.id')), ...);
```

## Tests Added or Updated

- `test/plugins/presenter/presenter_resolved_id_field_test.dart` — group asserts
  the presenter uses the resolved id field name and never hardcodes `.id`.

## Local Verification

- `dart analyze lib` → no `error` lines (no lib changes).
- `dart test test/plugins/presenter/presenter_resolved_id_field_test.dart` →
  `All tests passed!` (exit 0).

## Deviations from Assessment

None. The assessment's remediation is already merged in master; this PR only adds
the regression lock and closes the ticket.

## Follow-ups

- None. The existing `test/regression/issue_294_entity_without_id_test.dart`
  continues to guard Gap 2 (mock methods default) and the resolver side.
