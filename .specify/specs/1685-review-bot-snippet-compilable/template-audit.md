# Template audit — spec 1685 (SC-3)

Audit run in this session against `fix/1685-review-bot-snippet-compilable`
(Dart 3.13.4, working tree with the fix). Scope: every Dart-code-emitting
template site under `lib/` (the snippet-generation path the review bot
pulls from), swept for the verified-non-existent API members on the
spec's deny-list (`deleteRecursively`, `deleteRecursivelySync`,
`copyRecursively`, `waitAll`).

## 1. Whole-`lib/` sweep (1268 dart files)

`deleteRecursively`-class occurrences — every hit is SANCTIONED (the
deny-list itself in the gate, and the template documentation that NAMES
the non-existent API to explain its absence):

```
lib/src/plugins/tdd/services/ci_referee/snippet_compile_check.dart —
  lines 6, 7, 92, 100, 103, 105, 107, 108, 112, 113
  (the deny-list entries + the doc comment; the gate itself)
lib/src/plugins/tdd/services/ci_referee/review_snippets.dart —
  lines 6, 7, 69, 81
  (the doc comment + the fixed template's description naming the
  non-existent API it replaces)
```

ZERO offenders. No other file under `lib/` references a deny-listed
member. (Pre-fix, the same sweep returned zero `deleteRecursively`
occurrences anywhere in the tree — the bug lived in the bot's external
template, which is why the repo-side fix is the compilable catalog + the
gate.)

## 2. Per-site emitted-API inventory (the emitter walk)

| Site | Emitted cleanup/teardown APIs | Verdict |
| ---- | ----------------------------- | ------- |
| `lib/src/plugins/route/builders/route_table_test_builder.dart` | `addTearDown(router.dispose)`, `addTearDown(encodedRouter.dispose)`, `addTearDown(tester.view.resetPhysicalSize)`, `addTearDown(tester.view.resetDevicePixelRatio)` | VALID — real members on the emitted receiver types |
| `lib/src/plugins/tdd/services/behavior_test_writer.dart` | (no teardown/delete emission) | N/A |
| `lib/src/plugins/tdd/services/platform_harness_test_writer.dart` | (no teardown/delete emission) | N/A |
| `lib/src/plugins/tdd/services/scratch_tmpdir.dart` | `dir.delete(recursive: true)` (async dispose, line ~183) | VALID |
| `lib/src/plugins/tdd/services/ci_referee/verdict_comment.dart` | (no code snippets emitted — markdown verdict table only) | N/A |
| `lib/src/testing/persistence_test_harness.dart` | `dir.delete(recursive: true)`, `dir.delete()` | VALID |

**Audit verdict: CLEAN** — the temp-dir-cleanup template was the only
snippet of the `deleteRecursively` misfire class; the fixed catalog
(`review_snippets.dart`) now emits only compilable dart:io calls and the
gate (`snippet_compile_check.dart`) rejects the whole class before any
future posting.
