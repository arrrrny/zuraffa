# Assessment — 1690-companion-seams

- **Assessed**: 2026-09-18
- **Inputs**: GitHub issue #1690 (§1 + §2), the sources below, and the
  existing tests that masked the seams.
- **Scope**: §1 + §2 only (the two pre-publish blockers). §3 (scaffold)
  and §4 (repo splits) are explicitly OUT of this PR.

## §1 — `PluginGate.companionEntry` mis-resolves relative `rootUri`s

**Affected**: `lib/src/plugins/plugin_gate/plugin_gate.dart`
(`companionEntry`, the delegate path of `zfa graphql generate`).

**Root cause**: the resolution handed the raw `rootUri` to
`Directory(...).absolute`. Package_config v2 anchors RELATIVE `rootUri`s
at the config file's own directory (`<project>/.dart_tool/`) — pub
writes exactly that shape for relative `path:` deps, the documented
companion install (`packages/zuraffa_graphql/README.md`). `absolute`
anchored them at `Directory.current` instead. With CWD at the project
root (the user's terminal shape), `<CWD>/../../packages/zuraffa_graphql`
does not exist → `companionEntry` returned null → the delegate refused
with "bin entry is missing" after a correct install.

**Why tests missed it**: `test/graphql/graphql_generate_delegation_e2e_test.dart`
hand-wrote an absolute `file://` rootUri in its fixture; the gate unit
suite never exercised `companionEntry` against a relative shape.

**Remediation**: resolve through `p.join(p.dirname(packageConfigPath),
rootUri)` for relative URIs (normalized), keep `file://` stripping for
absolute URIs (constraint 3), and pin the relative shape at unit level
with CWD deliberately moved away from the project (proves
`Directory.current` is not consulted).

## §2 — `ZfaExecutable.ensureCompiled` compiles inside the candidate's own package root

**Affected**: `lib/src/cli/zfa_executable.dart` (`ensureCompiled` →
`_compileCached`), the delegate call site
`lib/src/commands/graphql_command.dart`.

**Root cause**: `sourceRoot` is derived from the candidate
(`_packageRootAbove`). For a hosted companion that is
`~/.pub-cache/hosted/pub.dev/<pkg>-<v>/`: a `pubspec.yaml`, no
`.dart_tool/package_config.json`. The compile ran as
`dart compile exe <candidate> --output <tmp>` with
`workingDirectory: sourceRoot` → Dart's implicit `pub get` fired INSIDE
the pub-cache package dir (verified upstream on archive-3.6.1):
network dependency on first run, shared-cache mutation, and the child
compiled against its own freshly-resolved `zuraffa` instead of the
project's. The compile artifact was also written into
`<sourceRoot>/.dart_tool/zfa_cli_bin/` — inside the shared cache — with
a slot keyed by the candidate alone, so two consuming projects would
share one binary.

**Remediation**:
1. `ensureCompiled` grows an optional `packagesFile` parameter; the
   delegate threads `PluginGate.packageConfigPath()` (the project's
   `.dart_tool/package_config.json`).
2. With `packagesFile` present, the argv carries
   `--packages=<project config>` (supported by `dart compile exe`,
   verified in the issue) — package resolution comes from the consuming
   project; no implicit `pub get` anywhere (constraint 4).
3. The artifact moves to the PROJECT's cache
   (`<project>/.dart_tool/zfa_cli_bin/`, the same `kZfaBinaryCacheDir`
   layout joined on the project root) under a slot that digests
   candidate AND project config — per-project keying (constraint 2).
4. Staleness treats a rewritten `package_config.json` as invalidating
   (`pub get` rewrites it on every resolve).
5. No `packagesFile` → byte-for-byte legacy behavior (the canonical
   `<sourceRoot>/.dart_tool/zfa_cli_bin/zfa_exe` contract with
   `scripts/zfa` / `test/helpers/run_zfa_source.dart` is untouched —
   pinned by U12e).

**Call-site scope**: only the companion delegate
(`graphql_command.dart`) threads `packagesFile`. The TDD/corpus/refactor
runners compile the CORE zfa binary (sourceRoot = the driving tree) and
keep the legacy path — minimal change, no behavior drift elsewhere.

**Delegate race note**: the gate proves the config exists
(`isResolvable` reads it) before the delegate runs; if it vanished
mid-run, the delegate refuses with a `--> fix: dart pub get` line
instead of silently falling back to the pub-cache-mutating seam.

## E2e fixture upgrade

The delegation e2e now performs the DOCUMENTED install: a real
`dart pub get` in a temp project whose pubspec carries relative `path:`
deps to the core and the companion. The fixture's package_config is
pub's genuine output (relative rootUris, asserted), closing the masking
gap that hid §1, and flow-level pins assert the artifact landed in the
PROJECT cache and that nothing was written into the companion package.
