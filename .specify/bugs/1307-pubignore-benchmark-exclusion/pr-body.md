## Summary

`.pubignore` `benchmark/` matched directories at any depth due to missing root
anchor (pub follows gitignore semantics), excluding `lib/src/core/benchmark/`
and `lib/src/plugins/benchmark/` from the published tarball while
`lib/zuraffa.dart:294-301` still exported `benchmark_contract.dart` et al.
Every day-zero scaffold of `zuraffa: ^6.2.0`/`^6.2.1` failed to compile.

## Root cause

A pattern with a trailing slash and no leading/middle slash (`benchmark/`)
matches directories at ANY depth, so the top-level dev harness exclusion also
excluded same-named library source dirs from the tarball.

## Remediation

1. Anchored the 8 dev-only directory patterns to the package root:
   `benchmark/`, `benchmarks/`, `coverage/`, `.worktrees/`, `specs/`,
   `contracts/`, `apps/`, `build/` → `/…/`. (In-file comment records why.)
   `lib/tdd/`, `test/fixtures/`, `example/pubspec.lock`,
   `examples/*/pubspec.lock`, `.zuraffa/plans/` were already root-anchored;
   `.env` is intentionally any-depth — kept as-is.
2. Added the publish-time export guard test (`test/pubignore_export_guard_test.dart`):
   rebuilds the would-publish file set from `.pubignore` with gitignore
   semantics and asserts every `export`/`part` directive target in published
   `lib/**` resolves inside it — plus a regression wall for the exact 1307
   semantics and a hygiene wall against future unanchored directory patterns.
3. Scope honored: only `.pubignore` + the guard test; no changes to
   `lib/zuraffa.dart` exports or the publish process.

## Verification

- TDD red → green: `dart test test/pubignore_export_guard_test.dart`
  RED 0/3 pre-fix (exactly the 8 exported benchmark targets missing from the
  publish set, all "on disk: yes") → GREEN 3/3 post-fix.
- `dart pub publish --dry-run`: tarball tree now contains
  `lib/src/core/benchmark/` (benchmark_contract.dart, benchmark_registry.dart,
  benchmark_result.dart, benchmark_runner.dart, isolate_benchmark_runner.dart)
  and `lib/src/plugins/benchmark/`; 4 warnings + 1 hint are pre-existing
  layout advisories unrelated to this bug.
- `dart analyze test/pubignore_export_guard_test.dart` → No issues found;
  `dart format` clean.
- Deliberate mutant sampling: reintroducing unanchored `benchmark/` turns the
  suite RED (mutant killed), restoring it is GREEN with a byte-identical diff.
- Full TDD audit: `.specify/bugs/1307-pubignore-benchmark-exclusion/tdd/verification.md`
  (verdict PASS), cycle evidence in `tdd/cycle-log.md`.
- Assessment: `.specify/bugs/1307-pubignore-benchmark-exclusion/assessment.md`

Closes #1307
