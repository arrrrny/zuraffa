# Bug Assessment: dart_core is red on master — analyzer 14.6.0 renamed `undefined_getter` to `undefined_instance_member_read`

- **Slug**: analyzer-diagnostic-rename
- **Created**: 2026-10-22
- **Source**: https://github.com/arrrrny/zuraffa/issues/1980
- **URL fetch policy**: allowlisted (`github.com`)
- **Verdict**: valid
- **Severity**: high

## Report (summarized)

`dart_core` is red on `master` itself — and on every PR built on it. One test fails:

```
test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart:
  SPEC 1685 — review bot snippet compilable U-1685-G2:
  REAL analyzer compile check rejects the historical snippet
  (undefined_getter, the issue's exact error)   (failed)

Expected: contains 'undefined_getter'
  Actual: MappedListIterable<SnippetValidationIssue, String?>:[
             'undefined_instance_member_read'
           ]
   Which: does not contain 'undefined_getter'
```

The issue identifies the root cause: analyzer **14.6.0** replaces the diagnostic
`undefined_getter` with `undefined_instance_member_read`. `pubspec.yaml` pins
`analyzer: ^14.4.0` and `pubspec.lock` is **not committed**, so CI always
resolves the newest matching analyzer.

Evidence quoted in the issue: failing CI on master @ `14b8698` — run
`39720800663`, job `dart_core`, 1 failing test; the same single failure on the
`arrrrny/zuraffa#1977` head @ `f1bb1d2` (run `39730566786`).

## Symptom

The SPEC 1685 snippet-compile gate test asserts that the REAL analyzer
compile check rejects the historical buggy snippet with the diagnostic code
`undefined_getter`. On analyzer ≥ 14.6.0 the same error class is reported under
the new name `undefined_instance_member_read`, so the assertion fails and the
`dart_core` lane is red on `master`.

## Reproduction

1. Clone `arrrrny/zuraffa` at `master` (`14b86989`).
2. `dart pub get` — resolves `analyzer 14.6.0` (the lock file is not committed,
   so resolution is always "newest matching").
3. `dart test test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`
4. Observed locally on 2026-10-22 with analyzer 14.6.0: `04:03 +8 -1` — the
   U-1685-G2 "REAL analyzer compile check rejects the historical snippet" case
   fails with `Expected: contains 'undefined_getter'` / `Actual:
   ['undefined_instance_member_read']`. Identical to the issue report.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart:234` —
  the machine-readable code is derived straight from the analyzer:
  `code: diagnostic.errorCode.name.toLowerCase()`. This is correct and
  version-agnostic; it is the *consumer* that pinned a literal name.
- `test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart:82`
  — the assertion that hard-codes the literal `'undefined_getter'`.
- `pubspec.yaml:44` — `analyzer: ^14.4.0` (a caret range with no upper bound)
  combined with an uncommitted `pubspec.lock`, which is why a fresh analyzer
  release reaches CI unreviewed.

## Root Cause Hypothesis

Confidence: **high** (reproduced locally).

The analyzer diagnostic that reports "a member does not exist on this type" was
renamed in analyzer 14.6.0: `undefined_getter` ("The getter '{0}' isn't defined
for the type '{1}'.") became `undefined_instance_member_read` ("The member '{0}'
isn't defined for the type '{1}'."). It is the same error class under a new
name. The SPEC 1685 test asserted the literal old name, so the rename broke a
test that asserts a *diagnostic identity*, not a behaviour.

The deeper cause is that this package resolves the analyzer fresh on every CI
run (`pubspec.lock` is not committed and the constraint is an open caret
range), so any future rename breaks the suite again.

## Proposed Remediation

**Preferred**: make the assertion accept both names of that ONE error class —
`undefined_getter` (analyzer ≤ 14.5.x) and `undefined_instance_member_read`
(analyzer ≥ 14.6.0) — with `contains(anyOf(...))`. This is the smallest diff
that keeps the test's meaning ("the compile check rejects this snippet with a
missing-member error") while surviving the rename.

**Alternatives** (not in this fix):
- Commit `pubspec.lock` for this package, or pin the analyzer upper bound in
  `pubspec.yaml` and bump it deliberately — this addresses the *root* cause
  (an unpinned analyzer) but is explicitly deferred by the issue to a separate
  change, because it would freeze every other transitive dependency too.
- Assert on the diagnostic *message* instead of the code — more brittle across
  analyzer wording changes, not less.

**Files likely to change**:
- `test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`

**Tests to add or update**:
- Update the existing U-1685-G2 assertion so it accepts both diagnostic names.
  No new test file is needed: the failing test IS the regression test.

## Risks & Considerations

- Low risk: the change is confined to a test assertion. It does not weaken the
  gate — the test still requires the compile check to reject the snippet, and
  still requires a missing-member diagnostic, it just no longer pins the
  analyzer's spelling of that diagnostic.
- The broader exposure (any future analyzer rename, and every other test that
  asserts a literal analyzer diagnostic name) remains. That is the deferred
  longer-term item named in the issue.

## Open Questions

None. The issue body names the root cause, the fix and the verification, and
the failure was reproduced locally before the fix was applied.
