# TDD Verification — spec `1256-update-setup-zuraffa-ui` (issue #1256)

RED → GREEN → verify, with REAL evidence from this branch's runs.
Every count below comes from an actual `dart test` / `dart analyze` /
`dart format` invocation on this branch; nothing is inferred.
Environment: Dart 3.13.3 stable (`/home/z/dart-sdk`), Linux sandbox —
the spec's declared toolchain floor (Dart 3.13+). Flutter SDK is NOT
available in this sandbox; the repo's root package is pure Dart and its
`dart test` suite runs without Flutter (the `example/` Flutter
subpackage is excluded and untouched).

## 1. Root cause (TDD step 1)

Read issue #1256, the spec context, and the live tree:

- **Setup gap**: `zfa setup` and `zfa init` share one wiring path —
  `DependencyWirer.standardSet(isFlutter:)`
  (`lib/src/core/dependencies/dependency_wirer.dart`). For Flutter apps
  it wired `zuraffa_flutter`, `zorphy_annotation`, `json_annotation`,
  `build_runner`, `json_serializable`, `flutter_lints` + analyzer/meta
  overrides — but NOT `zuraffa_ui`. A fresh app therefore had to add
  `zuraffa_ui` by hand.
- **Scaffold gap**: the widget lane's app shell
  (`lib/src/plugins/tdd/services/widget_scaffold.dart`,
  `WidgetAppShell`) defaulted to `shadapp` — generated widget tests
  emitted `pumpWidget(ShadApp(...))` and
  `import 'package:shadcn_ui/shadcn_ui.dart';`, and the theme-harness
  template (`theme_harness_test_writer.dart`) emitted the raw `Shad*`
  engine vocabulary (`ShadTheme.of`, `ShadThemeData`,
  `find.byType(ShadApp)`). Generated code required manual ShadApp →
  zuraffa_ui migration, violating the zfa-only generation contract.
- `zuraffa_ui` 0.1.0 is live on pub.dev (verified via the pub API):
  the barrel exports `ZuraffaApp` (the certified shell wrapping the
  engine), `ZfaTheme`/`ZfaThemeData` (zero-cost type aliases of
  `ShadTheme`/`ShadThemeData`) and the identified `Zfa*` components —
  a drop-in vocabulary replacement for the emitted templates.

## 2. RED (step 2 — reproduced before any implementation)

Evidence artifacts:

- New pin file `test/plugins/tdd/commands/spec_1256_zuraffa_ui_scaffold_test.dart`
  written FIRST (house pattern, issue-#938 precedent: new-API pins are
  compile-red until the fix lands).
- Repro script `specs/1256-update-setup-zuraffa-ui/tdd/red_repro.dart` run against the
  pristine lib:

```text
$ dart test test/plugins/tdd/commands/spec_1256_zuraffa_ui_scaffold_test.dart
test/plugins/tdd/commands/spec_1256_zuraffa_ui_scaffold_test.dart:NN:NN:
  Error: Member not found: 'zuraffaapp'.
  Error: Member not found: 'WidgetShadcnPreflight.importRequired'.
  Error: Member not found: 'WidgetShadcnPreflight.requiredPackage'.
  Error: Member not found: 'WidgetShadcnPreflight.projectDeclares'.
  Error: Member not found: 'WidgetShadcnPreflight.fixLineFor'.
00:00 +0 -1: Some tests failed.

$ dart run specs/1256-update-setup-zuraffa-ui/tdd/red_repro.dart
RED-1 standardSet(isFlutter: true) wires zuraffa_ui: false
     (expected: true — issue #1256) -> RED
RED-2 default widget shell: shadapp (ShadApp)
     (expected: a zuraffaapp shell emitting ZuraffaApp) -> RED
```

RED captured on both fronts: the dependency set omits `zuraffa_ui`
(runtime red), and the `zuraffaapp` shell / shell-aware preflight API
does not exist (compile red).

## 3. GREEN (step 3 — implementation + passing runs)

Landing map (all under `lib/`):

- `core/dependencies/dependency_wirer.dart` — `standardSet` gains
  `zuraffa_ui ^0.1.0` (hosted regular dep) for `isFlutter: true` only;
  both `zfa setup` and `zfa init` inherit it through the shared wiring.
- `plugins/tdd/services/widget_scaffold.dart` — `WidgetAppShell` gains
  `zuraffaapp` (default in `parse()`; `widgetName` → `ZuraffaApp`);
  `shadapp` kept as an explicit legacy opt-in, `materialapp` opt-out
  unchanged. `WidgetShadcnPreflight` generalized shell-aware:
  `requiredPackage` (zuraffaapp→`zuraffa_ui`, shadapp→`shadcn_ui`,
  materialapp→none), `importRequired`, `projectDeclares`,
  `fixLineFor`; the #938 shadcn statics remain valid for the shadapp
  shell (API stability).
- `plugins/tdd/services/behavior_test_writer.dart` — default shell
  `zuraffaapp`; the emitted shell import switches per shell
  (`package:zuraffa_ui/zuraffa_ui.dart` for the default).
- `plugins/tdd/services/theme_harness_test_writer.dart` — emitted
  template imports `package:zuraffa_ui/zuraffa_ui.dart`; `ShadTheme.of`
  → `ZfaTheme.of`, `ShadThemeData` → `ZfaThemeData`,
  `find.byType(ShadApp)` → `find.byType(ZuraffaApp)`; header/prereq
  prose updated (shadcn_ui → zuraffa_ui).
- `plugins/tdd/commands/gen_command.dart` — `--widget-shell` allowed
  values + help updated; `_resolveWidgetShell` fallback → `zuraffaapp`;
  the #938 preflight call site is shell-aware and the refusal reason +
  fix line name the shell's actual package.
- `config/zfa_config.dart` — `tdd.widgetShell` accepts
  `zuraffaapp | shadapp | materialapp`.

GREEN runs:

```text
$ dart test test/plugins/tdd/commands/spec_1256_zuraffa_ui_scaffold_test.dart
00:00 +17: All tests passed!

$ dart run specs/1256-update-setup-zuraffa-ui/tdd/red_repro.dart
RED-1 standardSet(isFlutter: true) wires zuraffa_ui: true -> GREEN
RED-2 default widget shell: zuraffaapp (ZuraffaApp)     -> GREEN
```

Existing-test reconciliation (three pins encoded the OLD default and
were updated to the #1256 contract, preserving their core guarantees):

- `bug_912_widget_shell_and_finders_test.dart` — "default gen" pin now
  expects the ZuraffaApp shell + zuraffa_ui import (pubspec seeded with
  `zuraffa_ui` so the #938 preflight passes, mirroring a post-#1256
  `zfa setup` app); the explicit-shadapp pin kept (renamed to say so).
- `bug_938_widget_shadcn_preflight_test.dart` — the refusal contract
  (non-zero exit, machine-parseable `--> fix:` line, zero artifacts,
  untouched registry) is unchanged; the default shell's package is now
  `zuraffa_ui`; added a legacy `--widget-shell shadapp` +
  declared-shadcn_ui back-compat pin; refusal must NOT print the legacy
  shadcn fix line.
- `theme_harness_test_writer_test.dart` — theme-assertion pin now
  expects `ZfaTheme.of` and `isNot(contains('ShadTheme.of'))`.

## 4. Refactor (step 4)

None required — the change landed as wiring + template vocabulary with
no post-green restructuring.

## 5. Verify (step 5 — MANDATORY)

Kernel-cache hygiene per the standing instructions:
`rm -rf .dart_tool/test/ ; rm -f /tmp/dart_test.kernel.*` before and
after every run below (a full-suite kernel cache reached 8 GB in this
sandbox and filled /tmp mid-run twice; every count below is from a run
that completed with the cache cleaned before and after).

a) Analyze ONLY the changed files:

```text
$ dart analyze lib/src/config/zfa_config.dart \
    lib/src/core/dependencies/dependency_wirer.dart \
    lib/src/plugins/tdd/commands/gen_command.dart \
    lib/src/plugins/tdd/services/behavior_test_writer.dart \
    lib/src/plugins/tdd/services/theme_harness_test_writer.dart \
    lib/src/plugins/tdd/services/widget_scaffold.dart \
    test/plugins/tdd/commands/bug_912_widget_shell_and_finders_test.dart \
    test/plugins/tdd/commands/bug_938_widget_shadcn_preflight_test.dart \
    test/plugins/tdd/services/theme_harness_test_writer_test.dart
Analyzing zfa_config.dart, dependency_wirer.dart, gen_command.dart,
  behavior_test_writer.dart, theme_harness_test_writer.dart,
  widget_scaffold.dart, bug_912_widget_shell_and_finders_test.dart,
  bug_938_widget_shadcn_preflight_test.dart,
  theme_harness_test_writer_test.dart...
No issues found!
```

b) Run ONLY the tests covering the modified code (the repo does not
mirror lib/ paths into test/, so each changed lib file is mapped to its
covering suite):

```text
$ dart test \
    test/plugins/tdd/commands/spec_1256_zuraffa_ui_scaffold_test.dart \
    test/core/dependencies/dependency_wirer_test.dart \
    test/plugins/tdd/services/bug_938_shadcn_preflight_unit_test.dart \
    test/plugins/tdd/commands/bug_938_widget_shadcn_preflight_test.dart \
    test/plugins/tdd/commands/bug_912_widget_shell_and_finders_test.dart \
    test/plugins/tdd/commands/bug_965_test_shell_resolved_keys_test.dart \
    test/plugins/tdd/services/theme_harness_test_writer_test.dart \
    test/plugins/tdd/services/behavior_test_writer_test.dart \
    test/plugins/tdd/services/behavior_test_writer_persistence_833_test.dart \
    test/config/zfa_config_test.dart \
    test/commands/setup_command_test.dart
00:05 +72: All tests passed!          (72 passed / 0 failed)
```

c) Wider assurance (same tree, post-fix):

```text
$ dart test test/plugins/tdd/services/ test/plugins/tdd/commands/ \
             test/plugins/tdd/models/ test/plugins/tdd/helpers/
02:24 +1179: (after the theme-harness pin update below) all green

$ dart test test/plugins/tdd/*.dart          (top-level tdd files)
00:35 +377: All tests passed!

$ dart test test/commands/ test/core/ test/config/
04:33 +941 ~1: All tests passed!             (1 pre-existing skip)

$ dart test test/agent/ test/app_update/ test/benchmark/ test/biometrics/ \
    test/cli/ test/clipboard/ test/dda/ test/device/ test/domain/ \
    test/engine/ test/feature_flags/ test/fixes/ test/graphql/ \
    test/helpers/ test/i18n/
01:20 +898: All tests passed!

$ dart test test/tdd/                        (self-hosting loop corpus)
00:50 +128: All tests passed!
```

d) Format (CI gate):

```text
$ dart format --output=none --set-exit-if-changed lib test
Formatted 2362 files (0 changed) in 6.27 seconds.   EXIT: 0
```

e) Known pre-existing failure, NOT caused by this branch: running the
21-directory chunk (`test/integration/ … test/zap/`) fails inside
`test/tdd/073-slice-isolation/` on BOTH trees — the identical chunk was
run on the pristine base commit `d3679e0f` (via `git stash`) and failed
there too (`-49`); on this branch the unique failing files are exactly
`test/tdd/073-slice-isolation/a1{1,2,3,4}_test.dart`, which reference
none of this spec's changed APIs (grep: zero hits for
`WidgetAppShell|BehaviorTestWriter|ThemeHarnessTestWriter|
WidgetShadcnPreflight|DependencyWirer|standardSet|widgetShell`), pass
in isolation on this branch (`+1: All tests passed!` for a11), and are
self-hosting loop fixtures whose only import is their own subject stub.
Chunk-composition test interference; out of scope for #1256 and left
untouched (no source or fixture file outside this spec's surface was
modified).

## 6. Success criteria — PROVED vs not

| Criterion (from the issue) | Status | Evidence |
| --- | --- | --- |
| `zfa setup` initializes a project with `zuraffa_ui` integrated by default | PROVED (unit/CLI level) | `standardSet(isFlutter: true)` contains `zuraffa_ui ^0.1.0` (hosted regular); `findMissing` reports it on a fresh pubspec and is satisfied once declared — spec_1256 pins + `dependency_wirer_test` (+72 batch) |
| `zfa init` adds the `zuraffa_ui` dependency | PROVED (unit level) | Same shared wiring path (`DependencyWirer.wire` is the documented `zfa init` implementor); `dart pub add`-based wiring exercised by the existing wirer tests |
| New Flutter application scaffolds created by `zfa` use `zuraffa_ui` for UI components | PROVED (unit/CLI level) | Default shell `zuraffaapp`: emitted widget tests pump `ZuraffaApp` + import `package:zuraffa_ui/zuraffa_ui.dart` (writer pins + end-to-end `zfa tdd gen` run through `CliRunner`); theme-harness template emits `ZfaTheme.of` / `ZfaThemeData` / `find.byType(ZuraffaApp)` with zero `shadcn_ui` references |
| Generated code no longer needs manual ShadApp → zuraffa_ui migration | PROVED at the template level (the emitted files contain no Shad engine names) | `isNot(contains('package:shadcn_ui'))` + `isNot(contains('ShadApp'))` pins on both writers' output |
| `shadcn_ui`-based projects are not broken | PROVED | `shadapp` shell retained behind `--widget-shell shadapp` / `.zfa.json`; back-compat pin asserts ShadApp + shadcn_ui import end-to-end |
| Real end-to-end `flutter create` + `zfa setup <app>` + `flutter pub get` on-device run | NOT PROVED here | The sandbox has no Flutter SDK (the repo's own `example/` Flutter subpackage cannot resolve without it). The wiring path both commands share is proved at the unit/CLI level above; the `flutter pub add` mechanics themselves are unchanged and are exercised by the existing wirer tests. |
