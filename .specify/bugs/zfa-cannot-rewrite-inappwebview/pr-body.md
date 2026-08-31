# PR Body: fix(477): Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin

## Summary

Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin (closes #477)

Root cause: `zfa` commands fail when run inside `zikzak_inappwebview/`
because the plugin is not a Zuraffa app and lacks required dependencies
(.zfa.json, zuraffa package, zorphy_annotation). `zfa` is purpose-built for
Zuraffa apps and has no command to rewrite arbitrary Flutter plugins. The
issue reports a valid limitation: `zfa` cannot operate on non-Zuraffa
Flutter packages like `zikzak_inappwebview`. This is expected behavior, not
a bug — the original request was misaligned with `zfa`'s capabilities.
Confidence: high.

Remediation: No code change needed. This is a documentation/expectations
issue. The reporter correctly identified the limitation. Options:
1. **Clarify intent**: Determine if the goal is to (a) scaffold new
   Zuraffa-style modules inside a Zuraffa app, (b) rewrite only a
   Zuraffa-compatible subset, or (c) accept hand-written code for the
   plugin. 2. **Feature request**: If `zfa` should support plugin rewrites,
   file a separate feature request for a command that operates on
   non-Zuraffa Flutter packages.

This PR applies the assessment's remediation minimally: an explicit scope
statement in `CLI_GUIDE.md` ("Scope: what `zfa` operates on") and `README.md`
("Scope"), pinned by a new doc-contract regression test
(`test/regression/issue_477_zfa_scope_docs_test.dart`, red → green, TDD
cycle in `.specify/bugs/zfa-cannot-rewrite-inappwebview/tdd/`).

## Verification

- `dart analyze` — No issues found!
- `dart test` — scoped to the change's tiers (the chunked fast suite plus
  the regression-preset doc tests):
  - Chunked fast suite (same per-chunk commands as
    `tools/run_tests_chunked.sh`): 59/59 executed chunks green, no new
    failures; 5 all-slow-tagged folders (`test/benchmark`,
    `test/core/dependencies`, `test/integration`, `test/plugins/tdd/scenarios`,
    `test/property`) exit 79 "No tests ran" — pre-existing at baseline
    (verified with the fix stashed), unrelated to this change.
  - `dart test --preset=regression test/regression/issue_477_zfa_scope_docs_test.dart`
    → 5/5 pass (was 5/5 RED before the doc change).
  - `dart test --preset=regression test/regression/docs_command_consistency_test.dart`
    → 8/8 pass (doc edits regress nothing).
- `dart format .` — clean, no remaining diffs.
- TDD verification: `.specify/bugs/zfa-cannot-rewrite-inappwebview/tdd/verification.md`
  (verdict PASS_WITH_GAPS; 2/2 deliberate mutants caught and restored).

Closes #477
