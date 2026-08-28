# Bug Assessment: zfa make: entity field named 'value' collides with generated toggle params → duplicate_definition in controller/presenter (Barcode)

- **Slug**: issue-302-zfa-make-entity-field-named-value-collides-with-generated-to
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Updated**: 2026-08-22T00:00:00+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/302
- **Verdict**: already fixed in `origin/master`; regression lock added
- **Severity**: unknown

## Report (verbatim or summarized)

`zfa make` for an entity with a field literally named `value` (e.g. `Barcode`)
generated a controller/presenter whose toggle method had two `value` parameters
(`String value` id + `bool value` toggle value) → `duplicate_definition` +
`argument_type_not_assignable`. See https://github.com/arrrrny/zuraffa/issues/302.

## Symptom

Generated `barcode_controller.dart` / `barcode_presenter.dart` fail analyzer
with `The name 'value' is already defined` and `argument_type_not_assignable`.

## Reproduction

```bash
zfa entity create -n Barcode --field value:String --field format:BarcodeFormat
zfa make Barcode --preset=crud --with=vpc,state,di,test,mock
flutter analyze
```

## Suspected Code Paths

- `lib/src/plugins/controller/controller_plugin_methods.dart` — toggle method
  built with a `bool value` parameter for the new toggle value.
- `lib/src/plugins/controller/controller_plugin_bodies.dart` — forwarded
  `toggleValue`/former `value` into `_presenter.toggleX(...)`.
- `lib/src/plugins/presenter/presenter_plugin.dart` — same toggle-method shape.

## Root Cause Hypothesis

The toggle-value parameter name was hardcoded to `value`. When the entity's
resolved id field is also `value` (e.g. `Barcode` whose first declared field is
`value`), the id parameter `String value` collides with the toggle-value
parameter `bool value`.

## Proposed Remediation (already merged)

Rename the toggle-value parameter to the fixed reserved name `toggleValue` in
both controller and presenter (merged as #305). `ToggleParams.value` is a class
constructor field name, not a parameter, so it is unaffected. The
`--id-field=value` case (id-less entity) now requires an explicit id resolution
per the loud no-id-error contract (#321/#322).

## Files likely to change

- `lib/src/plugins/controller/controller_plugin_methods.dart` (param renamed to
  `toggleValue`) — already done.
- `lib/src/plugins/presenter/presenter_plugin.dart` (param renamed to
  `toggleValue`) — already done.
- `test/plugins/toggle_value_param_test.dart` — added as a fast plugin-level
  regression lock (the existing `test/regression/issue_302_...` covers the
  resolver + loud-error side via the full `zfa make` path).

## Tests to add

- Plugin-level unit test driving `PresenterPlugin.generate` /
  `ControllerPlugin.generate` with `idField: 'value'` and asserting the generated
  toggle method uses `bool toggleValue`, forwards it into `ToggleParams.value`,
  and has no duplicate `bool value` parameter. See
  `test/plugins/toggle_value_param_test.dart`.

## Risks & Considerations

- Pure-Dart targets skip VPC generation per Constitution VII, so the existing
  slow regression test only asserts the presenter/controller file is NOT emitted
  on a pure-Dart workspace. The added unit test drives the plugin directly and
  inspects generated text, so it locks the real behaviour without a flutter SDK.
- No `lib/src` change was required: the fix already ships in master.

## Open Questions

- None.
