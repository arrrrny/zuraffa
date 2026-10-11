# RED Evidence — 1690-companion-seams

- **Date**: 2026-09-18
- **Dart SDK**: 3.13.4 (stable)
- **Branch**: fix/1690-companion-seams

## §1 — relative rootUri mis-resolution (PluginGate.companionEntry)

Command: `dart test test/plugins/plugin_gate/plugin_gate_test.dart`

```
00:00 +7 -2: Some tests failed.

Failing tests:
  U7: a RELATIVE rootUri anchors at the package_config directory —
      with CWD at the project root (the documented path: install)
  U7: a relative rootUri still resolves when CWD is unrelated to the
      project (no reliance on Directory.current)

Expected: '/tmp/gate_u7_companion_PJIXDZ/bin/zuraffa_graphql.dart'
  Actual: <null>
```

RIGHT reason: `companionEntry` returns **null** for the relative-rootUri
shape pub writes for relative `path:` deps (the exact bug — `Directory(
...).absolute` anchors the relative URI at `Directory.current`, the
companion's `bin/` entry is not found there). The absolute `file://`
guard and the missing-bin guard pass pre-fix (no regressions pinned).

## §2 — hosted compile anchors inside the candidate's own package root

Command: `dart test test/cli/zfa_executable_test.dart --plain-name "U12"`
(after a pass-through stub for the new `packagesFile` param — the API
error RED — to capture the honest behavioral RED)

Observed compiler argv (from the U12d failure output, identical shape in
U12a/b):

```
['dart', 'compile', 'exe',
 '/tmp/zfa_companion_stale_…/bin/zuraffa_graphql.dart',
 '--output',
 '/tmp/zfa_companion_stale_…/.dart_tool/zfa_cli_bin/zfa_exe_22ebf738.tmp']
```

RIGHT reason — the argv proves all four defect facets:
1. **No `--packages=` flag** (U12a) → the compile resolves packages from
   the candidate's own root; for a hosted install that root is
   `~/.pub-cache/hosted/pub.dev/<pkg>-<v>/` (pubspec.yaml, no
   `.dart_tool/package_config.json`) → Dart's implicit `pub get` inside
   the shared pub cache (verified on archive-3.6.1 per the issue).
2. **Artifact written inside the candidate source root** (U12b) → the
   compiled binary mutates the pub-cache package dir.
3. **Same slot for two different projects** (U12c) → no per-project
   cache keying; one project's binary is reused by another.
4. **A rewritten project package config does not invalidate** (U12d) →
   the cache survives `pub upgrade` in the consuming project.

U12e (legacy contract without `packagesFile`) passes pre-fix and must
keep passing.
