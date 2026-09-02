# Bug Issue: [TDD-120] Per-feature TDD artifact namespacing — end the test/tdd ownership collision (#801 system fix)

- **Slug**: tdd-artifact-namespacing
- **Fetched**: 2026-09-02
- **Issue**: 827
- **URL**: https://github.com/arrrrny/zuraffa/issues/827
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Goal is 120 specs in ONE repo, sequentially, 100% TDD. Today running feature #2 after feature #1 fails at gen with `ownership conflict` because both write `test/tdd/a1_test.dart`.

Test/subject paths are feature-agnostic (`test/tdd/<behavior>_test.dart`), but artifacts.json/run-state/cycle-log are per-feature. Two features cannot coexist.

Required (system fix):
1. Namespace all generated artifacts by feature: `test/tdd/<feature-slug>/a1_test.dart`, `lib/tdd/<feature-slug>/a1_subject.dart`.
2. The runnable_test_name and artifacts registry use the namespaced paths.
3. Migration path for existing projects (`zfa tdd migrate-paths` or versioned layout with auto-upgrade on first run).
4. Suite composition: `flutter test` keeps discovering everything under test/ — so multi-feature green suite is the norm, and refactor preflight sees the WHOLE suite (correct gate, stays).
5. Acceptance composition (compose) must resolve unit subjects cross-feature only via explicit dependency edges, not filename luck.

No gate is eased. The ownership guardrail itself is GOOD — it must keep working, just against namespaced paths.

## Comments

**arrrrny** (2026-09-02): "Part of epic #848 (Wave 1 — unblock the loop). Closing this without the epic context loses the dependency ordering."

**arrrrny** (2026-09-02): "Fresh evidence on current master (post-VISION commit 6921c730): Exact repro on a clean project — (1) `zfa setup --platforms=macos zik_zak_tdd`, (2) spec 001 → `zfa tdd run 001-app-bootstrap` → complete done=21, (3) spec 004 → `zfa tdd run 004-dependency-injection` → A1:gen fails with ownership conflict — test file `test/tdd/a1_test.dart` exists on disk but registry has no recorded ownership (004's registry doesn't know about 001's file). The guardrail behaved correctly (refused to clobber). The defect is the flat path layout: one namespace, per-feature registries. The namespacing fix is the system answer; do NOT fix this by teaching gen to overwrite foreign files. Corpus impact: feature N+1 can never start while feature N's artifacts exist. With 120 sequential specs this blocks 119 of them."
