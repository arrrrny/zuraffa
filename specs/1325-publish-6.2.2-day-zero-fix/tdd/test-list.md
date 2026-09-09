# TDD Test List — Spec 1325 publish 6.2.2 day-zero fix (release gates)

One behavior per line, traced to the FRs / success criteria in spec.md.
This is a RELEASE task (hard constraint: no source changes), so the
behaviors are exercised at the artifact level: the subject under test is
the published artifact fleet, and the "test files" are the gate commands
+ the scratch consumer + the drift-guard check. Red = the gate FAILS on
the broken artifact / mutated input; green = it PASSES on the live 6.2.2
fleet. The master publish-set export test
(`test/core/publish_set_exports_test.dart`, merged via the #1313 work)
is the in-repo behavioral pin and runs as B4.

## Behaviors

| # | Behavior | Trace | Gate / subject |
|---|--------|--------|-----------|
| B1 | `grep '^version:' pubspec.yaml` on this branch (fork of master) prints `version: 6.2.2` — the bump is present and untouched | FR-1 / SC-1 | `grep '^version:' pubspec.yaml` |
| B2 | pub.dev reports `latest.version == 6.2.2` (published 2026-09-08) — the artifact fleet moved with the merge | FR-2 / SC-2 | `curl -s https://pub.dev/api/packages/zuraffa \| jq -r .latest.version` |
| B3 | `dart pub publish --dry-run` on the master tree exits 0, prints "Package validation passed" with 0 errors, and the upload set includes `lib/src/core/benchmark/benchmark_contract.dart` | FR-3 / SC-3 | `dart pub publish --dry-run` |
| B4 | The publish-set export guard (walks `lib/zuraffa.dart`'s export/part graph against `.pubignore` semantics) passes on this branch — the #1307 regression class stays dead in-repo | FR-3, FR-4 / SC-3, SC-4 | `dart test test/core/publish_set_exports_test.dart` |
| B5 | The published 6.2.2 tarball contains `lib/src/core/benchmark/benchmark_contract.dart` and the full `lib/src/core/benchmark/` + `lib/src/plugins/benchmark/` sets, AND a fresh scratch consumer (`dart pub cache add zuraffa --version 6.2.2`, import `package:zuraffa/zuraffa.dart`) compiles via `dart compile exe` and runs, touching a benchmark-contract-reachable symbol; the SAME consumer pinned to 6.2.1 (the mutant) FAILS to resolve/compile with the issue's missing-file error naming `benchmark_contract.dart` — red/green at the artifact level | FR-4, FR-5, FR-6 / SC-4, SC-5, SC-6 | scratch consumer `/home/z/my-project/scratch/dayzero/{pubspec.yaml,bin/dayzero.dart}` |
| B6 | The publish-drift guard's check FAILS (exit 1) when `pubspec.yaml` version is deliberately mismatched against pub.dev's latest, and PASSES (exit 0) against the live state — the guard demonstrably detects the #1325 gap class (fix merged, fleet not moved) | FR-7 / SC-7 | `.github/workflows/publish_drift.yml` check step, self-tested locally |
| B7 | The branch diff touches NO source: `git diff --name-only master -- lib/ bin/ tool/` is empty | FR-8 / SC-8 | `git diff --name-only master -- lib/ bin/ tool/` |

## Red protocol

Targeted gates only — never the full suite (kernel-cache disk ceiling).
Red is produced where a broken subject exists to run against:

1. B5-red: scratch consumer pinned to `zuraffa: 6.2.1` (the published
   broken version IS the mutant — the #1307 bug shipped in it). Expected
   failure shape: pub resolution succeeds (6.2.1 exists) then
   compilation fails: `Error: Error when reading
   '.../lib/src/core/benchmark/benchmark_contract.dart': No such file or
   directory`.
2. B6-red: run the guard's check with `EXPECTED_VERSION=0.0.0-mutant`
   against the live pub.dev latest → exit 1 with the remedy message.

Everything else is a pass-gate on the live fleet (recorded verbatim in
tdd/verification.md, exit codes included).
