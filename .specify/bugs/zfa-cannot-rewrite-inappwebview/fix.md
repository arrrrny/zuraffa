# Bug Fix: Misfire: zfa cannot rewrite the zikzak_inappwebview WebView plugin

- **Slug**: zfa-cannot-rewrite-inappwebview
- **Fixed**: 2026-08-31
- **Assessment**: ./assessment.md
- **Change type**: documentation (assessment: "No code change needed.
  This is a documentation/expectations issue.")

## What changed

Two hand-maintained docs gained an explicit scope statement (nothing else —
no `lib/` or `bin/` file was touched, no pipeline-owned output was edited):

1. `CLI_GUIDE.md` — new "Scope: what `zfa` operates on" section after the
   intro. It states that `zfa` is a clean-architecture generator for
   **Zuraffa apps** (packages depending on `zuraffa`/`zorphy_annotation`
   with a `.zfa.json`), that `zfa` does not rewrite existing non-Zuraffa
   Flutter packages or plugins, that `zfa doctor`'s missing-dependency
   output inside such a package is the expected scope check (not a
   malfunction of the CLI), and that the options are: keep the code
   hand-written, add the Zuraffa dependencies to opt in, or file a feature
   request for a command that operates on non-Zuraffa packages.
2. `README.md` — new short "Scope" section (between "Why Zuraffa?" and
   "Installation") carrying the same contract and linking to the CLI guide
   section.

3. `test/regression/issue_477_zfa_scope_docs_test.dart` — new doc-contract
   regression test (5 tests, `regression`/`slow` tagged, following the
   `docs_command_consistency_test.dart` pattern) pinning each clause of the
   scope statement so it cannot be silently dropped.

## Why this is the minimal change

The assessment's proposed remediation is documentation/expectations only
("Files likely to change: None (documentation/expectations only)"): the
reported behavior — `zfa` refusing to operate inside a non-Zuraffa package
— is correct by design, and the reporter's real gap was that no doc ever
stated that scope. Adding the scope statement to the two user-facing docs
is the smallest change that closes that gap; a command that rewrites
non-Zuraffa plugins is a separate feature request, explicitly out of scope.

## Evidence

- RED: 5/5 tests failed pre-change with `does not contain '<scope clause>'`
  matcher misses (see `tdd/cycle-log.md`).
- GREEN: `dart test --preset=regression test/regression/issue_477_zfa_scope_docs_test.dart`
  → 5/5 pass; neighbor `docs_command_consistency_test.dart` → 8/8 pass.
- `dart analyze` → No issues found! `dart format .` → clean.
- Chunked fast suite: no new failures (see `tdd/verification.md`).
