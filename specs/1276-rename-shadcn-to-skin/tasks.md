# Tasks 1276 — rename shadcn plugin → skin (MVP-first, dependency-ordered)

Every behavior task below is driven by a failing test FIRST
(tdd/test-list.md). Non-behavioral tasks are implemented after the
green loop (speckit.implement).

## Phase 0 — test migration (RED)

- [x] T0.1 Move `test/plugins/shadcn/` → `test/plugins/skin/`
      (6 files): rename `shadcn_plugin_test.dart` →
      `skin_plugin_test.dart`; rewrite imports to
      `package:zuraffa/src/plugins/skin/...`; `ShadcnPlugin` →
      `SkinPlugin`; temp-dir prefix, group names, error-surface
      expectations re-voiced (`skin plugin not found`). [SC-3, SC-5]
- [x] T0.2 Migrate `test/commands/capability_receipt_test.dart`:
      `zfa skin list Product`, `args: ['skin', ...]`,
      `plugin: 'skin'`. [SC-4]
- [x] T0.3 Migrate `test/commands/exit_code_sweep_1139_test.dart`:
      `SkinCommand(SkinPlugin(...))`, `runner.run(['skin', ...])`,
      usage-error expectations re-voiced. [SC-2, SC-7]
- [x] T0.4 Migrate `test/fixes/kill_list_fix_list_test.dart`: group
      `skin advertised layouts`, `['skin', 'grid', ...]`. [SC-2]
- [x] T0.5 Migrate `test/regression/issue_512_pure_dart_flutter_import_guard_test.dart`:
      `SkinBuilder`, group `skin`, guard expectations name the skin
      lane. [SC-8]
- [x] T0.6 Migrate TDD-lane tests:
      `bug_912_widget_shell_and_finders_test.dart` (ZuraffaApp +
      zuraffa_ui import expectations),
      `bug_938_widget_shadcn_preflight_test.dart` →
      `bug_938_widget_skin_preflight_test.dart`,
      `bug_938_shadcn_preflight_unit_test.dart` →
      `bug_938_skin_preflight_unit_test.dart` (`WidgetSkinPreflight`,
      `zuraffa_ui` pubspec fixtures), `tdd_fixture.dart` (shell
      script strings), `run_command_test.dart` + `step_runner_test.dart`
      (skip reasons / resume lines → `zuraffa_ui`),
      `subject_writer_test.dart` (`isNot(contains('zuraffa_ui'))`),
      `gym_plugin_test.dart` (`runAfter` contains `skin`). [SC-6]
- [x] T0.7 Record RED evidence: `dart test` on the migrated files
      fails (missing `src/plugins/skin/` imports / renamed API);
      capture outputs into tdd/verification.md.

## Phase 1 — plugin core (GREEN start)

- [x] T1.1 Create `lib/src/plugins/skin/` mirroring the old layout;
      `SkinPlugin` id `skin` version 1.0.0; capability
      `ui.schema.export` unchanged; delete
      `lib/src/plugins/shadcn/` outright. [SC-1, SC-3]
- [x] T1.2 `SkinCommand`: name `skin`, invocation
      `zfa skin <layout> <Entity> | zfa skin ui.schema.export ...`,
      layout grammar (`list|form` + #1149 refusals), receipt
      persistence via CapabilityInvocationWrapper, #904 flag surface
      unchanged. [SC-2, SC-4]
- [x] T1.3 `SkinBuilder` certified templates: zuraffa_ui barrel
      import; list = `ZfaCard`/`ZfaInput`(String placeholder)/
      `ZfaButton`; form = `ZfaInput(onChanged:)` value map +
      `ZfaButton` submit; Constitution VII pure-Dart guard names the
      skin lane. [SC-2, SC-8]

## Phase 2 — wiring

- [x] T2.1 `plugin_loader.dart` + `code_generator.dart` register
      `SkinPlugin`; `zuraffa.dart` exports the five public vocabulary
      paths under `src/plugins/skin/`. [SC-1]
- [x] T2.2 `zfa_config.dart` default key `skin`; `plan_resolver.dart`
      honors the `skin` option; `generate_commands_command.dart`
      presentation map `skin`; gym/test `runAfter` keys `skin`;
      receipt-path comments re-voiced. [SC-1, SC-4]
- [x] T2.3 `ui_command.dart` imports + `skin plugin not found`
      surfaces; `make_command.dart` vocabulary imports + plugin-id
      sets. [SC-5]

## Phase 3 — TDD lane

- [x] T3.1 `widget_scaffold.dart`: `WidgetAppShell.zuraffaapp`
      (widgetName `ZuraffaApp`, config value `zuraffaapp`),
      `WidgetSkinPreflight` (`skinPackage = 'zuraffa_ui'`,
      `projectDeclaresZuraffaUi`, `skinImportRequired`, fixLine
      `--> fix: flutter pub add zuraffa_ui (widget-lane behaviors boot
      a ZuraffaApp shell)`). [SC-6]
- [x] T3.2 Writers: `behavior_test_writer.dart` emits
      `package:zuraffa_ui/zuraffa_ui.dart` for the skin shell;
      `theme_harness_test_writer.dart` emits `ZfaTheme`/`ZfaThemeData`
      + ZuraffaApp wording. [SC-6]
- [x] T3.3 Commands: `gen_command.dart` (help text, preflight wiring,
      refusal lines), `run_command.dart` / `run_engine_command.dart` /
      `run_skin_command.dart` (--skip-widget help), `run_driver_core.dart`
      (skip reason + resume strings), `zfa_config.dart`
      `tddWidgetShell` accepted value `zuraffaapp`. [SC-6]

## Phase 4 — non-behavioral (speckit.implement)

- [x] T4.1 `docs/skin_plugin.md`: command surface, capability
      contract, certified vocabulary, #938 preflight behavior. [SC-5]
- [x] T4.2 Spec-kit artifacts committed alongside code (this file,
      spec.md, plan.md, tdd/test-list.md, tdd/verification.md).

## Phase 5 — gates

- [x] T5.1 `rg -i "shadcn" lib/ test/ docs/` → zero matches. [SC-1]
- [x] T5.2 `dart analyze` over every changed dart file → clean. [SC-7]
- [x] T5.3 Targeted `dart test` over migrated suites → all pass;
      record counts in tdd/verification.md. [SC-7]
- [x] T5.4 `dart format .` → zero remaining diffs. [SC-7]
