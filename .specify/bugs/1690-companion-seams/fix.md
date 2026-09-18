# Fix — 1690-companion-seams

- **Fixed**: 2026-09-18
- **Branch**: fix/1690-companion-seams
- **Scope**: §1 + §2 only.

## §1 — relative `rootUri` anchoring (`lib/src/plugins/plugin_gate/plugin_gate.dart`)

- `companionEntry` now resolves the `rootUri` through
  `_resolvePackageRoot(rootUri, configPath: file.path)`:
  - the URI is PARSED (`Uri.parse` + `toFilePath`) — percent-escapes
    decode (`../my%20companion/` → `../my companion/`) and a
    `file://` value maps to a real path (a non-empty authority is
    dropped; POSIX `toFilePath` refuses it);
  - RELATIVE URIs anchor at `p.dirname(packageConfigPath)` — the
    package_config's own directory, where pub anchors them — and
    normalize. `Directory.current` is no longer consulted.
- New `packageConfigPath({String? projectRoot})` helper exposes the
  project's `.dart_tool/package_config.json` path (used by the delegate
  for §2).

## §2 — project-anchored hosted compile (`lib/src/cli/zfa_executable.dart`)

- `ZfaEnsureCompiled` / `ensureCompiled` gain an optional named
  `packagesFile` parameter. An implementation of a function type with
  named parameters must accept EVERY named parameter the type declares,
  so every existing fake had to grow the parameter — the earlier note here
  claimed the reverse, and the six-file analyzer scope hid the 19
  `argument_type_not_assignable` errors it left in `test/plugins/tdd/`
  (CI `analyze` / `dart_core` / the manifest conformance job were red).
  The fakes now carry it and `dart analyze lib test bin` is clean.
- `_compileCached(projectConfig: …)`:
  - argv gains `--packages=<project config>` before the candidate;
  - `currentInstalledBinary` is NOT probed when `packagesFile` is set:
    the installed binary was built against the source root's own graph,
    so reusing it would bypass `--packages=` and leave no project-local
    artifact;
  - cache dir becomes `<projectRoot>/.dart_tool/zfa_cli_bin/`
    (`kZfaBinaryCacheDir` joined on the project root — the config's
    grandparent directory), so the ARTIFACT is never written into a
    hosted pub-cache package;
  - exe slot digests `<candidate>|<projectConfig>` — per-project keying;
  - `_isStale` treats the project `package_config.json` as a staleness
    input (null-aware element).
- Without `packagesFile`, every path is byte-for-byte legacy (canonical
  `zfa_exe` slot, source-root cache, no `--packages`).

### §2 residual — the entrypoint's own package root (upstream SDK behavior)

`dart compile exe --packages=<config>` decides which config the COMPILER
reads; it does not stop the SDK from resolving the ENTRYPOINT's own
package root. With a candidate package dir that carries a `pubspec.yaml`
and no up-to-date `.dart_tool/package_config.json` (exactly the pub-cache
shape), the compile still creates `.dart_tool/package_config.json`,
`.dart_tool/package_graph.json` and `pubspec.lock` inside that directory
(reproduced on Dart 3.13.3; `dart compile exe --help` exposes no switch
for it, and the behavior is CWD-independent). So constraint 4 is met for
the ARTIFACT and for the package graph the child compiles against, but
NOT for the SDK's own candidate-root resolve — that one is upstream and
needs an SDK fix to remove. The delegation e2e pins the actual behavior
instead of asserting a no-mutation contract the SDK cannot honor.

## Delegate wiring (`lib/src/commands/graphql_command.dart`)

- `_GenerateDelegateCommand.run()` threads
  `packagesFile: PluginGate.packageConfigPath()` into
  `ZfaExecutable.ensureCompiled`, and refuses with a
  `--> fix: run 'dart pub get' in this project` line when the config is
  missing (mid-run race) instead of falling back to the implicit-pub-get
  seam.

## Explicitly NOT done (out of scope per the issue)

- §3 capability scaffold, §4 repo splits.
- No changes to the TDD/corpus/refactor runner compile paths (they
  compile the core binary; legacy contract holds).
