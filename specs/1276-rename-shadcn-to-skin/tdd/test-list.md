# TDD Test List — Spec 1276 rename shadcn → skin

One behavior per line, traced to the acceptance criteria in spec.md.
Every behavior is written as a failing test FIRST (RED), then made to
pass (GREEN). Red for this feature is a *rename red*: the migrated test
imports `package:zuraffa/src/plugins/skin/...` and asserts the renamed
API, which cannot compile/pass until the plugin lands.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | `SkinPlugin` generates the list widget with active discovery; emitted imports are material + zuraffa_ui only | SC-2 | test/plugins/skin/skin_plugin_test.dart |
| B2 | `SkinPlugin` generates the form widget on the certified barrel (ZfaInput/ZfaButton; no ShadForm vocabulary) | SC-2 | test/plugins/skin/skin_plugin_test.dart |
| B3 | The plugin exposes the `ui.schema.export` capability with id `skin` ownership unchanged | SC-3 | test/plugins/skin/ui_command_test.dart |
| B4 | `zfa ui schema --no-plugin` refuses with `skin plugin not found` | SC-5 | test/plugins/skin/ui_command_test.dart |
| B5 | Registry/exporter/scaffolder/validator suites pass unchanged against the moved vocabulary paths | SC-3 | test/plugins/skin/{ui_node_registry,vocabulary_schema_exporter,composite_scaffolder,payload_validator}_test.dart |
| B6 | Standalone `zfa skin list Product` ships a receipt with `plugin: skin` | SC-4 | test/commands/capability_receipt_test.dart |
| B7 | `zfa skin banana Product` exits 2 with the #1149 layout refusal naming `zfa skin` usage | SC-2 | test/commands/exit_code_sweep_1139_test.dart |
| B8 | `zfa skin grid Product` refuses loudly (kill-list fix 1 preserved) | SC-2 | test/fixes/kill_list_fix_list_test.dart |
| B9 | Pure-Dart pubspec ⇒ no skin widget emitted; Flutter pubspec ⇒ Flutter skin widget emitted (Constitution VII guard) | SC-8 | test/regression/issue_512_pure_dart_flutter_import_guard_test.dart |
| B10 | Default widget shell is ZuraffaApp with the zuraffa_ui import in the generated widget test | SC-6 | test/plugins/tdd/commands/bug_912_widget_shell_and_finders_test.dart |
| B11 | #938 preflight: widget gen refuses on a project without `zuraffa_ui` with `--> fix: flutter pub add zuraffa_ui`; proceeds when declared; `materialapp` opt-out emits no zuraffa_ui import | SC-6 | test/plugins/tdd/commands/bug_938_widget_skin_preflight_test.dart |
| B12 | `WidgetSkinPreflight.projectDeclaresZuraffaUi` pins on `zuraffa_ui` in the pubspec dependencies map | SC-6 | test/plugins/tdd/services/bug_938_skin_preflight_unit_test.dart |
| B13 | `--skip-widget` records `zuraffa_ui not declared (issue #938)` skip reasons and the `add zuraffa_ui` resume line | SC-6 | test/plugins/tdd/run_command_test.dart, test/plugins/tdd/services/step_runner_test.dart |
| B14 | Gym exercises run after the `skin` plugin | SC-1 | test/plugins/gym/gym_plugin_test.dart |
| B15 | Subject stub compiles with only the material import (no `zuraffa_ui` leak into the stub) | SC-6 | test/plugins/tdd/subject_writer_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
dart test test/plugins/skin/          # B1–B5
dart test test/commands/capability_receipt_test.dart   # B6
dart test test/commands/exit_code_sweep_1139_test.dart # B7
dart test test/fixes/kill_list_fix_list_test.dart      # B8
dart test test/regression/issue_512_pure_dart_flutter_import_guard_test.dart # B9
dart test test/plugins/tdd/commands/bug_912_widget_shell_and_finders_test.dart # B10
dart test test/plugins/tdd/commands/bug_938_widget_skin_preflight_test.dart    # B11
dart test test/plugins/tdd/services/bug_938_skin_preflight_unit_test.dart      # B12
dart test test/plugins/tdd/run_command_test.dart       # B13
```

Expected RED: compile errors on `src/plugins/skin/*` imports and
`SkinPlugin`/`SkinBuilder`/`SkinCommand`/`WidgetSkinPreflight`
symbols; string-assert failures on `plugin: skin`, `zuraffa_ui`
imports, `skin plugin not found`.
