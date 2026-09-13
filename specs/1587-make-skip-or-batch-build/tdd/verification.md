# Verification: 1587-make-skip-or-batch-build

Date: 2026-09-13 · Branch: `feat/1587-make-skip-or-batch-build`

## Method

Every behavior below was executed against the real CLI surface or the
real service layer in this checkout. Nothing on this page is asserted
from reading code alone. The red→green discipline: the two behavioral
tests (A1, A3) were run and observed FAILING on the pre-fix tree, and
the unit/runner tests were observed failing to COMPILE (the service,
the runner flag, and the model field did not exist), then the
implementation landed and every suite below was re-run and observed
passing.

## Red evidence (pre-fix tree, before the implementation commit)

- `dart test test/plugins/tdd/services/build_relevance_test.dart` →
  compile error: `Error when reading
  'lib/src/plugins/tdd/services/build_relevance.dart': No such file or
  directory` + `Undefined name 'BuildRelevance'` (×N).
- `dart test test/plugins/tdd/services/pipeline_runner_1587_test.dart`
  → compile errors: `No named parameter with the name
  'skipUnchangedBuild'` (×2), `The getter 'buildSkipped' isn't defined
  for the type 'GenerationStep'`.
- `dart test test/plugins/tdd/make_command_1587_build_skip_test.dart
  test/plugins/tdd/make_command_1587_dedup_test.dart` → 5 passed (the
  unchanged-behavior regression guards), 2 FAILED:
  - A1/SC-001 — `log.where((l) => l.contains('build')), isEmpty`
    failed: the whole-project build spawned for a plain subject write.
  - A3/SC-004 — `contains 'drift check satisfied from the certified
    red evidence'` missing: the precondition re-ran the target test.

## Green evidence (post-fix)

### Behaviour suites (this branch)

| suite | result |
| --- | --- |
| `test/plugins/tdd/services/build_relevance_test.dart` + `pipeline_runner_1587_test.dart` | 16 passed |
| `test/plugins/tdd/make_command_1587_build_skip_test.dart` + `make_command_1587_dedup_test.dart` | 7 passed |
| `test/plugins/tdd/commands/` | 550 passed |
| `test/plugins/tdd/{services,models,scenarios,theater,corpus_economics,helpers}/` | 1133 passed |
| `test/plugins/tdd/*.dart` top level (2 batches) | 574 passed |
| `test/commands/` | 379 passed |
| `test/core/` | 671 passed (+1 skipped) |
| `test/agent, domain, feature_flags, i18n, config, logging/` | 383 passed |
| `test/dda, docs, migration, helpers/` | 92 passed |
| `test/engine, state, skin, simulation, templates, utils/` | 599 passed |
| `test/plugins/{api,app_shell,benchmark,cache,cli,controller}/` | 215 passed |
| `test/plugins/{datasource,di,feature,graphql,gym,helpers}/` | 178 passed |
| `test/graphql/`, `test/helpers/` (chunked runner, partial sweep) | 192+ passed |

### Behavior-by-behavior test-list verdicts

- **A1 (skip on plain-Dart generation)** — U-1587-1: generation rewrote
  the subject (no annotations); the fake-zfa argv log recorded the func
  step and ZERO build spawns; stdout carried
  `terminal build step skipped: no builder-consumable input changed
  ... (issue #1587)`; the green evidence's generation block carried the
  synthetic step (`exit: 0`, `note: skipped`); `outcome=green`, exit 0,
  live post-generation `target test exit: 0`. **GREEN.**
- **A2 (annotated write keeps the build)** — U-1587-2 (`@Zorphy` raw
  content) and U-1587-3 (`pubspec.yaml` config churn): the build spawn
  recorded; no skip line. **GREEN.**
- **A3 (dedup on matching subject hash)** — U-1587-4: hashed red as the
  last entry, hash matched the on-disk subject; stdout carried
  `drift check satisfied from the certified red evidence — subject hash
  matches, target test not re-run (issue #1587)`; generation ran; the
  green evidence stayed live. **GREEN.**
- **A4 (fail open: hashless / drifted)** — U-1587-5 (hashless red) and
  U-1587-6 (`a`×64 hash mismatch): no dedup note; the live drift
  re-run executed. **GREEN.**
- **A5 (green after red keeps the live drift)** — U-1587-7: green
  evidence after the red; no dedup note; `outcome=skipped` (#694) with
  zero pipeline spawns. **GREEN.**
- **U1–U8** — unit/runner layer all covered by
  `build_relevance_test.dart` (fingerprint + gate decisions incl.
  deletions, config churn, non-dart writes, each annotation),
  `pipeline_runner_1587_test.dart` (synthetic step, annotated write,
  default-OFF), and the make-level suites. **GREEN.**

### Static analysis + formatting

- `dart analyze` over the repo: 112 findings, byte-identical to the
  pre-fix baseline (all pre-existing infos; zero new errors, warnings,
  or infos) — verified by sorted diff against the saved baseline.
- `dart format lib/ test/`: clean (`0 changed` on the final sweep).

### Regression notes

- `test/plugins/tdd/commands/bug_1551_no_green_units_defers_test.dart`
  (3) pinned `log.last == 'build'` as a plan-completion proxy. Under
  the #1587 scheduling contract a plain-Dart compose write skips the
  terminal build, so the pin was updated to the new honest contract
  (compose is the last spawn; the skipped build is audited via
  `note: skipped`; plan completion stays pinned by the green outcome
  and green evidence). Test intent (#1512 surface unbroken) preserved.
- Two suites fail in this environment for reasons that PRE-DATE this
  branch and are not exercised by it: they require the Flutter SDK
  (`flutter pub get` — `ProcessException` from
  `flutter_cluster_fixture.dart`): `controller_compile_test.dart`,
  `downstream_compile_gate_test.dart`. Not run to completion here:
  `test/plugins/{mcp,mock,module,provider,service,simulation}/`
  (per-folder runs exceed the 10-minute sandbox budget; they do not
  import the changed tdd surfaces — `PipelineRunner.runPlan` is called
  only from `make_command.dart`).

## Success criteria scorecard

- **SC-001** — met (A1: zero build spawns; green, exit 0, live green
  evidence).
- **SC-002** — met (A2: annotated write spawns the build).
- **SC-003** — met (A2b: config churn spawns the build; deletion
  refusal covered at unit level).
- **SC-004** — met (A3: zero precondition target-test subprocesses;
  green).
- **SC-005** — met (A4: hashless red still runs the live drift check).
- **SC-006** — met (analyze diff against baseline: zero new findings).
