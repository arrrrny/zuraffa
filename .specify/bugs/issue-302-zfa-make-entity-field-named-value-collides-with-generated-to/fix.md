# Bug Fix: zfa make: entity field named 'value' collides with generated toggle params → duplicate_definition in controller/presenter (Barcode)

- **Slug**: issue-302-zfa-make-entity-field-named-value-collides-with-generated-to
- **Fixed**: 2026-08-22T00:00:00+00:00
- **Assessment**: ./assessment.md
- **Status**: applied (source fix already merged in master; regression lock added)

## Summary

The source fix for #302 is already present in `origin/master` (merged as #305):
the toggle-value parameter is renamed to the reserved name `toggleValue` in both
the controller (`lib/src/plugins/controller/controller_plugin_methods.dart`) and
the presenter (`lib/src/plugins/presenter/presenter_plugin.dart`). Because the
name is fixed, it can never collide with `config.idField`, `field`, or
`cancelToken`, regardless of the entity's field names.

This PR does not modify `lib/src`. It adds a focused, fast plugin-level regression
test that drives the presenter + controller plugins directly and asserts the
generated toggle method uses `bool toggleValue`, forwards it into
`ToggleParams.value`, and has no duplicate `bool value` parameter — even when the
entity's id field is `value`. The existing slow regression test
(`test/regression/issue_302_toggle_param_collision_test.dart`) covers the
resolver + loud-error side via the full `zfa make` subprocess; this unit test
complements it without needing a flutter SDK or subprocess.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `test/plugins/toggle_value_param_test.dart` | added | Drives `PresenterPlugin.generate` + `ControllerPlugin.generate` with `idField: 'value'` and asserts `bool toggleValue`, no `bool value` collision, and `ToggleParams.value: toggleValue` forwarding; plus a canonical `id` control case. |

No `lib/src` changes were required; the fix already ships in master.

## Diff Highlights

```dart
// test/plugins/toggle_value_param_test.dart (new)
final config = GeneratorConfig(
  name: 'Barcode',
  methods: const ['get', 'update', 'toggle'],
  idField: 'value',            // entity field named `value`
  idFieldType: 'String',
  queryField: 'value',
  generatePresenter: true,
  outputDir: outputDir,
);
final content = (await plugin.generate(config)).first.content ?? '';
expect(content, contains('bool toggleValue'), ...);
expect(content, isNot(contains('bool value')), ...);
expect(content, contains('ToggleParams<String, Field<Barcode, dynamic>>(\n'
    '        id: value,\n        field: field,\n        value: toggleValue,'), ...);
```

## Tests Added or Updated

- `test/plugins/toggle_value_param_test.dart` — group asserts presenter + controller
  toggle methods use `toggleValue` (no `value` collision), plus a canonical `id`
  control case.

## Local Verification

- `dart analyze lib` → no `error` lines (no lib changes).
- `dart test test/plugins/toggle_value_param_test.dart` → `All tests passed!`
  (3 tests, exit 0).

## Deviations from Assessment

None. The assessment's remediation is already merged in master; this PR only adds
the regression lock and closes the ticket.

## Follow-ups

- None. The existing `test/regression/issue_302_...` continues to guard the
  resolver + loud no-id-error path.
