# Bug Verification: the entity pipeline produces CERTIFIED mocks (spec 1001 reconciliation)

- **Slug**: 1503-mock-create-certify-pipeline
- **Tested**: 2026-09-11
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **TDD verification**: ../../tdd/verification.md (fresh from this session's run)
- **Result**: verified

## Summary

The self-contradiction is gone. `generation_planner.dart` now emits
`mock create --name <E> --certify` from BOTH entity pipeline arms (the
traced-entity arm and the declared `GenerationSurface.entityPipeline`
arm), so run #1 leaves a certified mock on disk and run #2's spec-1001
pre-start preflight passes instead of refusing forever. The gate, the
preflight logic, and the `mock create` command are untouched; standalone
`mock create` stays opt-in.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| RED (pre-fix) | `dart test test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart` before the fix | fail (right reason) | 3 failed / 1 passed; `Actual: ['mock', 'create', '--name', 'Task']` — "does not contain '--certify'" on both arms. |
| GREEN (post-fix) | same suite after the fix | pass | 4/4. Exact argv pins: `['mock', 'create', '--name', 'Task', '--certify']` on both arms; stub arm still plans no mock step. |
| Chunked suite — planner | `dart test test/plugins/tdd/services/generation_planner_test.dart test/plugins/tdd/services/bug_1503_mock_create_certify_pipeline_test.dart` | pass | 35/35. The two pre-fix argv pins (U-829a, U-909) moved to the certified contract in the same change. |
| Chunked suite — other planner arms | declared + widget_950 + ffi_835 planner suites | pass | 18/18. No drift in declared/function/widget/ffi routing. |
| Chunked suite — standalone mock | `generation_planner_real_cli_test.dart` + `create_mock_capability_test.dart` | pass | 13/13. Standalone `mock create` unchanged (opt-in `--certify`, default false). |
| Chunked suite — gate side | `run_engine_command_test.dart` + `bug_1367_realize_mock_cert_fallback_test.dart` | pass | 17/17. Gate semantics, preflight, refusal/journaling untouched and green. |
| Static analysis | `dart analyze` over the 3 changed dart files | pass | No issues found! (re-checked after formatting) |
| Formatting | `dart format` on changed files | pass | 1 file reformatted (new test), re-verified 4/4 green. |
| Disk housekeeping | `rm -rf .dart_tool/test/`, kernel artifacts removed | pass | 8.2G free at delivery. |

## Residual Risks

- The whole-repo analyze/full-suite was not run (protocol: only test what
  changed); the chunked suites cover every planner consumer and the gate
  side reachable from this diff.
- `mock create` without `--certify` targeting a Key Entity OUTSIDE the
  TDD pipeline (expectation item 2 of the issue: refuse-or-warn loudly)
  is intentionally NOT implemented — the hard constraints scope this fix
  to the planner's mock step only, and the certified-variant request from
  the engine removes the contradiction end-to-end for the engine lane.
