---
feature: slice-cut-pubspec-static-template (bug #1304)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: fix/1304-slice-cut-pubspec-static-template (session run)
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: unmeasured # no mutation tool wired for this path; behavior-level deliberate-mutant equivalent = the pre-fix binary (git stash) used as the red run
mutants_survived: 0 # pre-fix binary survives zero of the new assertions (all 3 new tests red against it)
suite: chunked fast suite 4710 passed / 2 failed (both proven pre-existing on pristine base) across 99 chunks; pubspec_filter_test 7/7; dart analyze changed files clean; e2e cut→verify self-containment RED→GREEN; sandbox standalone pub get + analyze clean
---

# TDD Verification: slice cut — derive sandbox pubspec deps from the copied closure (bug #1304)

**Verdict: PASS.** The pubspec writer now declares every package the copied
closure imports (host constraint verbatim; transitive-only imports pinned from
the host's `pubspec.lock`, falling back to `any` + inline warning), the new
tests were written first and went red against the pre-fix binary for exactly
the bug's reason, and `slice verify --json` self-containment passes on a real
feature-shaped host with a working standalone sandbox. The two suite failures
are unrelated pre-existing failures proven on the base commit.

## Scope resolution (Phase 0)

This work is a **bug**, not a spec feature: no `SPECIFY_FEATURE_DIRECTORY` /
`.specify/feature.json` applies. Per the bug extension's convention
("per-bug reports stored under `.specify/bugs/<slug>/`"), `FEATURE_DIR`
resolves to `.specify/bugs/slice-cut-pubspec-static-template/` and this report
is written to `FEATURE_DIR/tdd/verification.md`. The committed bug records
were absent from the clone; `issue.md`/`assessment.md` were reconstructed
verbatim from GitHub issue #1304 (fetched via the API in this session) plus
the task assessment, before the fix was applied. Spec Kit CLI 1.0.5.dev0
installed; `specify check` OK; `✓ TDD Extension (v1.1.2)` confirmed present
and enabled (init/re-add deliberately skipped — the runbook forbids clobbering
the existing `.specify/templates` + `.specify/scripts` customizations).

## Test-first evidence (RED recorded before implementation)

The three new tests were added to
`test/plugins/slice/exporter/pubspec_filter_test.dart` and run BEFORE the
`lib/` change landed (kernel cache cleaned first per the cloud-agent
protocol). Red is an assertion red for the bug's exact reason — the emitted
sandbox pubspec declares only `['flutter']`:

| Suite | RED observation |
|---|---|
| U1304a (transitive-only import declared from host lock) | `Expected: contains 'zuraffa'` / `Actual: EfficientLengthMappedIterable<dynamic, dynamic>:['flutter']` — the imported-but-undeclared package is silently dropped (the bug) |
| U1304b (`any` + warning fallback) | same drop at the `contains 'zuraffa'` assertion |
| U1304a (determinism + sorted derived entries) | `Expected: '^6.2.0'` / `Actual: <null>` |
| Pre-existing U54/U55/U56 (regression guards) | 4 passed — the fix's blast radius is pinned by the spec-043 contract tests |

Result line: `00:00 +4 -3: Some tests failed.` (red for the RIGHT reason).

An end-to-end red was also captured on a faithful Flutter-shaped host
(pure-Dart first, then the final Flutter host with `flutter: sdk: flutter`,
get_it + equatable declared, `collection` transitive-only, data-layer
repository importing `package:collection/collection.dart`):

```
Error: slice-verify: feature=login_feature self-containment=fail mock-certification=pass suite=fail outcome=failed
  FAILED check "selfContainment":
    - lib/src/data/repositories/mock_login_repository.dart:5: "package:collection/collection.dart" — package "collection" is not declared in pubspec.yaml
  FAILED check "suiteState":
--> fix: resolve every named offender, then re-run `zfa slice verify --json login_feature` (issue #961).
```

Exit 1 with machine-checkable verdict JSON and the fix line — the same honest
gate signature as the issue's repro, against the pre-fix binary (changes
stashed).

## Green evidence (after implementation)

Per-suite counts as observed (fast tier only; `--exclude-tags flutter` chunks
via the chunked runner; flutter-tagged file run directly — it needs no Flutter
SDK):

| Suite | Result |
|---|---|
| test/plugins/slice/exporter/pubspec_filter_test.dart (direct `dart test`) | **7 passed, 0 failed** (4 pre-existing + 3 new) |
| test/plugins/slice chunk (fast, non-flutter; cut path regression guards) | passed |
| Chunked fast suite, `tools/run_tests_chunked.sh` (99 chunks executed) | **4710 passed / 2 failed** (both proven pre-existing below), 5 chunks SKIP (slow-tier-only), 92 chunks green |
| `dart analyze lib/src/plugins/slice/exporter/pubspec_filter.dart test/plugins/slice/exporter/pubspec_filter_test.dart` | No issues found |
| `dart format` on changed files | clean (test file reformatted by the tool; zero formatting diffs remain) |
| E2E `zfa slice cut login_feature --entry login --depth full` → `slice verify --json` (final Flutter-shaped host, fix applied) | cut exit 0 (9 project files); verdict JSON: `selfContainment=true`, `mockCertification=true`; sandbox pubspec carries `collection: ^1.19.1` with the `# derived (issue #1304)` provenance comment |
| Sandbox standalone proof | `flutter pub get` exit 0 (the derived constraint resolves for real); `dart analyze` → "No issues found!" |

Emission determinism is asserted by the new test (two runs byte-identical,
derived entries sorted).

## Unrelated pre-existing failures (flagged, proven, not fixed)

Both reproduce on the pristine base with this branch's changes stashed
(exit 1, identical `[E]` test names), and neither touches the slice pubspec
writer:

| Failure | Base evidence |
|---|---|
| test/cli/writers/tdd/app_module_writer_test.dart › BootstrapRoutingIndexWriter emits an empty getAllRoutes barrel | `BASE app_module_writer EXIT=1`, `00:00 +8 -1: ... [E]` |
| test/plugins/state/state_snapshot_test.dart › SC-3: the fixture matrix is byte-identical to the committed goldens | `BASE state_snapshot EXIT=1`, `00:00 +0 -1: ... [E]` |

## Acceptance-criteria coverage (hard constraints from the assessment)

| Criterion | Proof |
|---|---|
| (1) Scan copied files for `package:` imports | Unchanged scan kept in `PubspecFilter.filter()` (the closure scan was NOT touched); U54/U56 regression tests still green |
| (2) Declare each imported package with the host version constraint (or `any` + warning) | U1304a: host-declared → verbatim host constraint; transitive-only → `^<host lock version>`; U1304b: no lock entry → `any` + inline `# WARNING (issue #1304)` comment; derived entries sorted, byte-identical emission |
| (3) Not break `--depth feature` / `--depth full` behavior | E2E cut ran at `--depth full` (9 project files, exit 0); depth semantics live in the walker/closure scan, untouched; slice fast tests + chunked suite green |
| (4) `slice verify --json` self-containment passes on a real feature | Final host: `selfContainment=true` in verify-verdict.json; sandbox standalone `flutter pub get` + `dart analyze` clean |

Verify gate semantics unchanged: `ImportVerifier`/`SliceVerifier` untouched
(diff touches only the pubspec writer + its tests + the reconstructed bug
records). `suiteState` remains honestly `fail` for sandboxes without a
`test/` directory — observed identically pre- and post-fix and documented as
the verifier's designed behavior ("never as passing"); it is not a regression
and not part of bug #1304.
