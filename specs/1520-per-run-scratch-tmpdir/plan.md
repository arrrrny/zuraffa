# Plan — Spec 1520 per-run scratch TMPDIR + age-guarded janitor + configurable root

## Technical Context

- Chokepoint: `lib/src/plugins/tdd/services/tdd_timeout.dart` — `runTimed`
  spawns every TDD subprocess via `Process.start(...)` with NO `environment:`
  parameter, so every child inherits `Platform.environment` (the shared user
  TMPDIR). `step_runner.dart:153` is the same inheritance observed at the
  `StepRunner` layer (`defaultZfaBin` resolves through
  `Platform.environment`; the default spawner calls `runTimed` bare).
- Spawn sites (all spawn test children with the inherited TMPDIR):
  - `step_runner.dart` `_timedDefaultSpawner` → `runTimed` (the run/refactor
    driver's step children).
  - `realize_mock_command.dart` `_suiteRunner()` (`Process.run dart test`) +
    `_tier1Driver()` (`Process.start dart run tool/realize_driver.dart`).
  - `realize_command.dart` `_fixtureDriver()` (`Process.start dart run ...`)
    + `_suiteRunner()` (`Process.run dart test`).
  - `dream_runner.dart` `_timedProcessRun` (`Process.start`) behind
    `_defaultZfaSpawner` / `_defaultProcSpawner`.
  - `differential_ref_runner.dart` default `DifferentialSpawner` (`runTimed`)
    + default `DifferentialGitRunner` (`Process.run git`).
- Janitor: `lib/src/plugins/tdd/services/kernel_cache.dart`
  (`clearDartTestKernelCache`, #1515) — already dir-aware (files AND
  directories, recursive) with the argv-liveness guard, the
  `commandStartedAt` guard, and the `.dart_tool/test/` cycle-marker
  ownership guard. Missing: the ~1h age floor; the sweep reads
  `Platform.environment['TMPDIR']` directly (not injectable); the configured
  scratch root is not swept.
- Config: `.zfa.json` `tdd.*` keys are read per-command with a small
  `File('$projectRoot/.zfa.json')` + `jsonDecode` walk (the
  `tdd.realizeDifferentialThreshold` pattern in differential_harness.dart).
  `ZFA_TMPDIR` is new.
- Constraints honored: no state-machine/loop/test-runner-semantics changes;
  every new parameter is optional with today's behavior as the default;
  scratch lifecycle is `try/finally` best-effort.

## Approach

1. **New service `scratch_tmpdir.dart`** (the single owner of the scratch
   contract — the `kernel_cache.dart` layering lesson: shared contracts live
   in `services/`, not on a command):
   - `defaultKernelScratchPrefix = 'zfa-'` and label sanitization
     (`[^A-Za-z0-9._-]` → `_`, capped at 80 chars).
   - `ScratchTmpDir.configuredRoot(projectRoot, {environment})` — `ZFA_TMPDIR`
     (non-empty) > `.zfa.json` `tdd.tmpDir` (non-empty String) > null.
   - `ScratchTmpDir.acquire({label, projectRoot, environment})` — creates
     `(configured root ?? effective temp root).createTemp('zfa-<label>-')`;
     the effective temp root is the environment's TMPDIR/TEMP/TMP else
     `Directory.systemTemp.path`, so a nested tdd command that inherits its
     parent's scratch TMPDIR nests its own scratch inside the parent's
     (FR-4). Returns null on ANY failure (best-effort, never throws).
   - `childEnvironment({base})` — a merged copy of the base environment
     (default `Platform.environment`) with `TMPDIR`/`TEMP`/`TMP` pointed at
     the scratch path.
   - `dispose()` — idempotent, best-effort recursive delete.
2. **Chokepoint injection** — `runTimed` gains an optional
   `Map<String, String>? environment` forwarded to `Process.start`
   (`includeParentEnvironment` stays true: the map OVERRIDES the inherited
   env, it does not replace it). `StepRunner` gains `childEnvironment`;
   its default spawner forwards it to `runTimed`. The injected-`StepSpawner`
   fast-tier contract is unchanged (fakes ignore the env; the real spawn
   path is what carries it).
3. **Spawn sites** — the realize/realize-mock default suite runners and
   driver spawns, the dream default spawners (`_timedProcessRun` gains the
   same optional `environment`), and the differential default spawner/git
   runner forward the command's scratch env. Every forwarded map is
   `null`-safe: `Process.*` with `environment: null` is exactly today's
   behavior.
4. **Command-level lifecycle** — `tdd run` (via `RunDriverCore.drive`,
   which constructs the `StepRunner`), `tdd realize`, `tdd realize-mock`,
   `tdd dream` (`DreamRunner.execute`), and `tdd corpus differential`
   acquire the scratch once per invocation (label: the feature reference /
   entity / feature name), inject `scratch?.childEnvironment()` into every
   child, and `dispose()` in a `finally`. The command bodies keep their
   shape: a thin `_run()` wrapper owns acquire/try/finally and delegates to
   the (renamed) body, so no loop or state-machine code moves.
5. **Age-guarded janitor** — `clearDartTestKernelCache` gains injectable
   `environment` / `now` / `ageGuard` (default
   `defaultKernelAgeGuard = Duration(hours: 1)`) and the TMPDIR sweep
   deletes an entry only when BOTH
   `modifiedAt.isBefore(commandStartedAt)` (#1507 guard, unchanged) AND
   `modifiedAt.isBefore(now - ageGuard)` (new age floor) hold. The sweep
   runs over the ambient TMPDIR root AND the configured scratch root
   (deduped, canonicalized); liveness + the project-cache ownership guard
   are untouched. `refactor_command.dart` and `run_command.dart` call sites
   keep their signatures (all new parameters optional).
6. **Wiring order** — the sweep still runs at cycle start (before children
   spawn) so a per-run scratch is never swept by its own command; the age
   floor makes a nested command's janitor a no-op on its parent's fresh
   scratch.

## Test strategy

- **Fast tier** (no real processes where avoidable):
  `test/plugins/tdd/scratch_tmpdir_test.dart` — the service contract
  (root priority, sanitization, best-effort null, childEnvironment merge,
  dispose idempotence) with injected environments; `runTimed`'s env
  passthrough and `StepRunner`'s childEnvironment injection through real
  POSIX child probes (`@TestOn('linux || mac-os')`).
  `test/plugins/tdd/kernel_cache_age_guard_test.dart` — the janitor's age
  floor with injected clocks: young-but-pre-start entries survive; old
  dirs/files are swept; the configured root is swept; the
  `commandStartedAt` guard still wins.
- **CLI tier** (the #922/#1333 TddFixture fake-zfa pattern):
  `test/plugins/tdd/bug_1520_run_scratch_tmpdir_test.dart` — a full
  `zfa tdd run` whose fake zfa records `$TMPDIR` per invocation: every step
  child observes a fresh `zfa-<feature>-*` scratch, the scratch is inside a
  configured `ZFA_TMPDIR` root when set, and the scratch is deleted after
  the run.
- Red protocol: the service and the new parameters do not exist pre-fix —
  fast-tier reds are analyzer/compile errors (the spec-1333 red-protocol
  TODO pattern); the CLI tier reds behaviorally (children log the ambient
  user TMPDIR, no scratch dir exists).

## Risks

- `Process.start(environment:)` merges with the parent env — a child that
  reads `TMPDIR` sees the scratch; a child that hardcodes `/tmp` is
  unaffected (no regression surface).
- `Directory.systemTemp` resolves the CURRENT process env, so the
  nested-scratch behavior (FR-4) holds without any nested-command change.
- The age floor interacts with the #1507 suite's 1h-backdated fixtures:
  seeded entries are 1h + command-duration old, i.e. past the floor — the
  suite stays green (verified in verification.md).
