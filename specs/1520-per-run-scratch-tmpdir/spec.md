# Spec 1520 — per-run scratch TMPDIR + age-guarded janitor + configurable root

GitHub issue: arrrrny/zuraffa#1520
Related: #1507 (the kernel-dir leak), #1333 (transient runner failures / first
cleanup attempt), #1515 (kernel_cache service extraction)
Severity: high — cross-agent TMPDIR collisions kill live compiles; the shared
TMPDIR is a correctness hazard for every agent and terminal on the machine,
not just a disk leak.

## Problem

Every `dart test` process creates a per-process
`$TMPDIR/dart_test.kernel.<random>/` directory. The user TMPDIR is shared by
every agent and terminal on the machine. Two hazards collide there:

1. **Cross-agent cleanup kills live compiles.** Any process that globs
   `$TMPDIR/dart_test.kernel.*` and deletes (to fix #1507) deletes ANOTHER
   agent's actively-compiling kernel dir. The existing guards
   (commandStartedAt, argv liveness, #1515) narrow the window but cannot
   close it: entries written BEFORE this command started can still belong to
   a concurrent runner that started earlier and is still compiling.

2. **The cleanup is a mop, not isolation.** `clearDartTestKernelCache`
   (kernel_cache.dart, #1515) deletes `.dart_tool/test/` recursively (shared
   by every same-project runner, guarded only by the cycle marker) and
   sweeps TMPDIR kernel entries. The sweep's mtime guard protects entries
   newer than THIS command's start — an entry two minutes old, left by a
   crashed agent ten minutes ago, is deleted even though some other machine
   user may still reference it. The janitor deletes by GUESS (age heuristics
   about other people's files); nothing deletes its OWN garbage by
   construction.

Root cause: all zfa test children inherit `Platform.environment` (the
shared user TMPDIR) — `runTimed` (tdd_timeout.dart) spawns with no
`environment:` override, `StepRunner`'s default spawner inherits it, and the
realize/dream/differential spawn sites do the same. Every `dart test` child
therefore writes its kernel dir into ONE shared directory that every agent
on the machine sweeps.

## Locked decisions

1. Fix ONLY TMPDIR handling in `step_runner.dart` and the spawn sites
   (`realize_mock_command.dart`, `realize_command.dart`, `dream_runner.dart`,
   `tdd_timeout.dart`, `differential_ref_runner.dart`) plus the command-level
   scratch lifecycle wiring. Test runner semantics, the state machine, and
   the loop logic are UNCHANGED.
2. Per-run scratch deletion is best-effort in a `finally` block — a failed
   cleanup prints nothing fatal and never changes the run's exit code.
3. The age-guarded janitor must NOT delete anything written after the
   command started (the #1507 guard is preserved) AND nothing younger than
   ~1 hour (the new age floor).
4. Scratch acquisition is best-effort: a failure to create the scratch
   degrades to today's behavior (children inherit the ambient TMPDIR), never
   a crash.
5. Scratch-root priority: `ZFA_TMPDIR` env (invocation-level) > `.zfa.json`
   `tdd.tmpDir` (project-level) > the effective temp root (TMPDIR/TEMP/TMP,
   else `Directory.systemTemp`). No new CLI flag.
6. The `.dart_tool/test/` sweep and its cycle-marker ownership guard
   (#1507 CR-1) are UNCHANGED — this spec only touches TMPDIR handling.

## Functional requirements

- **FR-1 (per-run scratch)**: Every tdd command that spawns test children
  or test-adjacent tooling (`tdd run`, `tdd refactor`, `tdd realize`, `tdd
  realize-mock`, `tdd dream`, `tdd corpus differential`) creates ONE scratch
  dir per invocation via `createTemp('zfa-<feature>-')`, injects it as
  `TMPDIR`/`TEMP`/`TMP` into every child's environment, and deletes it
  (recursively, best-effort) at run end in a `finally` block. `tdd refactor`
  is the driving command whose loops historically leaked the most (#1507),
  so its preflight/re-proof suite children AND its pass children
  (build/format/fix) all inherit the scratch.

- **FR-2 (chokepoint injection)**: `runTimed` accepts an optional
  `environment` map and passes it to `Process.start`; `StepRunner` accepts
  the caller's child environment and the default spawner forwards it; the
  realize/realize-mock/dream/differential default spawners forward the same
  map. Null (the default everywhere) preserves today's
  inherit-`Platform.environment` behavior.

- **FR-3 (leak fixed by construction)**: A run's `dart test` children write
  their `dart_test.kernel.*` dirs INSIDE the run's scratch; run-end cleanup
  deletes only the run's own scratch dir recursively. After a completed run,
  the scratch no longer exists.

- **FR-4 (nested isolation)**: A spawned tdd command (e.g. the `tdd run`
  step children) inherits the parent's scratch TMPDIR; its own children
  therefore write inside the parent's scratch even when the nested command
  creates no scratch of its own. Nesting never escapes the outermost
  scratch.

- **FR-5 (age-guarded janitor)**: The TMPDIR kernel sweep deletes
  `dart_test.kernel.*` entries (files AND directories, directories
  recursively) only when the entry's mtime is older than the command start
  (unchanged #1507 guard) AND older than ~1 hour (new age floor,
  `defaultKernelAgeGuard = Duration(hours: 1)`). Nothing written since the
  command started is ever deleted. Top-level `zfa-*` scratch directories
  are reclaimable under the same guard stack, so a scratch orphaned by a
  run that died before its `finally` does not accumulate forever; a scratch
  holding a live runner's kernel is protected by the liveness guard (the
  runner's `--output-dill=<scratch>/dart_test.kernel.*` argv reference).

- **FR-6 (configurable scratch root)**: `ZFA_TMPDIR` and `.zfa.json`
  `tdd.tmpDir` name the scratch ROOT; zfa creates the per-run subdir inside
  it. Default: per-run system temp (the effective temp root). Empty values
  fall through to the next tier. `ZFA_TMPDIR` is used verbatim; a relative
  `.zfa.json` `tdd.tmpDir` resolves against the project root that declared
  it (not the process's incidental CWD, so two invocations from different
  directories cannot scatter scratches across the filesystem). The
  `.zfa.json` tier applies to every spec'd command, including ones invoked
  without `--project` (the root falls back to the nearest `specs/`
  ancestor).

- **FR-7 (janitor covers the configured root)**: The kernel sweep covers
  the ambient TMPDIR root (as today) AND the configured scratch root when
  one is set — both under the full guard stack (liveness, commandStartedAt,
  age floor).

## Success criteria (measurable)

- SC-1: A `tdd run` invocation's step children observe a `TMPDIR` that is a
  fresh `zfa-<feature>-<random>` directory, and that directory does not
  exist after the run completes (FR-1, FR-3).
- SC-2: With `ZFA_TMPDIR=<root>` set (or `.zfa.json` `tdd.tmpDir`), the
  scratch dir is created inside `<root>` (FR-6). `ZFA_TMPDIR` wins over
  `.zfa.json`.
- SC-3: A `dart_test.kernel.*` DIRECTORY whose mtime is before the command
  start but younger than 1 hour survives the janitor sweep (FR-5 — the
  pre-spec code deletes it).
- SC-4: A `dart_test.kernel.*` directory (and file) older than 1 hour is
  swept exactly as before — the age floor does not disable the janitor
  (FR-5, #1507 preserved).
- SC-5: `runTimed(..., environment: {'TMPDIR': X})` children observe
  `TMPDIR=X`; `StepRunner(zfaBin: fake, childEnvironment: env)` children
  observe the injected `TMPDIR` (FR-2).
- SC-7: A `tdd refactor` invocation's suite children observe a fresh
  `zfa-<feature>-<random>` directory (not the shared user TMPDIR) and that
  directory does not exist after the invocation completes (FR-1, FR-3).
- SC-8: A top-level `zfa-*` scratch directory older than the age floor is
  reclaimed by the sweep, while one holding a live runner's kernel (or
  younger than the floor) survives (FR-5).
- SC-6: `dart analyze` reports no new warnings; the existing bug-1507
  suite (test/plugins/tdd/bug_1507_kernel_cache_cycle_start_test.dart)
  stays green.

## Edge cases

- Scratch creation fails (unwritable/missing root, root path is a file) →
  the command runs scratchless (children inherit the ambient TMPDIR); the
  janitor still cleans historical leaks. Never a crash.
- Empty `ZFA_TMPDIR` / empty `tdd.tmpDir` → fall through to the next tier.
- Labels are sanitized to `[A-Za-z0-9._-]` (anything else → `_`) so a
  feature reference can never escape the root path.
- A scratch dir that survives a crashed run (the process died before the
  finally) is ordinary garbage under the root; the janitor's sweep reclaims
  top-level `zfa-*` scratch dirs under the same guard stack (commandStartedAt
  + 1 h age floor + liveness), so the leak is bounded by the crash rate
  rather than accumulating until manually removed (FR-5).
