# Bug Assessment: `zfa controller/presenter create` emit Flutter code in pure-Dart packages (Constitution VII violation)

- **Slug**: pure-dart-flutter-generation
- **Created**: 2026-08-22
- **Source**: https://github.com/arrrrny/zuraffa/issues/420 (fetched; host `github.com` is on the allowlist → `allowlisted`)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Fetched from [zuraffa #420](https://github.com/arrrrny/zuraffa/issues/420):

> Bug: `zfa controller create` and `zfa presenter create` generate Flutter-dependent code in pure-Dart packages:
>
> - Imports `package:zuraffa_flutter/zuraffa_flutter.dart`
> - Extends Flutter classes (`StatefulWidget`, `ControllerBase` from zuraffa_flutter)
> - Uses `CancelToken`, `Result`, `AppFailure`, `QueryParams`, `Eq` — all from zuraffa_flutter
> - Violates Constitution VII (Engine Purity: no Flutter deps in engine)
>
> Reproduction: `zfa controller create Suite` in a pure-Dart package (no `flutter` in `pubspec`) generates `lib/src/presentation/pages/suite/suite_controller.dart` with Flutter imports/classes. `dart analyze` → 20+ errors (undefined classes, missing zuraffa_flutter dep).
>
> Expected: controller/presenter generation should either (a) detect pure-Dart and skip Flutter generation, (b) generate plain-Dart controllers/presenters without Flutter deps, or (c) have a `--no-flutter` flag.
>
> Files: `lib/src/plugins/controller/`, `lib/src/plugins/presenter/`.

## Symptom

Running `zfa controller create <Name>` (and `zfa presenter create <Name>`) inside a pure-Dart package emits generated files that `import package:zuraffa_flutter/...` and extend Flutter-only base classes (`Controller`, `Presenter`, `StatefulController`). Because the target package has no `zuraffa_flutter` dependency, `dart analyze` fails with 20+ "undefined class / uri doesn't exist" errors. In a Flutter package the same commands work correctly. The behavior violates Constitution VII (Engine Purity): the engine's code generators must not assume a Flutter runtime in the target project.

## Reproduction

1. Create a pure-Dart package whose `pubspec.yaml` does **not** declare `flutter: sdk: flutter` (depends only on `zuraffa`).
2. Run `zfa controller create <Name>` (e.g. `Suite`) — and separately `zfa presenter create <Name>`.
3. Inspect the generated `lib/src/presentation/pages/<name>/<name>_controller.dart` (and presenter file).
4. Run `dart analyze` → 20+ errors referencing `package:zuraffa_flutter`, `Controller`, `Presenter`, `StatefulController`, `updateState`, `registerSubscription`, `viewState`.

- Exact CLI flag syntax for `zfa controller create` is not confirmed in the report; the capability schema (`lib/src/plugins/controller/capabilities/create_controller_capability.dart`) accepts `name`, `methods`, `state`, `dryRun`, `force`, `verbose`. [NEEDS CLARIFICATION: verbatim command used by reporter, and whether `zfa presenter create` triggers the same path via `generatePresenter`/`generateVpcs`.]

## Suspected Code Paths

- `lib/src/plugins/controller/controller_plugin_utils.dart:66` — hardcoded import `package:zuraffa_flutter/zuraffa_flutter.dart` (the primary smoking gun; comment claims presentation layer "must" import zuraffa_flutter).
- `lib/src/plugins/controller/builders/controller_class_builder.dart:116` — generated class `..extend = refer('Controller')`; line 122 mixes in `StatefulController<State>`. Both base symbols exist **only** in `zuraffa_flutter`.
- `lib/src/plugins/controller/controller_plugin_bodies.dart` — method bodies reference `updateState`, `registerSubscription`, `viewState`, `_presenter.dispose`, `super.onDisposed` — all members of the Flutter `Controller`/`StatefulController` (e.g. `zuraffa_flutter/lib/src/presentation/controller.dart:141` `abstract class Controller … with WidgetsBindingObserver, RouteAware, ChangeNotifier, Loggable`). `CancelToken?` here is fine (core `zuraffa` has it).
- `lib/src/plugins/presenter/presenter_plugin.dart:850` — hardcoded import `package:zuraffa_flutter/zuraffa_flutter.dart`.
- `lib/src/plugins/presenter/builders/presenter_class_builder.dart:30` — generated class `..extend = refer('Presenter')`. `Presenter` base lives in `zuraffa_flutter/lib/src/presentation/presenter.dart:52` (`abstract class Presenter with Loggable` — mostly pure-Dart-compatible, unlike `Controller`).
- `lib/src/plugins/view/view_plugin.dart:742` — **same hardcoded import** as controller/presenter (related; `view create` is the third presentation-layer command and almost certainly affected by the identical bug, though #420 only names controller/presenter).
- Base-class availability: `Controller`/`StatefulController` are Flutter-only (StatefulWidget/GlobalKey/ChangeNotifier); `CancelToken` (`lib/src/core/cancel_token.dart`), `Result` (`lib/src/core/result.dart`), `AppFailure` (`lib/src/core/failure.dart`), `QueryParams` (`lib/src/core/params/index.dart`) are all in core `zuraffa` and re-exported via `lib/src/zuraffa.dart`. So a pure import swap compiles presenter bodies but `Presenter` itself still isn't in core.
- Precedent / detection helper to reuse: `DependencyWirer.isFlutterProject(pubspecContent)` at `lib/src/core/dependencies/dependency_wirer.dart:227` (true iff `dependencies` contains `flutter`). The `test` plugin already uses it for the identical Flutter-vs-pure-Dart import decision: `test_builder_helpers.dart:577` `_isFlutterProject` (with caching) + `:598` `_testFrameworkImport` + `:611` `_zuraffaCoreImport`.

## Root Cause Hypothesis

The controller/presenter/view generators unconditionally emit Flutter-targeted code: a hardcoded `package:zuraffa_flutter/...` import plus references to Flutter-only base classes (`Controller`, `StatefulController`, and `Presenter` which ships only in `zuraffa_flutter`). The generators were written assuming every target project is a Flutter app (the historical default). They never inspect the target `pubspec.yaml` to branch on Flutter vs pure-Dart — the exact capability the `test` plugin already built for #354. When the target is pure-Dart, the emitted code references symbols that are absent from the `zuraffa` dependency, producing the analyzer failures.

Confidence: **high** — the hardcoded import lines are directly observable and `Controller`/`Presenter`/`StatefulController` are demonstrably defined only in `zuraffa_flutter`.

## Proposed Remediation

**Preferred**: Reuse the #354 precedent so the presentation-layer generators detect the target project type and branch on it.

1. Add a small Flutter-detection helper to the controller/presenter/view plugins (mirror `TestBuilderHelpers._isFlutterProject`): read `<projectRoot>/pubspec.yaml` via the existing `fileSystem`, call `DependencyWirer.isFlutterProject(content)`, cache the result. `projectRoot` is reachable through `PluginContext.core.projectRoot` (or derived from the plugins' `outputDir` + `fileSystem`).
2. When the target is **pure-Dart**:
   - `controller create` and `view create`: these are inherently Flutter-UI constructs (no widget tree, no `BuildContext`). **Skip generation and emit a clear warning** that controllers/views require a Flutter project (optionally suggest `zfa presenter create`, which is runtime-agnostic). This respects Constitution VII without inventing a non-existent pure-Dart controller.
   - `presenter create`: generate a pure-Dart presenter that imports `package:zuraffa/zuraffa.dart` (not `zuraffa_flutter`) and extends a **core `Presenter` base**. This requires landing a pure-Dart `Presenter` base class in core `zuraffa` (it only needs `Loggable` + usecase execution; `presenter.dart` is already `with Loggable`, i.e. Flutter-free). Low-risk and directly in line with the ongoing pure-dart-core-split (#253 / `specs/014-pure-dart-core-split`, Status: Implemented).
3. When the target is **Flutter**: keep today's behavior unchanged (import `zuraffa_flutter`, extend `Controller`/`Presenter`/`StatefulController`).

**Alternatives**:
- **A — explicit `--no-flutter` / `--dart` (and/or `--flutter`) flag** on `zfa controller/presenter create`: forces the pure-Dart code path or the Flutter path. Less "magic" than auto-detection, but still requires the core `Presenter` base (and a decision for controller: error out, or generate a non-Flutter stub). More CLI surface area; pairs well with the auto-detect as an override.
- **B — full pure-Dart core split**: as part of #253, move `Controller`/`Presenter`/`StatefulController` base classes into core `zuraffa` with Flutter-free implementations so generators *always* emit pure-Dart-safe code. Highest effort and broadest blast radius (affects `zuraffa_flutter` consumers), but eliminates the entire class of bug permanently.

**Files likely to change**:
- `lib/src/plugins/controller/controller_plugin_utils.dart` (import selection + skip logic for pure-Dart)
- `lib/src/plugins/controller/builders/controller_class_builder.dart` (skip when pure-Dart)
- `lib/src/plugins/controller/capabilities/create_controller_capability.dart` (optional `--no-flutter` arg) + `lib/src/commands/controller_command.dart`
- `lib/src/plugins/presenter/presenter_plugin.dart` (import selection)
- `lib/src/plugins/presenter/builders/presenter_class_builder.dart` (extend core `Presenter`)
- `lib/src/plugins/view/view_plugin.dart` (same import fix — related bug)
- `lib/src/zuraffa.dart` + a new `lib/src/.../presenter.dart` (land a pure-Dart `Presenter` base) — only needed for the preferred presenter fix / Alternative B
- `test/plugins/controller/controller_plugin_test.dart`, `test/plugins/presenter/presenter_plugin_test.dart`

**Tests to add or update**:
- A regression test mirroring `test/regression/issue_354_test_plugin_flutter_vs_dart_imports_test.dart` but for controller/presenter: given a pure-Dart `pubspec.yaml` (no `flutter`), assert generated controller/presenter files **do not** contain `zuraffa_flutter`, and that `controller create` is skipped with a warning; given a Flutter `pubspec.yaml`, assert the current `zuraffa_flutter` behavior is preserved.
- Unit test for the new Flutter-detection helper (pure-Dart vs Flutter vs missing/invalid `pubspec.yaml` → conservative pure-Dart default, matching `DependencyWirer`).

## Risks & Considerations

- **API/architecture**: Adding a core `Presenter` base (preferred presenter fix / Alt B) changes where `Presenter` is defined; ensure `zuraffa_flutter` re-exports it so existing Flutter consumers don't break. Keep the `zuraffa_flutter` `Presenter` as the (possibly enriched) Flutter subclass/re-export.
- **Behavior change**: Skipping `controller create`/`view create` in pure-Dart projects is a new failure mode for users who currently rely on it producing *something* — emit an actionable warning (Constitution VII rationale + suggested alternatives) rather than a silent skip.
- **Constitution VII**: Any fix must keep the engine (`zuraffa`) free of `package:flutter` imports; detection reads `pubspec.yaml` as text only, so it stays pure-Dart.
- **Consistency**: The `view` plugin shares the same hardcoded import (line 742) and should be fixed in the same change to avoid a half-fixed presentation layer.
- **Generator purity**: Per `specs/014-pure-dart-core-split`, the *generators themselves* already run under pure Dart (they only emit strings). The defect is purely in the emitted output's assumptions about the target project — keep the fix scoped to import/class selection, not to the generator runtime.

## Open Questions

- [NEEDS CLARIFICATION: exact `zfa` invocation the reporter used, and whether `presenter create` is reached the same way as `controller create`.]
- [NEEDS CLARIFICATION: is silently skipping `controller`/`view` in pure-Dart acceptable, or should it be a hard error / `--no-flutter` only? The reporter lists "skip" as one of three acceptable options.]
- [NEEDS CLARIFICATION: should `Presenter` be moved into core `zuraffa` (preferred) now, or should presenter also be skipped until a core base exists?]
