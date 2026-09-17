# TDD test list — Issue #1685 review bot snippet uses non-existent `Directory.deleteRecursively`

Spec: `.specify/specs/1685-review-bot-snippet-compilable/spec.md`

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1685-G1a | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | `tempDirCleanup` renders the exact issue-workaround shape — `Directory.systemTemp.createTempSync` + `addTearDown(() => tmp.deleteSync(recursive: true))` — and contains no `deleteRecursively` | issue #1685 (fix criterion 1, SC-1) | RED → GREEN |
| U-1685-G1b | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | NO template in the catalog references any deny-listed (verified non-existent) API member — the catalog-wide invariant | fix criterion 3 (audit), SC-1 | RED → GREEN |
| U-1685-G2a | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | static deny-list scan rejects the HISTORICAL snippet verbatim (`addTearDown(_tmp.deleteRecursively)`, inline comment id 4023967373) with `non_existent_api` + the compilable replacement | fix criterion 2 (compile-check), SC-2 | RED → GREEN |
| U-1685-G2b | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | REAL analyzer compile check rejects the historical snippet — `undefined_getter`, the issue's exact diagnostic class | fix criterion 2 (compile-check), SC-2 | RED → GREEN |
| U-1685-G2c | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | the FIXED render passes the REAL analyzer compile check with zero errors (in-process resolve over a wrapper file in the gitignored `build/` scratch) | fix criterion 1, SC-2 | RED → GREEN |
| U-1685-G2d | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | `validate()` combines both layers — a scan hit short-circuits before the analyzer runs | gate contract, SC-2 | RED → GREEN |
| U-1685-G3a | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | `postableSnippet` — the ONLY sanctioned posting path — returns compiled-verified code | fix criterion 2 (never posted un-verified), SC-2 | RED → GREEN |
| U-1685-G3b | test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart | unit | unknown template ids throw [ArgumentError] on both `render` and `postableSnippet` — no ad-hoc template fallback | gate soundness | RED → GREEN |

Guard pins (pre-existing, unchanged and green against the fix — posting
semantics untouched):

| id | suite | description |
| -- | ----- | ----------- |
| U12/U13 (spec 070) | test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart | the PR comment poster — URL/token/500-fallback/dry-run contract, unmodified |
| verdict renderer | test/plugins/tdd/services/ci_referee/verdict_comment_test.dart | the verdict comment markdown contract, unmodified |

## Red evidence (pre-fix, this session)

Both recorded verbatim in
`.specify/specs/1685-review-bot-snippet-compilable/red-evidence.md`:

1. **The bug's red** — the bot's snippet applied VERBATIM inside the
   standard wrapper:
   `dart analyze build/1685_repro_snippet_test.dart` →
   `error - The getter 'deleteRecursively' isn't defined for the type 'Directory'. - undefined_getter`
   (the issue's exact error, reproduced in this session on Dart 3.13.4).
2. **The new seam's honest red** — the regression suite pre-implementation:
   `dart test test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`
   → load failure (`No such file or directory` for
   `review_snippets.dart` / `snippet_compile_check.dart`) — the
   compile-error red proving the seam (catalog + validation gate) did not
   exist.

## Green evidence (post-fix, this session)

`dart test test/plugins/tdd/commands/spec_1685_review_bot_snippet_compilable_test.dart`
→ `00:11 +8: All tests passed!` (8/8 — U-1685-G1a/G1b, G2a/G2b/G2c/G2d,
G3a/G3b).
