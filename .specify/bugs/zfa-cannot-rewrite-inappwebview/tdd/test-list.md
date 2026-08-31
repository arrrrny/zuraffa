---
feature: zfa-cannot-rewrite-inappwebview
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 3
planned_at: fa2c501b
updated_at: fa2c501b
suite_baseline: 'docs_command_consistency 8/8 green at fa2c501b via `dart test --preset=regression test/regression/docs_command_consistency_test.dart`'
---

# Test List: Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin

Derived from `spec.md` (issue #477). The assessment names **no code change**:
this is a documentation/expectations fix, so the behaviors pin a doc contract,
following the repo's existing doc-content regression pattern
(`test/regression/docs_command_consistency_test.dart`). `outer-only` because
there is no `plan.md` and no component logic: the "implementation" is
hand-maintained prose in `CLI_GUIDE.md` and `README.md`.

## Outer loop: acceptance behaviors

| id  | behavior                                                                                                                            | traces | kind    | state | test                                                                          |
| --- | ----------------------------------------------------------------------------------------------------------------------------------- | ------ | ------- | ----- | ----------------------------------------------------------------------------- |
| A1  | `CLI_GUIDE.md` scopes `zfa` to Zuraffa apps (clean-architecture generator contract, not a general rewriter)                          | AC1    | example | RED   | `test/regression/issue_477_zfa_scope_docs_test.dart::guide scopes zfa`         |
| A2  | `CLI_GUIDE.md` states `zfa` does not rewrite existing non-Zuraffa Flutter packages or plugins                                       | AC2    | example | RED   | `test/regression/issue_477_zfa_scope_docs_test.dart::guide non-Zuraffa limit`  |
| A3  | `CLI_GUIDE.md` frames `zfa doctor`'s missing-dependency output inside a non-Zuraffa package as expected behavior, not a malfunction | AC2    | example | RED   | `test/regression/issue_477_zfa_scope_docs_test.dart::guide doctor expected`    |
| A4  | `CLI_GUIDE.md` routes plugin-rewrite support to a feature request instead of a silent misfire                                        | AC3    | example | RED   | `test/regression/issue_477_zfa_scope_docs_test.dart::guide feature request`    |
| A5  | `README.md` carries the short scope statement (Zuraffa apps; non-Zuraffa packages not rewritable by `zfa`)                          | AC2    | example | RED   | `test/regression/issue_477_zfa_scope_docs_test.dart::readme scope`             |

## Inner loop: unit behaviors

Not derived: the fix changes no library code, so there is no unit surface to
drive. The doc assertions are the load-bearing behaviors; a deliberate mutant
(removing the scope prose) must flip them red, which is what proves the safety
net is real without a mutation tool.

## Invariants and edge cases still to place

- The doc contract must not regress the neighboring doc-contract test:
  `docs_command_consistency_test.dart` (still asserts `zfa make` present,
  `zfa generate` absent) is re-run after the doc edits.
- New prose must not reintroduce the removed `zfa generate` command name
  (checked by the existing suite, listed here so the constraint is explicit).

## Out of scope

- Any `zfa` source change (assessment: no code change needed).
- A new command that rewrites non-Zuraffa plugins (separate feature request).

## Verification commands (from profile)

- Single test: `dart test --preset=regression test/regression/issue_477_zfa_scope_docs_test.dart`
- Neighbor doc contract: `dart test --preset=regression test/regression/docs_command_consistency_test.dart`
- Analyze: `dart analyze test/regression/issue_477_zfa_scope_docs_test.dart`
