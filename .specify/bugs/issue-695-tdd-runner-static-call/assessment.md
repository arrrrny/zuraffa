# Bug Assessment: fix(tdd): runner.dart calls static _firstMatchValue as instance method — compile error

- **Slug**: issue-695-tdd-runner-static-call
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/695
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`lib/src/plugins/tdd/services/runner.dart` (branch `053-rebase`, commit `69c0a7a5`) declares `_firstMatchValue` as `static` on line 257, but six call sites (lines 95, 120, 130, 173, 195, 203) invoke it without the `ClassName.` prefix — treating it as an instance method. This is a compile error in Dart. The bug was introduced when `_firstMatchValue` was added to support quoted/unquoted YAML scalars in the profile loader.

## Symptom

Running `zfa tdd run <feature>` (from a binary built from `053-rebase`) stops at the first A*:make step with a Dart compile error: `Error: The method '_firstMatchValue' isn't defined for the type 'SingleTestRunner'`.

## Reproduction

1. Build `zfa` from the `053-rebase` branch (commit `69c0a7a5`).
2. Run `zfa tdd run <feature>` in any project with a TDD test list.
3. When execution reaches behavior A3 (the make step), the runner crashes with the compile error at `runner.dart:95`.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/runner.dart:257` — `static String? _firstMatchValue(String pattern, String input)` declared as static helper on `SingleTestRunner`.
- `runner.dart:95` — `_firstMatchValue(...)` called as instance method in `loadSingleTemplate`.
- `runner.dart:120` — `_firstMatchValue(...)` called as instance method in `loadSingleTemplate`.
- `runner.dart:130` — `_firstMatchValue(...)` called as instance method in `loadSingleTemplate`.
- `runner.dart:173` — `_firstMatchValue(...)` called as instance method in `loadSuiteTemplate`.
- `runner.dart:195` — `_firstMatchValue(...)` called as instance method in `loadSuiteTemplate`.
- `runner.dart:203` — `_firstMatchValue(...)` called as instance method in `loadSuiteTemplate`.

All seven locations are on the `053-rebase` branch. The `master` branch does not contain `_firstMatchValue` — it was removed entirely in a later refactor (the inline `RegExp(...).firstMatch(...).group(...)` pattern was restored).

## Root Cause Hypothesis

**High confidence.** Commit `69c0a7a5` on `053-rebase` added `_firstMatchValue` as a `static` helper to support both quoted and unquoted YAML scalar values in the profile loader, but the six call sites inside instance methods (`loadSingleTemplate`, `loadSuiteTemplate`) invoke it without the `SingleTestRunner.` prefix. Dart requires `ClassName.staticMethod()` syntax; omitting the prefix makes it look for an instance method, which does not exist.

## Proposed Remediation

**Preferred**: Remove the `static` keyword from the `_firstMatchValue` declaration (Option B from the issue). This is the minimal, correct fix — the method is a pure helper with no dependency on static state.

```diff
-  static String? _firstMatchValue(String pattern, String input) {
+  String? _firstMatchValue(String pattern, String input) {
```

**Alternative A** (as noted in the issue): prefix all six callers with `SingleTestRunner._firstMatchValue(...)`. More verbose but equally correct.

**Note**: `master` already resolved this differently — it removed `_firstMatchValue` entirely and inlined the regex logic at each call site. This is a larger change than the minimal fix and may not be appropriate to backport to `053-rebase if that branch is targeted for a specific PR.

**Files likely to change**:
- `lib/src/plugins/tdd/services/runner.dart` — one line (remove `static`).

**Tests to add or update**:
- `test/plugins/tdd/services/runner_test.dart` — add coverage for quoted (`"value"`), single-quoted (`'value'`), and bare unquoted YAML scalar values in both `single:` and `suite:` profile keys.

## Risks & Considerations

- The fix is trivial (one keyword removal) with no behavioral change — only the compile error is resolved.
- If `053-rebase` is targeted for a PR into `master`, verify that the `master` approach (removing `_firstMatchValue` entirely) doesn't conflict, since `master` is the merge target.
- No API or data migration risk.

## Open Questions

- [RESOLVED: Confirmed on `053-rebase` at commit `69c0a7a5` — static declaration on line 257, six instance-method call sites on lines 95, 120, 130, 173, 195, 203.]
- [RESOLVED: `master` does not have this bug — `_firstMatchValue` was removed from master; the fix approach there was to not introduce the helper at all.]
