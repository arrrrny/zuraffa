# Running the test suite

Tests are split into a **fast unit suite** (default) and **slow tiers**
(E2E generation, full CLI runs, property/benchmark). This keeps day-to-day
feedback quick while still letting you target exactly the slice you care about.

## Tiers

| Tier        | Tag             | Folder(s)                                  | Speed  |
|-------------|-----------------|--------------------------------------------|--------|
| unit (default) | —             | `core`, `plugins`, `commands`, `state`, `graphql`, `config`, `domain`, `dda`, `cli`, `utils`, `src`-derived | fast   |
| regression  | `regression`    | `test/regression`                          | slow (E2E codegen) |
| integration | `integration`   | `test/integration`                        | slow (spawns CLI)   |
| property    | `property`      | `test/property`                           | slow   |
| benchmark   | `benchmark`     | `test/benchmark`                          | slow   |

Every slow test is also tagged `slow`. The default `dart test` run excludes
the `slow` tier (see `dart_test.yaml`).

## Commands

Run the fast unit suite (default — this is what CI and cloud/CI agents run,
and the tier to use for routine validation):

```bash
dart test
```

Run a single slow tier (only when the user explicitly asks for one):

```bash
dart test --preset=regression
dart test --preset=integration
dart test --preset=property
dart test --preset=benchmark
```

Target a **semantic folder** (fast feedback while working on one area):

```bash
dart test test/core
dart test test/plugins/route
dart test test/commands
dart test test/graphql
```

Run a **single file**:

```bash
dart test test/core/result_test.dart
```

## How it is wired

- Slow tiers carry `@Tags([...])` at the top of each file (library-level).
- `dart_test.yaml` sets `exclude_tags: slow` so the default run is fast. Run a
  specific slow tier with `--preset=regression` / `integration` / `property` /
  `benchmark` only when asked.
- Do NOT run `dart test --preset=all` on cloud/CI agents: it pulls in every slow
  tier, each spinning up temp projects that run `dart pub get` + `build_runner`
  and can fill several GB under `/tmp`, exhausting disk/RAM on small agents.
  Reserve `--preset=all` for an explicit full-local baseline on a developer
  machine (see `dart_test.yaml`).
- Add the `slow` tag (plus the tier tag) to any new E2E / heavy test so it is
  excluded from the default run automatically.

## Slow machines: `ZFA_TEST_TIMEOUT_SCALE`

Suites that spawn the CLI through `test/helpers/run_zfa_source.dart` carry
subprocess timeout budgets sized for CI-class hardware:

- **75s** — default per-spawn child guard (`runZfaSource`); the guard is
  killed with a named `TimeoutException` diagnostic so a wedged spawn fails
  fast instead of eating the enclosing test timeout (issue #531).
- **240s** — EVERY source spawn, under the documented
  degraded-environment escape hatch (`ZFA_ALLOW_JIT=1`, the only
  path that spawns `dart bin/zfa.dart`): the child pays the Dart VM
  front-end + JIT compile of the whole package before running a single
  command — **84s measured cold start alone** on the host that filed
  issue #1623, longer than the 75s guard, and a warm start was measured at
  71s — so every source spawn takes the cold budget instead of gambling on
  warm caches or in-file spawn order (issue #1623).
- **100s** — one-time AOT compile of `bin/zfa.dart` in `setUpAll`
  (`initZfaSourceBin`). When this budget is exceeded — or the compile fails
  for any reason — the build fails LOUDLY: `ZfaCompilationException`
  (its reason names the budget and this variable), rethrown by
  `initZfaSourceBin` as a `StateError` that fails the whole file in
  `setUpAll`. There is NO silent downgrade to the slow JIT path — that was
  the pre-#531-policy behavior; the no-JIT spawn policy removed it, so a
  slow compile can no longer turn into a whole suite of bare timeout
  failures. Raise this variable (or free the disk / fix the SDK) as the
  diagnostic instructs.

On older hardware (the 2019 Intel Mac baseline of issue #1187) the cold
frontend-server compile alone can exceed both budgets, and the
`feature_flags` suite failed 9+ tests purely on timeouts with no logic
failures. Set `ZFA_TEST_TIMEOUT_SCALE` to stretch **every** budget
proportionally instead of touching test semantics:

```bash
ZFA_TEST_TIMEOUT_SCALE=2 dart test test/feature_flags --preset=all
```

- Values are multipliers ≥ 1.0; blank/unparsable/NaN/infinite values and
  anything below 1.0 fall back to 1.0 (the scale relaxes budgets, never
  tightens them).
- The multiplier applies to the helper's 75s child guard, the 240s cold
  source spawn budget, the 100s AOT compile budget, and every suite
  `Timeout` built through `scaleDuration(...)` (the `feature_flags` suite
  declares these as 3-minute base ceilings so they grow together with the
  child guard — the guard must stay shorter than the enclosing test
  ceiling for its fail-fast diagnostic to fire first).
- Explicit `timeout:` arguments passed to `runZfaSource(...)` are NOT
  auto-scaled (only the default scales). Callers that want their custom
  budgets to follow the env must pass them through `scaleDuration(...)`
  themselves.
- The mechanism is covered by the fast-tier unit tests in
  `test/helpers/zfa_test_timeout_scale_test.dart` (run with the variable
  unset and with a scaled value to prove the plumbing both ways).
- Cloud/CI agents on modest runners can set the same variable in the job
  environment; the default (unset) behavior is unchanged everywhere.
- Note that `dart_test.yaml` tag timeouts (`timeout: 2x` global, `4x` for
  `slow`-tagged tests) are fixed factors that cannot read the environment;
  suites outside `feature_flags` that rely on those ceilings and need more
  headroom can pass an additional `--timeout xN` flag to `dart test`
  (e.g. `--timeout x8`) alongside the scale variable.

### Example: a slow CI host (issue #1623's shape)

On a host where `dart compile exe bin/zfa.dart` needs 2m38s, the 100s AOT
budget fails the file loudly in `setUpAll` — the fix is the scale, not a
per-test timeout override. Export the variable in the JOB environment so
every budget (75s guard, 240s cold source spawn, 100s AOT compile)
stretches together, and pair it with `--timeout xN` when the tier's fixed
`dart_test.yaml` ceilings are also too tight:

```yaml
# .github/workflows/integration.yml (shape)
env:
  ZFA_TEST_TIMEOUT_SCALE: '2'   # every helper budget x2: 150s guard,
                                # 480s cold source spawn, 200s AOT compile
steps:
  - run: dart test --preset=integration --timeout x4 test/package_sdk
```

Rule of thumb: set `ZFA_TEST_TIMEOUT_SCALE` to the smallest value that
covers the measured compile (2× covers a 200s AOT build); add
`--timeout xN` only when the enclosing tag ceiling (not the helper budget)
is what fired. One-off local reproduction of a slow-host failure:

```bash
ZFA_TEST_TIMEOUT_SCALE=2 dart test --preset=integration --timeout x4 \
  test/package_sdk/plugin_scaffold_e2e_test.dart -n B9b
```

