# Fix — 1690-companion-seams

- **Fixed**: 2026-09-18
- **Branch**: fix/1690-companion-seams
- **Scope**: §1 + §2 only.

## §1 — relative `rootUri` anchoring (`lib/src/plugins/plugin_gate/plugin_gate.dart`)

- `companionEntry` now resolves the `rootUri` through
  `_resolvePackageRoot(rootUri, configPath: file.path)`:
  - `file://` URIs strip the prefix and normalize (unchanged behavior);
  - RELATIVE URIs anchor at `p.dirname(packageConfigPath)` — the
    package_config's own directory, where pub anchors them — and
    normalize. `Directory.current` is no longer consulted.
- New `packageConfigPath({String? projectRoot})` helper exposes the
  project's `.dart_tool/package_config.json` path (used by the delegate
  for §2).

## §2 — project-anchored hosted compile (`lib/src/cli/zfa_executable.dart`)

- `ZfaEnsureCompiled` / `ensureCompiled` gain an optional named
  `packagesFile` parameter (existing fakes stay assignable — fewer
  optional named params remain a subtype).
- `_compileCached(projectConfig: …)`:
  - argv gains `--packages=<project config>` before the candidate;
  - cache dir becomes `<projectRoot>/.dart_tool/zfa_cli_bin/`
    (`kZfaBinaryCacheDir` joined on the project root — the config's
    grandparent directory), so nothing is written into a hosted
    pub-cache package;
  - exe slot digests `<candidate>|<projectConfig>` — per-project keying;
  - `_isStale` treats the project `package_config.json` as a staleness
    input (null-aware element).
- Without `packagesFile`, every path is byte-for-byte legacy (canonical
  `zfa_exe` slot, source-root cache, no `--packages`).

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
