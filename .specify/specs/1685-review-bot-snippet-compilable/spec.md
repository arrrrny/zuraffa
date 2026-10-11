# 1685-review-bot-snippet-compilable

- **Spec ID**: 1685-review-bot-snippet-compilable
- **Created**: 2026-09-18
- **Source**: GitHub issue #1685 (review bot snippet uses non-existent `Directory.deleteRecursively` — the posted suggestion cannot compile)
- **Type**: review-bot snippet template + validation fix (P2 — every temp-dir cleanup suggestion emitted from the buggy template lands as an `undefined_getter` compile error in the consumer's test suite)
- **Branch**: fix/1685-review-bot-snippet-compilable
- **Related**: arrrrny/zuraffa_browser#165 (inline comment id 4023967373, `test/widget/browser_settings_page_test.dart:38` — the misfire site), pool task 29275fc9-01e5-4a01-aeeb-3239a9b5b5e3 (apply review fixes for PR #165), spec 070 (the ci_referee comment-posting pipeline the validator slots beside), #1570 (the precedent compile-bar test built from a zuraffa-review finding), #1664 (the scratch build-dir pattern)

## Problem

The review comment posted by `zuraffa-review[bot]` on
arrrrny/zuraffa_browser#165 (inline comment id 4023967373,
`test/widget/browser_settings_page_test.dart:38`) proposes:

```dart
addTearDown(_tmp.deleteRecursively)
```

`deleteRecursively` is not a member of `dart:io`'s `Directory` (which only
has `delete({recursive})` / `deleteSync({recursive})`), and it is not
provided by any extension exported from flutter_test, test_api 0.7.12, or
any package imported by that test file. The snippet as written cannot
compile:

```
error - test/widget/browser_settings_page_test.dart:42:19 - The getter 'deleteRecursively' isn't defined for the type 'Directory'. - undefined_getter
```

**Workaround already applied** (in the consumer repo):
`addTearDown(() => tmp.deleteSync(recursive: true))` — same cleanup
semantics with plain dart:io, plus an inline comment in the test linking
this issue.

### Root cause

The snippet-generation path hands out a temp-dir-cleanup template whose
cleanup call names an API that does not exist anywhere in the snippet's
reachable API surface (`dart:io`, `flutter_test`, `test_api`). Nothing on
the generation path verifies that the emitted code resolves before the
comment is posted — there is no compile-check (or any snippet validation)
between "template rendered" and "suggestion published", so a non-existent
API reference ships straight to the reviewer's test file.

The repo-side artifacts of that pipeline are the first-party snippet
templates and their validation gate. The canonical cleanup idiom already
used elsewhere in this codebase is the correct shape:
`addTearDown(() => dir.deleteSync(recursive: true));`
(`lib/tdd/073-slice-isolation/u1_subject.dart:19`,
`lib/tdd/078-skin-contract-schema/a3_subject.dart:35`,
`test/zap/zap_conformance_test.dart:78` — the same semantics with
compilable dart:io).

## Suggested fix

1. Make the canonical review-snippet template catalog (source of truth
   for the bot's suggestions) emit only compilable dart:io calls — the
   temp-dir-cleanup template uses
   `addTearDown(() => dir.deleteSync(recursive: true));`.
2. Add a snippet validation gate (static deny-list scan for
   known-nonexistent APIs + a REAL analyzer-based compile check over a
   wrapper file) so un-compilable suggestions are never posted; the
   sanctioned render entry point validates before returning.
3. Audit the other Dart-code-emitting templates in the repo for similar
   non-existent API references and record the evidence.
4. Pin the `deleteSync(recursive: true)` shape with a regression test
   that also rejects the historical buggy snippet verbatim.

## Hard constraints

- Fix ONLY the review bot's snippet template/validation; do NOT change
  review posting semantics (the verdict-comment posting path —
  `pr_comment_poster.dart`, `verdict_comment.dart`, dry-run default —
  stays untouched); one PR per spec.
- The fix must:
  1. replace non-compilable API references with valid dart:io calls in
     snippet templates,
  2. add a compile-check (or snippet validation) step so un-compilable
     suggestions are never posted,
  3. audit existing templates for similar non-existent APIs,
  4. include a regression test pinning the `deleteSync(recursive: true)`
     shape.

## Goal

Every snippet emitted from the review-bot template catalog compiles
against plain dart:io + package:test, and the validation gate rejects the
historical `addTearDown(_tmp.deleteRecursively)` snippet (and anything of
its class) before a suggestion can be rendered for posting.

## Success criteria (measurable)

- **SC-1**: The temp-dir-cleanup template renders
  `addTearDown(() => tmp.deleteSync(recursive: true));` — the exact
  workaround shape from the issue — and NO template in the catalog
  contains `deleteRecursively` or any other deny-listed (verified
  non-existent) API reference.
- **SC-2**: The validation gate, run against the HISTORICAL buggy snippet
  verbatim (`addTearDown(_tmp.deleteRecursively)`), fails with an
  undefined-API finding (the analyzer reports `undefined_getter` for
  `deleteRecursively`); run against the fixed template's render, it
  passes with zero errors (REAL analyzer resolve, not just a string
  scan).
- **SC-3**: The audit of the repo's other Dart-code-emitting template
  sites (route table test builder, behavior test writer, platform
  harness writer, scratch tmpdir owner, persistence test harness)
  produces recorded evidence: every emitted API reference exists in the
  snippet's reachable surface; no other `deleteRecursively`-class
  misfires exist.
- **SC-4**: The regression suite
  `test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`
  (new) goes honest-red before the fix (the catalog/validator seam does
  not exist) and green after, pinning SC-1 + SC-2; existing
  ci_referee suites (`pr_comment_poster_test.dart`,
  `verdict_comment_test.dart`) pass unmodified — posting semantics
  unchanged.
- **SC-5**: `dart analyze` on all changed/new Dart files reports zero
  issues; `dart format .` reports zero drift.
