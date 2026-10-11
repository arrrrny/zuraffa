# Bug Assessment: cache adapter receipt: kind string has space instead of hyphen, entitySource is null (2 failing tests)

- **Slug**: cache-adapter-receipt-kind
- **Created**: 2026-09-05
- **Source**: https://github.com/arrrrny/zuraffa/issues/1130
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

Two tests in `test/plugins/cache/cache_adapter_receipt_test.dart` are failing on master:

1. Receipt kind string mismatch — test expects `'cache-adapter'` (hyphenated) but the code emits `'cache adapter'` (space-separated).
2. Entity source binding — test expects a non-null `entitySource` on the receipt, but it is null.

Source: https://github.com/arrrrny/zuraffa/issues/1130

## Symptom

Two cache adapter receipt tests fail because (a) the receipt kind literal is `'cache adapter'` instead of `'cache-adapter'`, and (b) `entitySource` is null instead of the entity source file path.

## Reproduction

1. Run `dart test test/plugins/cache/cache_adapter_receipt_test.dart`.
2. Observe 2 failing tests:
   - one asserting the receipt kind equals `'cache-adapter'` (hyphen)
   - one asserting `entitySource` is non-null.

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

Candidate files per the issue body:
- `lib/src/plugins/cache/capabilities/create_cache_adapter_capability.dart`
- `lib/src/core/project/receipt_store.dart`

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

Likely:
1. A literal `'cache adapter'` was emitted instead of `'cache-adapter'`.
2. The receipt construction omitted `entitySource`, while the test expects it populated like `RepositoryContractManifest` (per `repository_plugin.dart:375-420`).

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

Per the issue orders: change the kind literal to `'cache-adapter'` and populate `entitySource` with the entity source file path.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Do not change other plugins' receipt code.
- Do not change receipt semantics beyond fixing these two bugs.

## Open Questions

- [NEEDS CLARIFICATION: exact failing assertions and full test names]
- [NEEDS CLARIFICATION: the entity source path format expected by the test]