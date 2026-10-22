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

> **On this repo, run the fast tier through the entrypoint**:
> `dart run tools/run_fast_suite.dart`. It pins the serial flag and refuses
> a parallel request. See
> [Loaded hosts: the serial fast lane](#loaded-hosts-the-serial-fast-lane)
> below for why a plain `dart test -j 2` is not safe here.

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

## Loaded hosts: the serial fast lane and the budget ladder

Two properties of the fast tier are load-sensitive, and issue #1994 is the
report that both of them bit on a shared host under load ~390:

1. **The fast tier runs SERIAL — and that is a correctness requirement.**
   `dart test` runs the suites as isolates of ONE process, so
   `Directory.current` and `dart:io exitCode` are process-global. In a
   parallel lane one suite's chdir window silently redirects every
   concurrent suite's relative-path I/O into its temp fixture — the three
   consecutive red master runs of #1632/#1682.
   `dart_test.yaml` pins `concurrency: 1` for that reason, **but the pin
   alone does not hold**: package:test resolves
   `concurrency => _concurrency ?? defaultConcurrency`, so a CLI `-j 2`
   overrides the config SILENTLY. The fleet-wide `dart test -j 2`
   convention therefore broke the invariant without a word — and the
   symptom is a fast suite that fails in ways that pass in isolation
   (`pubspec.yaml not found` mid-setup, a sibling's tree read as yours).
2. **The per-test ceiling is a fixed factor, and a cold child can outrun
   it.** The root ceiling is `4x` (120s of package:test's 30s base) after
   this change; at the time of #1994 it was `2x` (60s). A
   fast-tier suite that drives a REAL external child — a `dart analyze`
   subprocess — pays the analyzer's cold start inside that budget, and on
   a loaded host the start alone exceeds it. The real-analyzer suite went
   further and pinned its own ceiling with a 2-minute per-test constant,
   so the root ceiling never governed it — the effective ceiling there was
   120s, not 60s. The `ffi` lane already carries `8x` for exactly this
   reason (#1678); the `spawn` tag (issue #1994) carries the same ceiling
   for the fast-tier suites that drive a real child.

### What to run

```bash
# the fast tier, serial, with the CI lane's tag selector
dart run tools/run_fast_suite.dart

# a subset, still serial
dart run tools/run_fast_suite.dart test/core
```

The entrypoint pins `-j 1` explicitly (an implicit default is exactly what
a fleet-wide `-j 2` overrides) and **refuses** a parallel request with the
reason instead of inheriting one:

```console
$ dart run tools/run_fast_suite.dart -j 2
run_fast_suite: REFUSING concurrency=2.
...
$ echo $?
2
```

It also runs CI's `dart_core` lane (`--exclude-tags "flutter || e2e"`), so
the local fast tier is the BOUNDED lane: CI measures it at ~12 minutes,
while the whole-tree default run (`dart test`, which also pulls in the
`e2e` temp-project suites) is what pushed a loaded host past a two-hour
window in #1994.

A **preset** is refused here: a preset carries its own selector
configuration, and that configuration wins over the CLI's tag selectors
(package/test), so it would replace the lane's `--exclude-tags` and take
the run outside the bounded lane — the `all` preset re-admits the whole
tree. Run a heavy tier directly with its own lane instead
(`dart test --preset=regression`).

> **On a small/disposable agent, use the chunked runner instead.** The
> entrypoint runs `dart test test`, which compiles the whole test tree's
> kernel into one cache that can reach ~6.5 GB — the same warning the
> next section gives for a plain `dart test test`. Use
> `tools/run_tests_chunked.sh` (kernel cache cleared between per-folder
> chunks) when disk is tight.

### The `spawn` tag

A fast-tier suite that drives a real external child carries the `spawn`
tag, which raises its ceiling to `8x` (240s — the `ffi` precedent). Put
it on the group that drives the child, not on the whole file — a file-wide
tag would move every in-process test in it from the 60s ceiling to 240s:

```dart
group('real scoped dart analyze (U3 real)', () {
  // ...tests that build the PRODUCTION certifier...
}, tags: ['spawn']);
```

A file-level annotation works too, and is the right choice when the whole
file drives real children:

```dart
@Tags(['spawn'])
library;
```

The tag is NOT a tier: it rides the default `slow` exclusion, so a
`spawn`-tagged suite still runs in the fast tier (and in CI's
`dart_core` lane) — it only gets the relaxed ceiling. The tier-integrity
pin B10 (`test/tier_integrity_test.dart`) keeps the class honest: every
fast-lane-eligible suite that reaches a real analyzer child through the
lib must carry the tag — on the file or on the group.

### The budget ladder

The old 2x (60s) root ceiling killed spawn-heavy suites **mid-setup**: the
suite left a half-created temp project behind, and the next test in the same
file failed on the missing `pubspec.yaml` rather than on its own subject — a
cascade that reads like a functional regression and is not one (every failing
file passed in isolation on the same tree).

Two budgets and one tag close that gap:

| Knob | Value | Why |
|------|-------|-----|
| root `timeout` | `4x` (120s) | what the #1994 report verified on the loaded host (`dart test -j 2 --timeout 4x`) |
| `spawn` tag | `8x` (240s) | two sequential 75s child guards plus slack — the `ffi` precedent (#1678) |
| `e2e` tag | `8x` (240s) | same reason: real `dart pub get` / `dart test` / `analyze` children |

`spawn` is orthogonal to the lane tags: `slow`/`e2e` decide *where* a suite
runs, `spawn` only decides *how much wall-clock* it gets. Add it to any new
fast-tier suite that launches an external process.

Two traps worth knowing, both pinned by `test/tier_integrity_test.dart`
(B11–B13):

- **`-j/--concurrency` always wins.** The CLI value overrides this repo's
  `concurrency: 1` in `dart_test.yaml`; there is no config-side hard cap.
  That is why the fast tier is run through
  `dart run tools/run_fast_suite.dart` (which owns the cap and refuses a
  parallel request) — a direct `dart test -j 2` still overrides the pin and
  runs two suites at once, and the budgets above are what keep such a run
  honest under load.
- **An explicit per-test `Timeout` overrides BOTH the tag and the root.** A
  literal below the root ceiling silently re-creates the #1994 timeout for
  that test; `B13` fails on one. Raise it, or route it through
  `scaleDuration(...)` from `test/helpers/run_zfa_source.dart` so
  `ZFA_TEST_TIMEOUT_SCALE` still reaches it.

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

