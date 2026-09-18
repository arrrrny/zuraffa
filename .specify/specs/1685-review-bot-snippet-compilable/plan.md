# Plan: 1685-review-bot-snippet-compilable

- **Spec ID**: 1685-review-bot-snippet-compilable
- **Created**: 2026-09-18

## Technical Context

- **The pipeline surface**: `zuraffa-review[bot]` is an external GitHub
  App; the repo-side artifacts of its snippet generation are the
  first-party template catalog and the validation gate that stands
  between "template rendered" and "suggestion published". The in-repo
  comment-posting machinery lives under
  `lib/src/plugins/tdd/services/ci_referee/` (spec 070) — the natural
  home for the snippet source of truth and its gate, beside
  `pr_comment_poster.dart`, WITHOUT touching it.
- **The bug**: the temp-dir-cleanup template emitted
  `addTearDown(_tmp.deleteRecursively)`. `deleteRecursively` exists
  NOWHERE: not on `dart:io`'s `Directory` (which offers
  `delete({recursive})` / `deleteSync({recursive})`), not in
  flutter_test / test_api 0.7.12 extensions, not in any package imported
  by the consumer test file. Analyzer verdict at the misfire site:
  `undefined_getter`.
- **The correct shape is already canonical in this repo**:
  `addTearDown(() => dir.deleteSync(recursive: true));` —
  `lib/tdd/073-slice-isolation/u1_subject.dart:19`,
  `lib/tdd/078-skin-contract-schema/a3_subject.dart:35`,
  `test/zap/zap_conformance_test.dart:78` (and the async form
  `dir.delete(recursive: true)` in `scratch_tmpdir.dart:183` and
  `persistence_test_harness.dart:151`). The fix aligns the template with
  the codebase's own proven idiom.
- **Validation design (two layers, one gate)**:
  1. **Static deny-list scan** (`scan`, pure string, no I/O): a
     curated, VERIFIED list of member names that do not exist in the
     snippet's reachable surface — `deleteRecursively` /
     `deleteRecursivelySync` (the #1685 class: dart:io cleanup is
     `delete({recursive})`/`deleteSync({recursive})`), plus
     `Directory.copyRecursively` and `Future.waitAll` (common
     hallucinations of the same kind). Any hit fails immediately with
     the reason and the valid replacement.
  2. **REAL analyzer compile check** (`compileCheck`, authoritative):
     writes the snippet into a wrapper file inside a scratch dir under
     the gitignored `build/` path (inside the package, so this package's
     own package config resolves `dart:io` + `package:test` — the
     wrapper's import set), resolves it IN-PROCESS with
     `package:analyzer` (already a direct dependency, ^14.4.0), and
     fails on any ERROR-severity diagnostic. This is exactly the
     `undefined_getter` class of failure the issue reports — a
     non-existent member cannot resolve in any context.
- **The gate**: the sanctioned render entry point
  (`ReviewSnippets.postableSnippet`) validates (scan + compile) before
  returning; an invalid template cannot produce a postable snippet.
  Posting semantics (dry-run default, verdict renderer, poster
  transport) are NOT touched.

## Remediation

TWO new files, ONE regression test — nothing existing modified:

- `lib/src/plugins/tdd/services/ci_referee/review_snippets.dart`:
  `ReviewSnippetTemplate` (id, title, description, code),
  `ReviewSnippets` catalog with the FIXED temp-dir-cleanup template
  (`tempDirCleanup` — `Directory.systemTemp.createTempSync` +
  `addTearDown(() => tmp.deleteSync(recursive: true));`), `render(id)`
  for plain instantiation, `postableSnippet(id, {check})` as the
  validated gate.
- `lib/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart`:
  `SnippetCompileCheck` with the verified deny-list (`scan`) and the
  analyzer-based compile pass (`compileCheck`) over a wrapper file in
  `build/` (gitignored — the #1664 scratch pattern), plus
  `validate` (both layers combined) and `SnippetValidationResult` /
  `SnippetValidationIssue` (severity, message, code).
- `test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`:
  the spec-pinned regression suite (U-1685-G1/G2/G3).

`pr_comment_poster.dart`, `verdict_comment.dart`, `golden_workflow.dart`
and every other existing file stay untouched (one PR per spec).

## Verification plan

- **Reproduction first (red evidence, pre-fix)**: a scratch file
  containing the bot's snippet VERBATIM
  (`addTearDown(_tmp.deleteRecursively)`) inside the standard wrapper →
  `dart analyze` reports `The getter 'deleteRecursively' isn't defined
  for the type 'Directory'` — `undefined_getter`, the issue's exact
  error, reproduced in this session.
- **Honest red for the new seam**: the regression suite references the
  new catalog/validator seam → pre-implementation the file fails to
  LOAD (compile-error red — the same honest-red class as #1664's new
  seam), post-implementation green.
- **Fast-tier regression tests** (no pub get, no build, in-process
  analyzer):
  U-1685-G1 pins SC-1 (fixed shape present, no deny-listed API in any
  template), U-1685-G2 pins SC-2 (historical snippet rejected by BOTH
  the static scan and the REAL analyzer check; fixed render passes the
  analyzer with zero errors), U-1685-G3 pins the gate (invalid template
  id throws; gate returns compiled-verified code).
- **Template audit** (SC-3): scan every Dart-code-emitting template site
  in `lib/` (route table test builder, behavior test writer, platform
  harness writer, scratch tmpdir, persistence harness, verdict comment
  renderer) for the deny-list members + `deleteRecursively` class
  strings; record per-site evidence in the spec's verification notes.
- **Gates**: `dart analyze` on changed/new files (zero issues),
  `dart test` on the new suite + the existing ci_referee suites
  (unmodified, green), `dart format .` (zero drift).

## Verification run context (provenance for tdd/verification.md)

`tdd/test-list.md` and `tdd/verification.md` are scoped to THIS spec
(the root `tdd/` artifacts are overwritten per spec, per the #1664 /
#1655 / #1636 precedent). The recorded runs are the ones executed in
THIS session on `fix/1685-review-bot-snippet-compilable`: the verbatim
reproduction (red), the regression suite red→green, the template audit
scan, the ci_referee guard suites, and the analyze/format gates.
