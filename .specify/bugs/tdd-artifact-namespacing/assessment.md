# Bug Assessment: per-feature TDD artifact namespacing — end the test/tdd ownership collision

- **Slug**: tdd-artifact-namespacing
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/827
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Running feature #2 after feature #1 fails at gen with `ownership conflict` because both write `test/tdd/a1_test.dart`. Test/subject paths are feature-agnostic (`test/tdd/<behavior>_test.dart`), but artifacts.json/run-state/cycle-log are per-feature. Two features cannot coexist. Feature N+1 can never start while feature N's artifacts exist. With 120 sequential specs this blocks 119 of them. https://github.com/arrrrny/zuraffa/issues/827

## Symptom

Running `zfa tdd run <feature-2>` after completing `<feature-1>` fails at gen with `ownership conflict` — the test file `test/tdd/a1_test.dart` exists on disk (owned by feature-1) but feature-2's registry has no recorded ownership, so gen refuses to overwrite. Two features cannot coexist in the flat layout.

## Reproduction

1. `zfa setup --platforms=macos zik_zak_tdd`
2. `zfa tdd run 001-app-bootstrap` → complete done=21
3. `zfa tdd run 004-dependency-injection` → A1:gen fails: ownership conflict — `test/tdd/a1_test.dart` exists but 004's registry doesn't know about it

## Suspected Code Paths

- The `test/tdd/<behavior>_test.dart` and `lib/tdd/<behavior>_subject.dart` path generation — flat, no feature-slug prefix
- `artifacts.json` — per-feature registry that records ownership, but paths overlap across features
- The gen step's ownership check — correctly refuses to clobber, but the flat layout makes cross-feature files look "unowned"

## Root Cause Hypothesis

High confidence: the path layout is flat (`test/tdd/<behavior>_test.dart`) while registries are per-feature. When feature-2 runs, it checks its own artifacts.json for ownership of `a1_test.dart` — finds nothing (feature-1 owns it) — and correctly refuses to overwrite. The system answer is namespacing paths by feature slug, not weakening the guardrail.

## Proposed Remediation

**Preferred**: Namespace all generated artifacts by feature: `test/tdd/<feature-slug>/a1_test.dart`, `lib/tdd/<feature-slug>/a1_subject.dart`. Update runnable_test_name and artifacts registry to use namespaced paths. Add migration path for existing projects (auto-upgrade on first run or `zfa tdd migrate-paths`). Suite composition stays: `flutter test` discovers everything under test/ — multi-feature green suite is the norm. Acceptance composition resolves unit subjects cross-feature only via explicit dependency edges.

**Alternatives** (optional):
- Teach gen to overwrite foreign files — explicitly rejected by the issue author; breaks the ownership guardrail.

**Files likely to change**:
- Path generation code (test/tdd and lib/tdd paths)
- Artifacts registry (artifacts.json path format)
- Gen step (to use namespaced paths)
- Migration logic (auto-upgrade existing flat layouts)

**Tests to add or update**:
- Two sequential features in one project: feature-1 completes, feature-2 starts without ownership conflict
- Migration: existing flat-layout project auto-upgrades on first run
- Cross-feature acceptance composition resolves subjects via explicit edges

## Risks & Considerations

- Migration path must not break existing projects with flat layouts
- `flutter test` must still discover all tests (namespaced under `test/tdd/<feature>/`)
- Cross-feature subject resolution must use explicit dependency edges, not filename luck
- The ownership guardrail must keep working against namespaced paths
- Part of epic #848 (Wave 1 — unblock the loop)

## Open Questions

- [NEEDS CLARIFICATION: Should migration be automatic on first run, or a separate `zfa tdd migrate-paths` command?]
- [NEEDS CLARIFICATION: How does cross-feature acceptance composition resolve unit subjects? Is there an existing dependency-edge mechanism?]
