# Bug Assessment: Template self-hosting defects

- **Slug**: template-self-hosting
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/912
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> Part of #908. Absorbs live defects: #907 (migrate-paths package-URI rewrite + success-on-red), apostrophe breakage, and widget-template shallowness.
>
> Live defect register (all reproduced on master):
> 1. Persistence template: behavior description 'persist the user's theme preference' injected UNESCAPED into a single-quoted Dart string → unterminated literal → compile-error.
> 2. Widget template pumps inside MaterialApp; ZikZak is ShadApp/shadcn_ui — SC-001 asserts ShadTheme.
> 3. Widget template asserts 'findsOneWidget' placeholder — green achievable by returning SizedBox(); scenario not actually asserted.
> 4. migrate-paths (#907): rewrites test relative imports but not package-URI imports in composed subjects; reports migrated=N success while the suite is unloadable.
> 5. route create dry-run omits the route-table test from the changes list (real run emits it).

## Symptom

Five distinct template/command defects block generated code from compiling or being meaningful:
1. Apostrophe in behavior description breaks Dart string literal in generated persistence test.
2. Widget test template uses `MaterialApp` but the project uses `ShadApp` (shadcn_ui).
3. Widget test asserts `findsOneWidget` as a placeholder — a test can trivially pass by returning `SizedBox()` without testing the actual scenario.
4. `zfa tdd migrate-paths` rewrites relative imports but not `package:` URI imports, producing tests that fail to load.
5. `zfa route create --dry-run` omits the route-table test file from the changes list, even though the real (non-dry-run) run generates it.

## Reproduction

1. **Apostrophe**: Create a behavior with description "persist the user's theme preference". Run `zfa tdd gen`. The generated persistence test contains an unescaped apostrophe in a single-quoted Dart string. `dart analyze` reports unterminated string literal.
2. **Widget MaterialApp**: Run `zfa tdd gen` on a behavior marked as `widget` kind. The generated test file contains `MaterialApp(home: ...)` — but the project uses `ShadApp` from shadcn_ui.
3. **Placeholder assertion**: Run `zfa tdd gen` on a widget behavior. The generated test uses `expect(find.byType(WidgetUnderTest), findsOneWidget)` — this can pass even if the widget returns an empty `SizedBox()`.
4. **migrate-paths**: Run `zfa tdd migrate-paths --feature <f>` on a feature with composed subjects that have `package:` URI imports. The command rewrites relative imports but not the package-URI imports, then reports `migrated=N` as success. The resulting tests fail to compile.
5. **route dry-run**: Run `zfa route create --dry-run --name Product`. The output does not list the route-table test file, but a real `zfa route create` generates it.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/behavior_test_writer.dart:48-49,52-58` — `_renderPersistenceTest()` renders the test; the apostrophe escaping at line 48 (`replaceAll("'", "\\'")`) escapes the group description but the **behavior description** itself (passed as a parameter) may not be escaped before insertion into the Dart string literal
- `lib/src/plugins/tdd/services/behavior_test_writer.dart:56-57` — `_renderWidgetTest()` generates the widget test template; this is where `MaterialApp` vs `ShadApp` is hardcoded and where the `findsOneWidget` placeholder lives
- `lib/src/plugins/tdd/commands/migrate_paths_command.dart:1-80` — `MigratePathsCommand` handles path rewriting; the bug is that it only rewrites relative test imports but not `package:` URI imports in composed subject files
- `lib/src/plugins/route/capabilities/create_route_capability.dart:74-78` — `dryRun` flag; the dry-run path may compute the file list differently than the real path
- `lib/src/plugins/route/builders/route_table_test_builder.dart` — builds the route-table test; may not be included in the dry-run's file list computation

## Root Cause Hypothesis

**High confidence** for defects 1-4, **medium confidence** for defect 5.

Defects 1-4 are clear code gaps:
- Defect 1: The behavior description text is interpolated into a Dart single-quoted string without escaping special characters (apostrophes, backslashes, `${}`). The group description IS escaped (line 48-49) but the behavior description is passed raw.
- Defect 2: The widget test template hardcodes `MaterialApp` — it needs to be configurable per project (default to `ShadApp` for zuraffa apps).
- Defect 3: The widget test assertion is a placeholder, not a real scenario-derived assertion. This is a known shallow-template issue.
- Defect 4: `migrate_paths_command.dart`'s import rewriter handles relative paths but its regex/logic does not match `package:` URI patterns (e.g., `import 'package:my_app/src/...'`).

Defect 5 needs verification — the dry-run path may compute files from the same builders as the real path, in which case the omission would be in the builder registration, not the dry-run logic.

## Proposed Remediation

**Preferred**:
1. **Apostrophe**: Add a Dart string escape function that handles `'`, `\`, `$`, and unicode before interpolating behavior descriptions into generated Dart strings. Add a literal-safety pin test per template.
2. **Widget template**: Make the widget template project-configurable — detect whether the project uses `ShadApp` or `MaterialApp` from the project's imports/patterns, and default to `ShadApp` for zuraffa apps. Add this as a config key.
3. **Placeholder assertion**: Replace `findsOneWidget` with a scenario-derived finder (derived from the behavior description), or mark placeholder-found tests as `'scaffolded'` and exclude them from contract-green accounting.
4. **migrate-paths**: Extend the import rewriter regex to also match and rewrite `package:` URI imports. Add a self-check that compiles the affected feature before declaring success.
5. **route dry-run**: Ensure the dry-run file list computation includes the route-table test builder.

**Alternatives**:
- For defect 2: Generate both `MaterialApp` and `ShadApp` variants and let the user choose — more flexible but adds template complexity.
- For defect 3: Skip the widget assertion entirely (just compile-test) — simpler but loses the TDD value.

**Files likely to change**:
- `lib/src/plugins/tdd/services/behavior_test_writer.dart` — escape description strings, make widget template configurable, derive scenario assertions
- `lib/src/plugins/tdd/commands/migrate_paths_command.dart` — extend import rewriter for package URIs
- `lib/src/plugins/route/capabilities/create_route_capability.dart` or builders — fix dry-run file list
- New config: project-level ShadApp/MaterialApp preference

**Tests to add or update**:
- Apostrophe literal-safety test: behavior description with `'`, `"`, `\`, `${}` → compiles
- Widget template test: ShadApp project → ShadApp in generated test
- migrate-paths test: package-URI imports are rewritten correctly
- route dry-run test: route-table test appears in dry-run output

## Risks & Considerations

- **Template changes ship through zfa's own red-green loop** (the VISION self-hosting meta-rule) — every template fix must be test-driven with the defect register as the fixture corpus.
- **Widget template configurability**: Adding a project-level config key (`widgetTemplateFramework`) introduces a new config surface that must be documented and maintained.
- **migrate-paths backward compatibility**: Existing migrated features may have already committed package-URI imports that are wrong; re-running migrate-paths on them would need to handle already-migrated-but-broken state.

## Open Questions

- [NEEDS CLARIFICATION: Is the widget template a `.dart.j2` (Jinja2) template or inline Dart string in `behavior_test_writer.dart`? The search found no `.dart.j2` or `.stg` files with `MaterialApp`.]
- [NEEDS CLARIFICATION: Does the route dry-run path share the same file-computation logic as the real path, or does it have a separate code path?]
- [NEEDS CLARIFICATION: What is the "shell-configurable widget template" mechanism — a `.zfa.json` config key, a CLI flag, or auto-detection from project imports?]
