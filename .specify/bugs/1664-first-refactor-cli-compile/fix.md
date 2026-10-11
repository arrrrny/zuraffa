# Bug Fix: first refactor after every master bump pays a one-time ~85s dart compile exe of the zfa CLI — even when the parent runs from a current installed binary

- **Slug**: 1664-first-refactor-cli-compile
- **Fixed**: 2026-09-15 (this session)
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ../tdd/test-list.md, ../tdd/verification.md, ./red-evidence.md

## Summary

The child binary resolution seam (`ZfaExecutable.ensureCompiled` →
`_compileCached`) now prefers a compiled install proven current for the
candidate's source tree over an unconditional AOT compile. When the compile
cache is missing or stale AND the RUNNING process is itself a compiled
(non-Dart-VM) executable whose `<install-dir>/zfa.build_commit` equals the
candidate source root's `git rev-parse HEAD`, the running binary is returned
for children instead of compiling — it IS the artifact the compile would
rebuild (same source commit). Every unprovable input (VM driver, no/empty
marker, git failure, commit mismatch, non-canonical `--zfa-bin` candidate)
fails open to the exact pre-fix compile path, and a marker that disagrees
with the checkout HEAD is precisely the stale-reuse guard the acceptance
criteria demand.

Remedy 1 from the issue ("prefer the running binary — extend #1643 to the
current case"), implemented at the compile choke point so every resolution
path is covered: the observed compile argv (`dart compile exe
<checkout>/bin/zfa.dart --output <checkout>/.dart_tool/zfa_cli_bin/zfa_exe.tmp`)
is `_compileCached`'s exact shape, and StepRunner / PipelineRunner /
`zfaBuildCommand` / the phase-0 driver / the dream, replay and differential
runners all funnel their `.dart` resolutions through it. `scripts/rebuild.sh`
wipes `<checkout>/.dart_tool` on every install, which is why the cache-miss
— and therefore the ~85s cost — recurred on the first refactor after every
master bump.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/cli/zfa_executable.dart` | modified | New public injectable probe `ZfaExecutable.currentInstalledBinary({candidate, sourceRoot, runningExecutable, runner})`: canonical-entrypoint check → VM-executable exclusion → marker read (`zfaBuildCommitMarker` imported from `binary_staleness.dart`, no constant duplicated) → `git rev-parse HEAD` in the source root → strict full-SHA equality; returns the running executable or null. New `_compileCached` wiring: probe consulted AFTER the fresh-cache check (steady state byte-for-byte unchanged) and BEFORE the build lock. New `_defaultGitProbe` runner — deliberately separate from the compile runner so a compiler fake's recorded argv never includes the probe's git argv. Library doc gains the #1664 contract paragraph. No existing method signature changed; the refactor pass logic, the build-relevance gate, and the CLI entry point are untouched. |
| `test/cli/zfa_executable_1664_installed_binary_reuse_test.dart` | added | The #1664 suite: U-1664-b1 (the bug: current installed binary reused for the canonical candidate — probe argv/cwd contract pinned), b2 (stale marker forbids reuse — criterion 3), b3 (VM driver never reuses), b4/b5 (no/empty marker unprovable), b6 (git failure fail-open), b7 (non-canonical fixture never reuses), b8 (missing exe), b9 (VM-driven cache miss still compiles; the compile runner never sees a git argv). |

## Diff Highlights

The behavioral core — the would-compile moment consults the running binary:

```dart
if (exeFile.existsSync() && !_isStale(exeFile, candidate, sourceRoot)) {
  return exePath;                       // steady state: cache wins first
}

// Issue #1664: cache miss/stale — the moment the old path paid the
// one-time ~85s dart compile exe after every master bump.
final installed = await currentInstalledBinary(
  candidate: candidate,
  sourceRoot: sourceRoot,
  runningExecutable: Platform.resolvedExecutable,
);
if (installed != null) return installed; // proven-current install, no compile

await cacheDir.create(recursive: true);  // ...otherwise compile as before
```

The reuse guard (acceptance criterion 3 — strict, fail-open):

```dart
if (!_isCanonicalEntrypoint(candidate, sourceRoot)) return null;
if (_isVmExecutablePath(runningExecutable)) return null;   // dart*/flutter_tester
if (!exe.existsSync()) return null;
commit = marker.readAsStringSync().trim();                 // zfa.build_commit
if (commit.isEmpty) return null;
head = '${result.stdout}'.trim();                          // git rev-parse HEAD
if (result.exitCode != 0 || head.isEmpty) return null;
return commit == head ? exe.path : null;                   // strict full-SHA
```

## Soundness notes

- **Fresh-cache-first ordering** keeps criterion 4: a warm cache (mtime
  `_isStale`) is returned exactly as before; the probe only fires on the
  would-compile path, and for a VM driver it rejects before any I/O.
- **Differential worktrees** (`DifferentialRefRunner` compiles a ref
  worktree's `bin/zfa.dart`): the worktree HEAD differs from the marker in
  every interesting case → compile as before; when a worktree IS at the
  marker commit the reuse is semantically identical (same source).
- **Uncommitted checkout edits**: the fresh-cache verdict still wins first;
  on a stale cache with a matching marker the issue prescribes the
  commit-equality trade explicitly (".build_commit comparison prevents
  stale binary reuse").
- **`scripts/zfa` parents** (`.dart_tool/zfa_cli_bin/zfa_exe`): no
  `zfa.build_commit` marker next to that artifact → probe null → compile
  path unchanged.
