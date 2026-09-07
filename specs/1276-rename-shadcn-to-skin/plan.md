# Plan 1276 — rename shadcn plugin → skin; zuraffa_ui vocab swap

## Technical Context

- Toolchain: Dart 3.13.3 stable (SDK constraint `^3.11.0` respected);
  pure-Dart package — no Flutter SDK in the loop (Constitution VII).
- Target: the certified vocabulary is **package:zuraffa_ui 0.1.0**
  (pub.dev, 2026-09-05). Its barrel exports ONLY identified names:
  `ZuraffaApp`, `ZfaButton`, `ZfaCard`, `ZfaDialog`, `ZfaInput`,
  `ZfaSheet`, `ZfaToaster`, `SkinContractKit`, `ZfaContract`,
  `ZfaAuditBus`, `ZuraffaRouteObserver`, `ZfaTheme` (= `ShadTheme`
  typedef), `ZfaThemeData`. `ZfaForm`/`ZfaInputFormField` are NOT in
  the published barrel — the `form` template emits `ZfaInput` +
  `ZfaButton` instead (see spec constraint note).
- Signature deltas that make this a semantic migration, not sed:
  - `ZfaInput.placeholder` is `String?` (was `Widget?` on `ShadInput`).
  - `ZfaButton` has no `.outline`/variant constructor.
  - `ZuraffaApp` keeps `home`, `navigatorObservers`, `theme` params, so
    the widget-lane pump templates keep their shape under the new name.
- Scale: ~175 case-sensitive `shadcn` references in lib/ + test/,
  8 source files under `lib/src/plugins/shadcn/`, 6 test files under
  `test/plugins/shadcn/`, 13 integration/lib files, 11 tdd-adjacent
  test files.

## Migration map (authoritative)

| Old | New |
|---|---|
| `lib/src/plugins/shadcn/shadcn_plugin.dart` | `lib/src/plugins/skin/skin_plugin.dart` (`SkinPlugin`, id `skin`, v1.0.0) |
| `commands/shadcn_command.dart` (`ShadcnCommand`, name `shadcn`) | `commands/skin_command.dart` (`SkinCommand`, name `skin`) |
| `builders/shadcn_builder.dart` (`ShadcnBuilder`) | `builders/skin_builder.dart` (`SkinBuilder`) |
| `capabilities/ui_vocabulary_export_capability.dart` | same file name; description says "skin plugin"; capability id `ui.schema.export` UNCHANGED |
| `vocabulary/{ui_node_registry,composite_scaffolder,payload_validator,vocabulary_schema_exporter}.dart` | same names (public API via barrel; doc comment says skin plugin) |
| `test/plugins/shadcn/*` | `test/plugins/skin/*` (6 files, imports + names updated) |
| import `package:shadcn_ui/shadcn_ui.dart` | `package:zuraffa_ui/zuraffa_ui.dart` |
| `ShadApp` / `ShadTheme` / `ShadThemeData` | `ZuraffaApp` / `ZfaTheme` / `ZfaThemeData` |
| `ShadInput(placeholder: const Text(...))` | `ZfaInput(placeholder: '...')` (String) |
| `ShadButton.outline(child:, onPressed:)` | `ZfaButton(child:, onPressed:)` |
| `ShadCard(title:, description:)` | `ZfaCard(title:, description:)` (Widget? — unchanged shape) |
| `ShadForm` + `GlobalKey<ShadFormState>` + `saveAndValidate` + `ShadInputFormField` | per-field `ZfaInput(onChanged:)` into a value map + `ZfaButton` submit |
| `WidgetAppShell.shadapp` (widgetName `ShadApp`, config value `shadapp`) | `WidgetAppShell.zuraffaapp` (widgetName `ZuraffaApp`, config value `zuraffaapp`) |
| `WidgetShadcnPreflight.shadcnPackage = 'shadcn_ui'`, `projectDeclaresShadcnUi`, `shadcnImportRequired`, fixLine `flutter pub add shadcn_ui` | `WidgetSkinPreflight.skinPackage = 'zuraffa_ui'`, `projectDeclaresZuraffaUi`, `skinImportRequired`, fixLine `flutter pub add zuraffa_ui` |
| config key `shadcn`, plan option `shadcn`, gym/test `runAfter` `shadcn`, presentation map `shadcn` | all `skin` |
| receipt `plugin: shadcn` | `plugin: skin` |

## Implementation strategy

MVP-first, dependency-ordered (T1 → T4):

1. **T1 — vocabulary (pure moves).** The vocabulary files
   (`ui_node_registry`, `composite_scaffolder`, `payload_validator`,
   `vocabulary_schema_exporter`) keep their names; only the plugin dir
   changes and one doc comment is re-voiced. Everything public via
   `zuraffa.dart` keeps compiling.
2. **T2 — plugin core.** `SkinPlugin`/`SkinCommand`/`SkinBuilder` +
   capability. Builder templates rewritten against the certified
   barrel (String placeholder, no variant button, ZfaInput-based form,
   Constitution VII pure-Dart guard renamed). Command usage/error text
   re-voiced.
3. **T3 — wiring.** Loader, code generator, config, plan resolver,
   receipt comments, gym/test ordering, presentation map, barrel
   exports, ui_command imports + messages.
4. **T4 — TDD lane.** Widget shell enum + preflight class rename +
   writers' templates + gen/run messages.

Test-first discipline (see tdd/test-list.md): the migrated test files
are committed and run RED (they import `src/plugins/skin/...` which
does not exist yet), then T1–T4 land and the same files run GREEN.
Non-behavioral work (docs, spec artifacts) is covered by
`/speckit.implement` tasks after green.

## Risk register

- **Hidden `Shad*` template references** — mitigated by the final
  `rg -i "shadcn|Shad[A-Z]" lib/ test/ docs/` gate (SC-1).
- **String-literal contract drift in tests** (receipt keys, skip
  reasons, fix lines asserted verbatim) — every asserted string is
  migrated in the same commit as the emitter; the tdd fixture script
  (`tdd_fixture.dart`) carries shell-script assertions too.
- **Generate-path regressions** (exit codes, layout grammar, preflight
  refusals) are pinned by the migrated exit-code-sweep and kill-list
  tests — they must stay green unchanged except for the renamed ids.

## Verification plan

`dart analyze` over changed files; targeted `dart test` per migrated
suite (never the full suite — disk ceiling); `dart format .` with zero
remaining diffs; SC-1 grep gate; disk hygiene between phases.
