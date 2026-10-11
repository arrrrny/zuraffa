# Issue #1690 — companions (#1678 follow-up): fix the delegate's path-dep + hosted compile seams

- **GitHub issue**: arrrrny/zuraffa#1690 (open)
- **Severity**: high
- **Slug**: 1690-companion-seams
- **Scope for this PR**: §1 and §2 only — the two pre-publish blockers.
  §3 (capability scaffold) and §4 (repo splits) are separate follow-up
  workstreams.

## §1 — Bug: `companionEntry` mis-resolves relative `rootUri`s (breaks the documented `path:` install)

`PluginGate.companionEntry` resolves the companion's `bin/<pkg>.dart` with

```dart
final packageRoot = Directory(
  rootUri.startsWith('file://') ? rootUri.substring(7) : rootUri,
).absolute.path;
```

`Directory(...).absolute` anchors a relative path at `Directory.current`.
pub writes:

- absolute `file://` URIs for hosted deps (and for absolute `path:` deps)
  — resolves fine today;
- **relative** URIs for relative `path:` deps (e.g.
  `../../packages/zuraffa_graphql`), anchored at the **package_config's
  own directory** (`.dart_tool/`).

**Repro** (branch tree, real `dart pub get`, the exact shape
`packages/zuraffa_graphql/README.md` documents):

```yaml
dependencies:
  zuraffa:
    path: ..
  zuraffa_graphql:
    path: ../packages/zuraffa_graphql
```

→ `package_config.json`: `zuraffa_graphql -> ../../packages/zuraffa_graphql`
(relative) → `PluginGate.companionEntry('graphql')` with CWD = the project
root → **`null`** → `zfa graphql generate` refuses: *"zuraffa_graphql is
resolvable but its bin entry is missing"* after a completely correct
install.

The delegation e2e (`test/graphql/graphql_generate_delegation_e2e_test.dart`)
masked this by hand-writing an absolute `file://` rootUri, so no test
covered the relative shape.

**Fix**: anchor relative `rootUri`s at `p.dirname(packageConfig.path)`;
add a pin whose fixture keeps the relative rootUri with CWD at the
project root.

## §2 — Bug: hosted companions compile through an implicit `pub get` inside the pub cache

`ZfaExecutable.ensureCompiled(entry)` derives its `sourceRoot` from the
candidate's own package root (`_packageRootAbove`). For a hosted install
that root is `~/.pub-cache/hosted/pub.dev/<pkg>-<v>/` — a directory with
a `pubspec.yaml` but no `.dart_tool/package_config.json` — so
`dart compile exe` runs Dart's **implicit `pub get` inside the pub
cache**.

Verified on a real cache entry (`archive-3.6.1`): the compile created
`.dart_tool/` + `pubspec.lock` inside
`~/.pub-cache/hosted/pub.dev/archive-3.6.1/`.

Consequences for a hosted companion: the first `zfa graphql generate`
needs network, mutates the shared pub cache, and the child compiles
against its own freshly-resolved `zuraffa` rather than the project's.

**Fix**: compile against the consuming project's package config —
`dart compile exe --packages=<project>/.dart_tool/package_config.json` is
supported (verified) — i.e. thread the project config (or a project-root
CWD) through the delegate → `ZfaExecutable`, and key the compile cache
per project.

## Hard constraints

1. resolve relative rootUris correctly with a regression pin;
2. compile hosted companions against the project's package config with
   per-project cache keying;
3. do not break absolute/`file://` rootUri resolution;
4. do not mutate the shared pub cache during hosted compile.
