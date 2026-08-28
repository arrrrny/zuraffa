# Bug Verification: ModuleOrchestratorBuilder generates unparseable Dart (getter bodies without return)

- **Slug**: issue-247-bug-moduleorchestratorbuilder-generates-unparseable-dart-get
- **Tested**: 2026-08-22T19:50:00+00:00
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified-fixed (reproduction test passes on origin/master)

## Summary

The unparseable getter-body output is not reproducible on `origin/master`
(`c0b3758`). The builder emits via `code_builder` + `DartFormatter`, so the
generated orchestrator parses and formats cleanly.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction | `dart test test/plugins/module/module_plugin_test.dart` | pass | `+2: All tests passed!` |
| Generated content | assert `class TodoFeaturePlugin`, `extends ZuraffaPlugin`, `'todo'` | pass | Format-parseable output. |

## Output Excerpts

```
00:00 +2: All tests passed!
```

## Residual Risks

- None. The fix is already merged and covered by an existing regression test.

## Recommendation

Close issue #247.
