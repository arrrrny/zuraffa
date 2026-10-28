This page walks a beginner through everything needed to get Zuraffa installed, verified, and ready to generate code: prerequisites, adding the package, installing the CLI, creating a fresh project, and validating the environment with `zfa doctor`.

## Prerequisites

Zuraffa v7 requires a modern Dart toolchain and, for Flutter apps, a Flutter SDK installation.

| Requirement | Version / Detail | Verification |
|---|---|---|
| Dart SDK | `^3.11.0` (from `pubspec.yaml` `environment.sdk`) | `dart --version` |
| Flutter SDK | Any Flutter release compatible with the Dart SDK above | `flutter --version` |
| Git | Required for project scaffolding and proof checks | `git --version` |
| (Optional) zorphy CLI | Standalone entity tooling; bundled inside zfa | `dart pub global list` |

Sources: [pubspec.yaml](pubspec.yaml#L20-L22), [README.md](README.md#L55-L75)

## Add Zuraffa to Your Project

Add Zuraffa to both `dependencies` and `dev_dependencies` in `pubspec.yaml`, along with the Zorphy annotation package and build runner.

```yaml
dependencies:
  zuraffa: ^7.2.0

dev_dependencies:
  zuraffa: ^7.2.0
  zorphy_annotation: ^2.4.1
  build_runner: ^2.16.1
```

Then fetch packages:

```bash
dart pub get
```

For Flutter apps, prefer the Flutter-scoped resolver:

```bash
flutter pub get
```

Sources: [README.md](README.md#L55-L68), [pubspec.yaml](pubspec.yaml#L1-L8)

## Install the CLI Globally

Install the `zfa` executable on your PATH so it can be invoked from any project directory:

```bash
dart pub global activate zuraffa
zfa --version
```

The CLI reports its version from `lib/src/version.dart` (currently `7.2.0`). Global activation places the binary in `~/.pub-cache/bin` (or `~/.local/bin` depending on your Dart setup); ensure that directory is on your PATH.

Sources: [README.md](README.md#L64-L70), [lib/src/version.dart](lib/src/version.dart#L1-L2)

## The No-JIT Execution Policy

Zuraffa enforces a strict **No-JIT policy**: every `zfa` child process must be a compiled AOT binary, never `dart bin/zfa.dart` run through the VM interpreter. JIT spawning pays ~20 seconds of cold-start per invocation and can silently run a different source tree than the driver.

For local development inside this repository, use the sanctioned launcher:

```bash
scripts/zfa --help
```

`scripts/zfa` compiles once into `.dart_tool/zfa_cli_bin/zfa_exe` and reuses it while the source is unchanged; it also copies a fresh system binary when available to skip recompilation. `dart bin/zfa.dart` is reserved for `dart test` itself.

If an environment cannot run `dart compile exe`, set the escape hatch:

```bash
ZFA_ALLOW_JIT=1 zfa --help
```

This spawns through the Dart VM and prints a loud warning; any value other than `1` keeps the compiled-child policy in force.

Sources: [scripts/zfa](scripts/zfa#L1-L40), [website/static/docs/23-no-jit-execution-policy.md](website/static/docs/23-no-jit-execution-policy.md#L1-L20), [lib/src/cli/zfa_executable.dart](lib/src/cli/zfa_executable.dart)

## Bootstrap a New Project with `zfa setup`

Instead of wiring dependencies by hand, use `zfa setup` to scaffold a fresh Flutter or Dart project with the Zuraffa dependency set already configured:

```bash
zfa setup my_app --flutter --org=com.example
cd my_app
dart pub get --no-example
```

| Flag | Purpose |
|---|---|
| `--flutter` | Create a Flutter app (default) |
| `--dart` | Create a pure Dart package |
| `--org=com.example` | Organization identifier for Flutter creation |
| `--platforms=ios,android` | Target platforms |
| `--deep-link-scheme=gozuzu` | Pre-seed a URL scheme for deep links |
| `--specs=dir` | Import a spec corpus for TDD from day zero |
| `--dry-run` | Preview without writing files |
| `--no-git` | Skip git initialization |
| `--force` | Delete and recreate the target directory if it exists |
| `--tdd-example` | Emit an additional failing example test |

The setup command performs 9 sequential steps:

1. Creates the app (`flutter create` / `dart create`)
2. Wires zuraffa dependencies into `pubspec.yaml`
3. Creates `build.yaml` + domain directory structure
4. Creates default `.zfa.json`
5. Pre-seeds deep-link scheme (Flutter only)
6. Emits TDD day-zero baseline (Flutter only)
7. Imports spec corpus (if `--specs` provided)
8. Generates app shell (Flutter only)
9. Prints summary + next steps

After setup, the next steps are printed for you:

```text
cd my_app
zfa entity create -n Product --field id:String --field name:String
zfa make Product --preset=crud --with=vpc,state,di,test
zfa build
```

Sources: [lib/src/commands/setup_command.dart](lib/src/commands/setup_command.dart#L33-L144), [README.md](README.md#L76-L93)

## Initialize Project Configuration

For an existing project (or after `zfa setup`), initialize the `.zfa.json` project defaults file:

```bash
zfa config init
```

This creates `.zfa.json` with the clean-architecture stack enabled by default (di, datasource, repository, usecase, mock, test, method_append, route, provider, presenter, controller, cache). Use `--minimal` to start with every plugin disabled and select plugins per command:

```bash
zfa config init --minimal
```

You can inspect or mutate configuration later:

```bash
zfa config show
zfa config set diByDefault true
```

Sources: [lib/src/commands/config_command.dart](lib/src/commands/config_command.dart#L44-L74), [lib/src/config/zfa_config.dart](lib/src/config/zfa_config.dart#L436-L470)

## Verify the Environment with `zfa doctor`

`zfa doctor` inspects the installed tooling, v5 migration readiness, and named environment checks:

```bash
zfa doctor
```

It reports:

- Zuraffa CLI version
- Dart / Flutter installation status
- `.zfa.json` presence and parseability
- `pubspec.yaml` presence and dependency checks (`zuraffa`, `zorphy_annotation`)
- Globally installed `zorphy` CLI (optional)
- Dead-code analysis via `dart analyze`
- v5 migration readiness (state, GQL, DI, controlled-widget detectors)

For machine-readable output suitable for CI, use JSON mode:

```bash
zfa doctor --format=json
```

The named environment checks (`deps`, `generated-imports`, `artifacts`, `baseline-cache`, `config`, `profile`, `binary-staleness`) can be auto-healed:

```bash
zfa doctor --fix
```

Preview heals without writing:

```bash
zfa doctor --dry-run
```

A non-zero exit code indicates at least one check failed after the fix pass.

Sources: [lib/src/commands/doctor_command.dart](lib/src/commands/doctor_command.dart#L44-L120), [lib/src/commands/doctor_checks.dart](lib/src/commands/doctor_checks.dart#L1-L60)

## Binary Staleness Detection

When running an installed `zfa` binary inside a Zuraffa checkout, the CLI compares the binary's build commit (recorded by `scripts/rebuild.sh` as `zfa.build_commit`) against the checkout's `git rev-parse HEAD`. If they differ, a warning is printed:

```text
⚠️ installed zfa (<short>) is older than this checkout (<short>) — run scripts/rebuild.sh
```

Rebuild the system binary to resolve:

```bash
scripts/rebuild.sh
```

This guard prevents the trap where `~/.local/bin/zfa` is older than the source tree you just edited. Staleness is never reported for source runs, missing markers, or non-checkout directories.

Sources: [lib/src/cli/binary_staleness.dart](lib/src/cli/binary_staleness.dart#L1-L60), [scripts/rebuild.sh](scripts/rebuild.sh)

## Build Step

After generation, finalize build outputs with `zfa build` instead of calling `build_runner` directly. It ensures `build.yaml` registers the zorphy builder, runs the slang codegen stage when i18n sources exist, and runs `dart analyze` by default:

```bash
zfa build
```

Useful flags:

| Flag | Purpose |
|---|---|
| `--clean` | Delete the build cache before building |
| `--force` | Regenerate all files from scratch |
| `--no-analyze` | Skip post-build `dart analyze` |
| `--dry-run` | Preview without invoking build_runner |

Sources: [lib/src/commands/build_command.dart](lib/src/commands/build_command.dart#L40-L120)

## Environment Variables

| Variable | Effect |
|---|---|
| `ZFA_ALLOW_JIT=1` | Escape hatch allowing JIT execution (any other value keeps compiled-child policy) |
| `ZFA_NO_REBUILD=1` | Fail instead of recompiling when no fresh system binary is available |

Sources: [scripts/zfa](scripts/zfa#L1-L40), [website/static/docs/23-no-jit-execution-policy.md](website/static/docs/23-no-jit-execution-policy.md#L80-L90)

## Troubleshooting

| Symptom | Likely Cause | Remediation |
|---|---|---|
| `zfa: command not found` | Global activation bin dir not on PATH | Add `~/.pub-cache/bin` (or `~/.local/bin`) to PATH; re-run `dart pub global activate zuraffa` |
| `No .zfa.json found` | Project not initialized | Run `zfa config init` or `zfa setup` |
| `Zuraffa package not found` | Missing dependency | Add `zuraffa` to `pubspec.yaml` and run `dart pub get` |
| `zorphy_annotation not found` | Missing annotation package | `dart pub add zorphy_annotation` |
| Stale behavior after editing source | Installed binary older than checkout | Run `scripts/rebuild.sh` |
| `build_runner` writes 0 outputs | `build.yaml` missing zorphy builder registration | Run `zfa build` (self-healing preflight) or `zfa doctor --fix` |
| Missing TDD dev-deps | Fresh clone without dev dependencies | `zfa doctor --fix` (installs mocktail/coverage/mutation_test) |

Sources: [lib/src/commands/doctor_command.dart](lib/src/commands/doctor_command.dart#L160-L200), [lib/src/commands/doctor_checks.dart](lib/src/commands/doctor_checks.dart#L1-L60)

## Reading Progression

Continue with these pages to move from installation to your first generated architecture:

- [Overview](1-overview) — What Zuraffa is and its core systems
- [Quick Start](2-quick-start) — From blank terminal to compilable architecture
- [Canonical CLI Workflow](4-canonical-cli-workflow) — The `entity create → make → build` pipeline in depth
- [Project Layout & Fixed Architecture Root](5-project-layout-and-fixed-architecture-root) — The fixed `lib/src` structure
- [Configuration & Project Memory](6-configuration-and-project-memory) — `.zfa.json` and `.zfa/` in detail
- [Running Tests & Local CI](7-running-tests-and-local-ci) — Test execution and CI integration