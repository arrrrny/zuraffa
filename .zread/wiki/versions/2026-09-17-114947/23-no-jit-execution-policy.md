The No-JIT Execution Policy is a hard architectural invariant in zuraffa's CLI layer: **every child process spawned by the zfa CLI must be a compiled AOT binary, never a Dart source script run through the VM**. This policy eliminates the ~20-second cold-start penalty that `dart <path>/bin/zfa.dart` incurs per spawn, and more importantly, it guarantees that every child operates on the same code tree that is driving it — a source-driven child can silently diverge from its driver when the driver is a compiled install.

Sources: [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart#L1-L200)

## The Problem: JIT Spawning Costs and Divergence

Before the policy, every zfa child process was spawned as `dart <path>/bin/zfa.dart`. This shape pays the Dart VM front-end and JIT compilation of the entire package before the child runs a single command. Issue #531 measured ~20 seconds cold per spawn. The differential and corpus harnesses spawn dozens of children, so the cumulative cost dominated every TDD cycle.

Beyond performance, the source-spawn shape creates a correctness hazard: when the driving process is a compiled system install and a child spawns `dart <path>/bin/zfa.dart`, the child runs the source tree's code while the driver runs the installed binary's code. A fix present in one but not the other produces silent behavioral divergence.

Sources: [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart#L1-L20)

## The Core Service: ZfaExecutable

The entire policy is implemented in a single, side-effect-free static service — `ZfaExecutable` in `lib/src/cli/zfa_executable.dart`. Every spawn site resolves its entrypoint through `ZfaExecutable.ensureCompiled` and shapes its child argv through `ZfaExecutable.commandFor`. There is exactly one place in the entire codebase that reads the `ZFA_ALLOW_JIT` escape hatch.

Sources: [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart#L200-L250)

### The Two Public Seams

| Seam | Signature | Purpose |
|------|-----------|---------|
| `ensureCompiled` | `Future<String> Function(String candidate, {String? sourceRoot, ZfaCompileRunner? runner, Map<String, String>? environment, String? runningExecutable})` | Resolves a candidate entrypoint to something runnable: a `.dart` source becomes the AOT-compiled artifact; a compiled exe/snapshot is returned unchanged |
| `commandFor` | `List<String> Function(String entry, List<String> args, {Map<String, String>? environment})` | Shapes the spawn argv: `[entry, ...args]` for a compiled entrypoint; `['dart', entry, ...args]` only under the escape hatch; throws `StateError` otherwise |

Sources: [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart#L145-L200)

### The Compile Cache

When a `.dart` candidate needs compilation, the artifact lands in a shared cache directory:

```
<sourceRoot>/.dart_tool/zfa_cli_bin/
```

The canonical package entrypoint (`bin/zfa.dart` or `bin/zuraffa.dart`) keeps the shared name `zfa_exe`. Any other explicit source entrypoint (a `--zfa-bin <path>.dart` override) gets its own slot suffixed with an FNV-1a digest of the normalized path — two overrides inside one package must never inherit each other's binary.

A write-then-rename staging pattern (`zfa_exe.tmp` → `zfa_exe`) prevents the kernel from executing a half-written binary. The Linux ETXTBSY ("Text file busy") failure that killed `zfa feature enable notes` on the CI runner is explicitly handled here.

Sources: [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart#L400-L500)

## The Reuse Probe: Skipping Redundant Compiles

Issue #1664 introduced a reuse probe that avoids re-compiling when the running process is already the artifact the compile would rebuild. The probe fires only when all of these conditions hold:

1. The candidate is the canonical package entrypoint of the source root — the shape that shares the `zfa_exe` cache slot
2. The running executable is a compiled (non-Dart-VM) executable that exists on disk
3. A `zfa.build_commit` marker file exists next to the running binary and is non-empty
4. `git rev-parse HEAD` in the source root resolves and equals the marker commit

When every condition holds, the running binary is returned instead of paying the one-time ~85s AOT build that otherwise lands inside the first refactor after every master bump. A marker that disagrees — or any unprovable input — falls through to the compile.

Sources: [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart#L250-L350)

## The Staleness Guard

`scripts/rebuild.sh` records the source commit next to the installed binary at build time. The CLI reads that marker at startup and in `zfa doctor`, compares it against the enclosing zuraffa worktree's HEAD, and surfaces a warning when they differ. This catches the trap where `~/.local/bin/zfa` is a compiled snapshot that predates a fix in the checkout.

Sources: [lib/src/cli/binary_staleness.dart](lib/src/cli/binary_staleness.dart#L1-L50)

## The Escape Hatch: ZFA_ALLOW_JIT

The single escape hatch is the environment variable `ZFA_ALLOW_JIT=1`. When set exactly to `1`, a `.dart` entrypoint is spawned through the Dart VM and one loud warning line is printed. Any other value — including unset — keeps the compiled-child policy in force. The default is off.

Sources: [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart#L50-L60)

The escape hatch is read in exactly one place: the `commandFor` method. A textual sweep test asserts that no other file in `lib/src` references the constant or the string literal.

Sources: [test/core/no_jit_zfa_spawn_scan_test.dart](test/core/no_jit_zfa_spawn_scan_test.dart#L240-L280)

## The Spawn Site Registry

Eight registered spawn sites must route their children through the service. Each is listed in the sweep test with the reason it is on the list:

| Spawn Site | Role | Uses `commandFor`? |
|------------|------|---------------------|
| `lib/src/plugins/tdd/services/step_runner.dart` | TDD step children (gen / verify-red / make / refactor) | Yes |
| `lib/src/plugins/tdd/services/corpus_step_runner.dart` | Corpus harness children (tdd run / tdd verify) | Yes |
| `lib/src/plugins/tdd/services/pipeline_runner.dart` | Make pipeline children (generation plan steps) | No — runs `entrypoint.executable` directly |
| `lib/src/plugins/tdd/services/refactor_passes.dart` | The refactor build pass | Yes |
| `lib/src/plugins/tdd/services/dream_runner.dart` | Dream-runner zfa children | Yes |
| `lib/src/plugins/tdd/services/differential_ref_runner.dart` | Differential ref worktree children | Yes |
| `lib/src/plugins/tdd/services/replay_runner.dart` | Replayed recorded zfa commands | No — re-anchors recorded command strings onto the compiled path |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | Phase-0 entity orchestration | Yes |

Sources: [test/core/no_jit_zfa_spawn_scan_test.dart](test/core/no_jit_zfa_spawn_scan_test.dart#L35-L60)

## The Sweep Test

`test/core/no_jit_zfa_spawn_scan_test.dart` is a textual drift tripwire, not a compiler. It scans every `.dart` file under `lib/src` (except the service itself) for three pre-policy shapes:

1. A `endsWith('.dart')` ternary that carries a `'dart'` argv — the pattern every rewired site used to have
2. An argv list starting with `'dart'` followed by a zfa entrypoint token
3. Inside a registered spawn site, any `['dart', …]` argv whose first argument is not a Dart-toolchain subcommand (`pub`, `run`, `test`, `compile`, `analyze`, `format`, `fix`, `dartdev`)

The test also asserts that every registered spawn site references the `ZfaExecutable.ensureCompiled` seam, that argv-shaping sites call `ZfaExecutable.commandFor`, and that the `ZFA_ALLOW_JIT` constant is read only by the service.

Sources: [test/core/no_jit_zfa_spawn_scan_test.dart](test/core/no_jit_zfa_spawn_scan_test.dart#L80-L160)

## The Resolution Chain

When a spawn site resolves its entrypoint without an explicit `--zfa-bin` override, it walks a six-tier chain:

1. `Platform.script` when its basename is `zfa.dart` or `zuraffa.dart` (running from the entrypoint directly)
2. `p.join(dirname(Platform.script), 'bin', 'zfa.dart')` — handles compiled-snapshot / global-activate
3. `Isolate.resolvePackageUri` fallback — handles test contexts
4. `Platform.resolvedExecutable` when it is a compiled (non-Dart-VM) executable — the running binary itself
5. The system-installed `zfa` binary, resolved concretely from PATH
6. `Platform.script` as a usable file (compiled snapshot)

VM drivers (`dart run`, `dart test`, a `dartaotruntime` snapshot launch) fail the tier-4 non-VM check and keep the exact order below. The resolved path is then passed through `ensureCompiled`: a source resolution becomes the shared AOT artifact, while an already-compiled binary or a system install is returned unchanged.

Sources: [lib/src/plugins/tdd/services/step_runner.dart](lib/src/plugins/tdd/services/step_runner.dart#L180-L230)

## Failure Mode: Loud, Never Silent

A compile that cannot happen throws `ZfaCompilationException` — non-zero exit, a deadline kill, or a missing output file. The exception carries the exact command line, the exit code, and the last ~20 lines of stderr so the operator can reproduce by hand. There is deliberately no JIT fallback: the degraded path is exactly what the policy exists to remove.

Sources: [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart#L80-L120)

## Test Helper: Shared Cache

`test/helpers/run_zfa_source.dart` shares the same binary cache location (`<sourceRoot>/.dart_tool/zfa_cli_bin/zfa_exe`) with the production path on purpose. Tests and runtime use the same binary, so a warm cache is warm for both. This keeps the test suite hermetic while still exercising the real compile path.

Sources: [test/helpers/run_zfa_source.dart](test/helpers/run_zfa_source.dart#L1-L30)

## Next Steps

For understanding the broader operational context, see:

- [Error Handling & Exit Code Protocol](error-handling-and-exit-code-protocol) — the exit code contract that compiled children must honor
- [Benchmarking & Performance](benchmarking-and-performance) — the performance measurements that motivated this policy
- [TDD Cycle & Spec-Driven Development](tdd-cycle-and-spec-driven-development) — where these spawn sites operate
- [Proof Receipts & Verification Gates](proof-receipts-and-verification-gates) — the receipts children emit

For a higher-level view, return to [Overview](1-overview).