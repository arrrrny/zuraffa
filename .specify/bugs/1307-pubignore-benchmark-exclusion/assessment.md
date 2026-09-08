# Bug Assessment: Published package 6.2.0/6.2.1 broken by unanchored .pubignore pattern

- **Slug**: 1307-pubignore-benchmark-exclusion
- **Created**: 2026-09-08T12:30:00Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1307
- **Verdict**: valid — root cause confirmed against the working tree and pub's gitignore semantics; reproduction is deterministic
- **Severity**: high

## Report (verbatim or summarized)

Issue #1307 (authored by arrrrrny, no labels, no comments as of fetch). Every
consumer of `zuraffa: ^6.2.0`/`^6.2.1` fails to compile at day zero: the
published tarball is missing `lib/src/core/benchmark/` while
`lib/zuraffa.dart:294-301` still exports 8 files from it
(`benchmark_contract.dart`, `benchmark_result.dart`, `benchmark_registry.dart`,
`benchmark_runner.dart`, `metric_collector.dart`, `baseline_store.dart`,
`standard_metrics.dart`, `isolate_benchmark_runner.dart`). Verified on the
pub.dev tarballs for both 6.2.0 and 6.2.1.

## Symptom

Consumer compile fails on the missing exported file:

```
zuraffa-6.2.1/lib/zuraffa.dart:294:1: Error: Error when reading
'.../zuraffa-6.2.1/lib/src/core/benchmark/benchmark_contract.dart':
No such file or directory
```

## Reproduction

```bash
zfa setup todo_planner --platforms=ios,macos
cd todo_planner && flutter pub get && flutter test
```

→ compile error above on any scaffold that resolves the published package.
Automated equivalent used in this fix (no Flutter SDK needed): a publish-time
export guard test that rebuilds the would-publish file set from `.pubignore`
and asserts every `export`/`part` target under `lib/` is present.

## Confirmed code paths (working-tree evidence)

- `.pubignore` line 21: `benchmark/` — unanchored (trailing slash, no leading
  slash, no middle slash) → matches directories named `benchmark` at ANY depth.
- `find lib bin tool -type d -name benchmark` (excluding the top-level one)
  hits:
  - `lib/src/core/benchmark/` — exported by `lib/zuraffa.dart:294-301` → THE BUG.
  - `lib/src/plugins/benchmark/` — not directly exported by `lib/zuraffa.dart`,
    but still library source wrongly dropped from the tarball by the same
    unanchored pattern.
- Sibling audit of every other pattern in `.pubignore`:
  - `lib/tdd/`, `test/fixtures/`, `example/pubspec.lock`,
    `examples/*/pubspec.lock`, `.zuraffa/plans/` — contain a middle slash →
    already root-anchored → safe.
  - `coverage/`, `.worktrees/`, `specs/`, `contracts/`, `apps/`, `build/`,
    `benchmarks/` — same any-depth hazard as `benchmark/` (no hits under
    `lib/`, `bin/`, `tool/` today, so they are latent, not live, hazards).
  - `.env` — no slash at all → matches `.env` files at any depth; INTENTIONAL
    (environment secrets must be excluded wherever they appear). Keep.

## Root Cause (confirmed hypothesis)

Pub's ignore rules follow gitignore semantics: a pattern containing a slash
only in trailing position (`benchmark/`) matches directories at any depth
below the ignore file. `.pubignore` therefore excluded the intended top-level
dev benchmark harness **and** `lib/src/core/benchmark/` +
`lib/src/plugins/benchmark/`. The published export set then pointed at files
absent from the tarball.

## Proposed Remediation

1. Anchor the dev-only directory patterns to the package root in `.pubignore`:
   `benchmark/` → `/benchmark/`, and audit-anchor the sibling latent hazards
   `benchmarks/`, `coverage/`, `.worktrees/`, `specs/`, `contracts/`, `apps/`,
   `build/` the same way. Keep `.env`, `lib/tdd/`, `test/fixtures/`,
   `example/pubspec.lock`, `examples/*/pubspec.lock`, `.zuraffa/plans/`
   as-is (already anchored or intentionally any-depth).
2. Add a publish-time export guard test
   (`test/pubignore_export_guard_test.dart`) that:
   - rebuilds the would-publish file set by applying `.pubignore` with
     gitignore semantics (any-depth vs root-anchored rules),
   - parses every `export`/`part` directive in every published `lib/**/*.dart`,
   - asserts each resolved target exists in the would-publish set,
   - pins the gitignore-semantics regression directly (top-level `benchmark/`
     excluded; `lib/src/core/benchmark/` sources included).
   `dart pub publish --dry-run` remains the authoritative publish gate and is
   run as part of fix verification.
3. Republish 6.2.2 is maintainer-side and OUT OF SCOPE for this PR (see hard
   constraints below).

### Hard constraints (from the bug record)

- Fix ONLY `.pubignore` and add the publish-time export guard test.
- Do NOT change `lib/zuraffa.dart` export lines.
- Do NOT change the pub.dev publish process.
- One PR per bug.

## Files likely to change

| File | Change |
|------|--------|
| `.pubignore` | anchor 8 directory patterns to root |
| `test/pubignore_export_guard_test.dart` | new guard test (TDD red first) |
| `.specify/bugs/1307-pubignore-benchmark-exclusion/*` | bug workflow records |

## Tests to add or update

- `test/pubignore_export_guard_test.dart` — new. Must be proven RED against
  the current unanchored `.pubignore` (exported `lib/src/core/benchmark/*.dart`
  absent from the would-publish set), then GREEN after anchoring.

## Risks & Considerations

- The guard test reimplements the gitignore-semantics subset pub applies
  (any-depth vs root-anchored, trailing-slash directory-only). It is scoped to
  the semantics this `.pubignore` uses; `dart pub publish --dry-run` remains
  the authoritative gate and is run during verification.
- Anchoring `build/`, `coverage/`, etc. changes no live behavior today (no
  same-named dirs under `lib/`, `bin/`, `tool/`), so the publish set delta is
  exactly: `lib/src/core/benchmark/*` and `lib/src/plugins/benchmark/*` return
  to the tarball.
- Republishing 6.2.2 is a maintainer action after merge; the PR fixes the
  ignore so the next publish is correct.

## Open Questions

- None.
