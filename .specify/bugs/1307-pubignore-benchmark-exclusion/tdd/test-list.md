# Test List — 1307-pubignore-benchmark-exclusion

Derived by `speckit.tdd.plan` (LLM-guided fallback: zfa engine ZFA_MISSING —
no `.zfa.json` at package root) from `spec.md`. Each behavior traces to an
acceptance criterion. Every behavior must be proven RED before its fix, with
evidence in `tdd/cycle-log.md`.

| Behavior | Test | Trace | Status |
|----------|------|-------|--------|
| B1 — publish-time export guard: every `export`/`part` target under published `lib/**` resolves inside the would-publish file set | `test/pubignore_export_guard_test.dart` → `export guard: every export/part directive target under lib/ exists in the would-publish set` | AC-1 | PENDING |
| B2 — regression wall on gitignore semantics: top-level `benchmark/` excluded, `lib/src/core/benchmark/` sources included | `test/pubignore_export_guard_test.dart` → `would-publish set: includes lib/src/core/benchmark sources and excludes the top-level benchmark harness` | AC-2 | PENDING |
| B3 — hazard-class wall: no unanchored trailing-slash-only directory patterns in `.pubignore` | `test/pubignore_export_guard_test.dart` → `.pubignore hygiene: directory patterns are root-anchored (no any-depth hazards)` | AC-3 | PENDING |

Notes:

- Outer loop = AC-1..AC-4 above; the unit behaviors are B1–B3.
- AC-4 (scope constraint) is verified by `git diff --stat` at fix time, not by
  a test behavior.
- The guard test reimplements pub's gitignore semantics for the subset this
  `.pubignore` uses (documented in-file); `dart pub publish --dry-run` stays
  the authoritative publish gate and is exercised in fix verification.
