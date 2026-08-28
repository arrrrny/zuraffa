# Bug Assessment: bug: ModuleOrchestratorBuilder generates unparseable Dart (getter bodies without return)

- **Slug**: issue-247-bug-moduleorchestratorbuilder-generates-unparseable-dart-get
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/247
- **Verdict**: already fixed on master (verified — reproduction test passes)
- **Severity**: test (per labels), not reproducible on current origin/master

## Report (verbatim or summarized)

`ModuleOrchestratorBuilder` emitted unparseable Dart: getter bodies used
`{ 'todo' }` instead of `=> 'todo'`, statements joined on one line, and the
`routes` getter had a body-less `{` with only a comment. `dart format` failed.

## Symptom

`dart format` could not parse the generated orchestrator file (missing `;`,
unterminated getter bodies).

## Reproduction

`flutter test test/plugins/module/module_plugin_test.dart` — the two
`ModuleOrchestratorBuilder` cases.

## Suspected Code Paths

- `lib/src/plugins/module/builders/module_orchestrator_builder.dart` —
  the original hand-rolled string templates built getter bodies without arrow
  syntax / return statements and concatenated imports + class on one line.

## Root Cause Hypothesis

String-concatenation codegen produced syntactically invalid Dart because
getter bodies were emitted as `{ value }` (block without `return`) and
directives/declarations were not separated by newlines.

## Proposed Remediation

Already applied on master: the builder now uses the `code_builder` package to
emit the `Library`/`Class`/`Method` AST and runs `DartFormatter.format(...)`
before writing, guaranteeing parseable, formatted output (e.g.
`String get pluginId => 'todo';`).

## Files likely to change

- `lib/src/plugins/module/builders/module_orchestrator_builder.dart` (already fixed)

## Tests to add

- `test/plugins/module/module_plugin_test.dart` already asserts the generated
  content contains `class TodoFeaturePlugin`, `extends ZuraffaPlugin`, and
  `'todo'`; it passes on `origin/master` (`c0b3758`): `+2: All tests passed!`.

## Risks & Considerations

- None for the fix; it is present and verified.
- GitHub issue #247 is still OPEN although the fix is merged.

## Open Questions

- None. Not reproducible on current master.
