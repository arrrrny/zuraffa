# Verification 1325 — publish 6.2.2 day-zero fix (release gates on the live artifact fleet)

GitHub issue: arrrrny/zuraffa#1325
Branch: `feat/1325-publish-6.2.2-day-zero-fix`
Toolchain: Dart 3.13.3 stable (SDK constraint `^3.11.0`).

## Test-first evidence (red → green)

This is a RELEASE task (no source changes, per the issue's hard
constraint), so the red/green pair lives at the artifact level: the
subject under test is the PUBLISHED artifact fleet, the "mutant" is the
published broken 6.2.1 (the #1307 bug shipped inside it), and the gate is
a scratch consumer compiling against `package:zuraffa/zuraffa.dart`.

Scratch consumer (`/home/z/my-project/scratch/dayzero/`, outside the
repo, deleted after evidence was recorded):

```dart
import 'package:zuraffa/zuraffa.dart';

void main() {
  // ThresholdConfig lives in lib/src/core/benchmark/benchmark_contract.dart
  // (exported by lib/zuraffa.dart). If that file is missing from the
  // published tarball, this app must fail to compile — the #1325
  // day-zero failure shape.
  final threshold = ThresholdConfig(
    metric: 'latency_p99',
    operator: ThresholdOperator.lte,
    value: 200,
  );
  print('day-zero OK: ${threshold.metric} ${threshold.operator.name} ${threshold.value}');
}
```

### RED (artifact mutant: published zuraffa 6.2.1)

Command:
```
cd /home/z/my-project/scratch/dayzero   # pubspec pins zuraffa: 6.2.1
dart pub get                            # exit 0 — the broken version IS resolvable
dart compile exe bin/dayzero.dart -o /tmp/dayzero_red
```
Result: compile exit **254**, with the issue's repro shape verbatim:

```
../../../.pub-cache/hosted/pub.dev/zuraffa-6.2.1/lib/zuraffa.dart:294:1: Error: Error when reading '../../../.pub-cache/hosted/pub.dev/zuraffa-6.2.1/lib/src/core/benchmark/benchmark_contract.dart': No such file or directory
export 'src/core/benchmark/benchmark_contract.dart';
../../../.pub-cache/hosted/pub.dev/zuraffa-6.2.1/lib/src/cli/plugin_loader.dart:36:8: Error: Error when reading '../../../.pub-cache/hosted/pub.dev/zuraffa-6.2.1/lib/src/plugins/benchmark/benchmark_plugin.dart': No such file or directory
../../../.pub-cache/hosted/pub.dev/zuraffa-6.2.1/lib/src/cli/plugin_loader.dart:199:7: Error: The method 'BenchmarkPlugin' isn't defined for the type 'PluginLoader'.
```

The gate demonstrably kills the broken artifact (test-list B5-red,
FR-6/SC-6).

### GREEN (live artifact: published zuraffa 6.2.2)

Commands (fresh consumer + the acceptance criterion's cache add):
```
dart pub cache add zuraffa --version 6.2.2   # OK — 6.2.2 in fresh pub cache
# pubspec dependency flipped 6.2.1 → 6.2.2, then:
dart pub get          # "zuraffa 6.2.2 (was 6.2.1)"
dart compile exe bin/dayzero.dart -o /tmp/dayzero_green
/tmp/dayzero_green
```
Result: compile exit **0**; run prints `day-zero OK: latency_p99 lte 200`
and exits 0 — the benchmark contract export graph resolves, compiles
(AOT), and executes end-to-end (test-list B5-green, FR-5/SC-5).

### Guard self-test red → green (drift guard, test-list B6)

The workflow's check block was executed verbatim (extracted from
`.github/workflows/publish_drift.yml`) in a scratch dir:

- RED: `pubspec.yaml` pinned to `version: 0.0.0-mutant` → exit **1** with
  `::error::PUBLISH DRIFT: pubspec.yaml says 0.0.0-mutant but pub.dev
  latest is 6.2.2. A merged change is not live for consumers. Remedy:
  bump the version and run 'dart pub publish' (see PUBLISH.md), then
  re-run this workflow.`
- GREEN: run from the repo root (`version: 6.2.2`) → exit **0**, prints
  `OK: repo version 6.2.2 matches pub.dev latest — no drift.`

## Release-gate evidence (pass-gates on the live fleet)

- **SC-1 (B1)**: `grep '^version:' pubspec.yaml` → `version: 6.2.2`
  (bump already merged on master via `956867fa chore: release 6.2.2`;
  this branch does not touch it — duplicate-version publishes are
  rejected by pub.dev).
- **SC-2 (B2)**: pub.dev API → `latest=6.2.2
  published=2026-09-08T20:03:48.135281Z`.
- **SC-3 (B3)**: `dart pub publish --dry-run` → exit **65**, output:
  "Package validation found the following 4 potential issues" … "Package
  has 4 warnings." — **0 errors**; the upload set includes
  `benchmark_contract.dart (7 KB)` (22 benchmark-path entries). The 4
  warnings are pre-existing cosmetics on paths untouched since the
  release commit (`git log 956867fa..d23bde35 -- examples/ tools/ docs/
  .gitignore .env coverage/` is empty): 3 checked-in-but-gitignored
  files (`.env`, `.zuraffa/plans/plan_1773207137676.json`,
  `coverage/lcov.info`) and the plural layout names `examples/`,
  `tools/`, `docs/`. "Package validation passed" (the zero-warning
  variant) does NOT print for this reason — recorded ACTUAL, not the
  task brief's ideal string. Real publishes proceed past warnings via
  the interactive prompt; 6.2.2 published from this same warning state.
- **SC-4 (B5a)**: `tar -tzf` on the downloaded pub.dev 6.2.2 archive →
  `lib/src/core/benchmark/benchmark_contract.dart` present; 8 files
  under `lib/src/core/benchmark/`, 9 under `lib/src/plugins/benchmark/`.
- **B4**: `dart test test/core/publish_set_exports_test.dart` (targeted,
  not the full suite) → exit 0, `+4: All tests passed!` — the in-repo
  publish-set export guard (#1307/#1325, merged via the #1313 work) is
  green on this branch. Kernel cache cleaned before and after
  (`.dart_tool/test/`, `dart_test.kernel.*`).
- **SC-7 (B6)**: drift-guard self-test — see red→green above.
- **SC-8 (B7)**: `git diff --name-only master -- lib/ bin/ tool/` →
  empty (FR-8 no-source-change constraint holds; the branch adds only
  spec artifacts + the workflow).

## Changed-file verification (task brief protocol)

- `dart analyze $(git diff --name-only HEAD -- '*.dart')` → SKIPPED
  honestly: the changed set contains **zero `.dart` files** (spec `.md`
  artifacts + one workflow `.yml`), so there is nothing to analyze
  beyond what B4's compile already exercised.
- Targeted test loop `git diff --name-only HEAD -- 'lib/'` → empty map,
  zero tests to run (no `lib/` change).
- `dart format .` → 3 pre-existing files OUTSIDE the CI format gate's
  scope were flagged (`corpus/regression/.../u1_test.dart` ×2,
  `specs/1256-update-setup-zuraffa-ui/tdd/red_repro.dart`). The CI
  format job runs `dart format --set-exit-if-changed lib test` —
  **exit 0, "Formatted 2442 files (0 changed)"** on this branch. The 3
  out-of-scope files were REVERTED untouched: reformatting files under
  `corpus/**` would trigger the generator-differential workflow against
  regression baselines — an out-of-scope behavioral risk a release PR
  must not take. Flagged here as pre-existing master drift for a future
  housekeeping task.
- POST-TEST cleanup: `.dart_tool/test/` + `dart_test.kernel.*` removed;
  scratch consumer, drift self-test dirs, downloaded tarball and pub
  cache entries (`zuraffa-6.2.1`, `zuraffa-6.2.2`) deleted after
  evidence capture.

## PROVED vs not

| Criterion | Verdict |
|---|---|
| 1. Version bump 6.2.2 | **PROVED** (SC-1; merged upstream, branch leaves it intact) |
| 2. Published; 6.2.2 latest on pub.dev | **PROVED** (SC-2; publish executed by maintainer 2026-09-08 — this branch re-proves publishability via dry-run, 0 errors) |
| 3. Tarball smoke test incl. benchmark | **PROVED** (SC-4 + SC-5 green + SC-6 red on 6.2.1) |
| 4. Publish-drift CI guard | **PROVED** (SC-7 self-test red + green; workflow lands in this PR) |

Not claimed: a fresh publish by this branch (impossible and unnecessary
— 6.2.2 already live; duplicate-version publish is rejected by pub.dev).
The dry-run "Package validation passed" string (zero-warning variant) is
NOT met — 4 pre-existing cosmetic warnings recorded verbatim above.
