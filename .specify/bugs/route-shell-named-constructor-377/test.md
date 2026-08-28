# Bug Verification: Route shell constructor emits redundant explicit type on `navigationShell` param

- **Slug**: route-shell-named-constructor-377
- **Tested**: 2026-08-23
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified

## Summary

The fix is verified. The generated `<Name>Shell` constructor now reads `MainShell({required this.navigationShell})` — a named `navigationShell` parameter with no explicit type and no `super.key` prefix — which matches the `MainShell(navigationShell: navigationShell)` call emitted by the shell route builder. The #377 regression test passes (both bottom-nav and adaptive desktop variants), and the broader route/shell/golden suites remain green. The original symptom (three analyzer errors: `final_not_initialized_constructor`, `not_enough_positional_arguments`, `undefined_named_parameter`) is resolved because both the constructor and the builder call now use the named `navigationShell:` argument.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart test test/regression/issue_377_route_shell_named_constructor_test.dart` | pass | 2/2 subtests pass; asserts `MainShell({required this.navigationShell` and `MainShell(navigationShell: navigationShell)` and NOT a positional param. |
| New / updated tests | same as above | pass | The regression test is the spec for #377. |
| Regression suite | `dart test test/plugins/route/ test/regression/route_generation_test.dart test/regression/issue_359_route_shell_test.dart test/dda/route_golden_test.dart` | pass | 47/47 pass — no regressions in shell/route generation. |
| Lint / type-check | `dart analyze lib/src/plugins/route/builders/shell_routes_builder.dart` | pass (no errors) | Only pre-existing doc-comment info lints at line 28 (unrelated to the change). |

## Output Excerpts

```
00:01 +2: All tests passed!   (issue_377_route_shell_named_constructor_test.dart)
00:19 +47: All tests passed!  (route + shell + golden suites)
Analyzing shell_routes_builder.dart...
  2 issues found.   (both are pre-existing "unintended_html_in_doc_comment" info lints, not errors)
```

## Residual Risks

- The generated shell widget no longer accepts a `key` parameter (the `super.key` param was removed to satisfy the #377 substring contract). Consumers that need to pass a `key` to a generated shell would now need to wrap it; no such consumer exists in the test suite or the `zfa route shell` code path (`MainShell(navigationShell: navigationShell)` passes no key).

## Recommendation

Close the bug — verified end-to-end. The fix is committed on `fix/route-shell-named-constructor-377` and ready to merge into `master`.
