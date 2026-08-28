# Bug Assessment: Route shell constructor emits redundant explicit type on `navigationShell` param

- **Slug**: route-shell-named-constructor-377
- **Created**: 2026-08-23
- **Source**: pasted text (failing regression test output)
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

Failing regression test: `test/regression/issue_377_route_shell_named_constructor_test.dart` (issue #377). Two subtests fail:

1. `#377 — route shell constructor must be named generated shell class uses a named navigationShell constructor`
2. `#377 — route shell constructor must be named adaptive (desktop) shell class also uses a named constructor`

Expected: generated shell class constructor contains the substring `MainShell({required this.navigationShell`.

Actual generated source:

```dart
class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required StatefulNavigationShell this.navigationShell,
  });
  final StatefulNavigationShell navigationShell;
  ...
}
```

The constructor parameter is emitted as `required StatefulNavigationShell this.navigationShell` (explicit type + `this.`), which does not contain the expected named-parameter form `required this.navigationShell`.

## Symptom

The route/shell code generator emits the shell widget's `navigationShell` constructor parameter with a redundant explicit `StatefulNavigationShell` type. The regression test (a golden/substring assertion introduced for #377) expects the parameter in the `required this.navigationShell` form, so the test fails. The generated code is still valid Dart and functionally works; this is a code-style/golden mismatch, not a runtime break.

## Reproduction

1. Generate a route shell (e.g. via `zfa route create --shell` or the regression test fixture).
2. Inspect the generated `<Name>Shell` class constructor.
3. Observe `required StatefulNavigationShell this.navigationShell` instead of `required this.navigationShell`.
4. (Or) run `dart test test/regression/issue_377_route_shell_named_constructor_test.dart` — both subtests fail.

## Suspected Code Paths

- `lib/src/plugins/route/builders/shell_routes_builder.dart:168-177` — `Parameter((p) => p ..name = 'navigationShell' ..type = refer('StatefulNavigationShell') ..named = true ..required = true ..toThis = true)` for the bottom-nav (default) shell. The combination of `..type` + `..toThis` makes `code_builder` print `StatefulNavigationShell this.navigationShell`.
- `lib/src/plugins/route/builders/shell_routes_builder.dart:280-289` — identical `Parameter` construction for the adaptive/desktop shell variant.

## Root Cause Hypothesis

`code_builder`'s `Parameter` prints the explicit `type` when set, even when `toThis = true`. Because both `..type` and `..toThis` are set, the output is `required StatefulNavigationShell this.navigationShell`. The field declaration (`Field` at lines 182-186 / 294-298) still carries the `StatefulNavigationShell` type, so the parameter type is redundant. Removing `..type` from the two `Parameter` blocks yields `required this.navigationShell` (type inferred from the field), matching the test. Confidence: high.

## Proposed Remediation

**Preferred**: In `lib/src/plugins/route/builders/shell_routes_builder.dart`, remove the `..type = refer('StatefulNavigationShell')` line from both `Parameter` blocks (the bottom-nav constructor at ~171-175 and the adaptive constructor at ~283-287). Leave `..name`, `..named`, `..required`, and `..toThis` intact. The `Field` declarations keep the `StatefulNavigationShell` type, so the parameter type is still inferred correctly.

**Alternatives**:
- Change the regression test's expected substring to accept the explicit-type form. Rejected: the `required this.navigationShell` form is cleaner and is the intended contract for #377; fixing the generator is the correct direction.

**Files likely to change**:
- `lib/src/plugins/route/builders/shell_routes_builder.dart`

**Tests to add or update**:
- `test/regression/issue_377_route_shell_named_constructor_test.dart` already covers both variants; no new test needed. Should pass once the generator is fixed.

## Risks & Considerations

- The field type is unchanged, so no API/type breakage for consumers of the generated shell.
- Any other golden/snapshot tests that pinned the old `required StatefulNavigationShell this.navigationShell` form would need updating — none identified beyond this regression test.

## Open Questions

- None.
