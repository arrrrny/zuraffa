# TDD verification — #1586 PluginConfig owns a mutable disabled set

**FRESH RUN RECORD — all evidence below is from real executions on this
branch (`fix/1586-plugin-enable-disable-unmodifiable-set`), Dart SDK
3.13.3 (stable), 2026-09-13. Nothing here is asserted from memory.**

## 1. Cycle summary (red → green → verify)

| phase | command | result |
| ----- | ------- | ------ |
| RED (unit) | `dart test test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart` (pre-fix tree) | `+0 -4: Some tests failed` — A-1586-1/2/3 threw `Unsupported operation: Cannot change an unmodifiable set` (`_UnmodifiableSetMixin.remove`); A-1586-4 failed on the aliasing leak; guard A-1586-5 green |
| RED (CLI) | compiled `bin/zfa.dart` → `zfa plugin enable state` / `disable state` in a scaffolded `zfa setup calculator --dart` project | `❌ Error: Unsupported operation: Cannot change an unmodifiable set`, exit non-zero, `.zfa.json` unwritten; `zfa plugin list` = 31 ids, all affected |
| GREEN (fix) | `Set.of` ownership copy + awaited save (see `../fix.md`) | `00:00 +5: All tests passed!` |
| GREEN (CLI) | recompiled binary, same fixture | `Disabled plugin: state` → `.zfa.json` `["state"]`; `Enabled plugin: state` → `[]`; 31/31 enable+disable sweep, all persisted |
| verify | analyze + sibling tests + chunked fast suite + format | see below |

## 2. Static analysis (post-fix)

```
$ dart analyze lib/src/cli/plugin_loader.dart lib/src/commands/plugin_command.dart
No issues found!

$ dart analyze test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart
No issues found!
```

Final clean-state re-run after `dart format .` (identical result).

## 3. Targeted suites (post-fix)

```
$ dart test test/cli/plugin_loader_test.dart \
            test/commands/plugin_command_add_test.dart \
            test/commands/plugin_command_mcp_test.dart \
            test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart
00:01 +13: All tests passed!
```

(The sibling tests for the two changed lib files: the repo's test tree
maps `plugin_command.dart` → `plugin_command_add_test.dart` +
`plugin_command_mcp_test.dart`; `plugin_loader.dart` → `test/cli/`.)

## 4. Chunked fast suite — FULL RUN, zero failures

Environment note honored (dart_test.yaml header): a single-invocation
`dart test test` compiles a ~6.5 GB kernel cache that overflows small
disks, so the fast suite ran through the repo's disk-safe chunked
protocol (`tools/run_tests_chunked.sh` semantics: per-folder
`dart test <dir> --exclude-tags flutter`, kernel caches cleared between
chunks). A detached first attempt died at chunk 2; the run was resumed
and completed chunk-by-chunk in the foreground.

**Final tally — 104/104 chunks, 99 PASS, 5 SKIP, 0 FAIL:**

- PASS: 99 chunks (every fast-tier test in the repo, including
  `test/agent` +240, `test/cli`, `test/commands`, all `test/plugins/*`,
  `test/core/*`, `test/config`, `test/regression`-tagged fast rows, …)
- SKIP: 5 chunks (`benchmark`, `property`, and 3 slow-tier-only
  folders — every test in them carries a slow-tier tag excluded by
  design; the runner's documented "skip, not a failure" class)
- FAIL: none → **NO NEW failures introduced by the fix** (zero at all)

Slow tiers (`--preset=all`: regression/integration/property/benchmark)
were deliberately NOT run — per dart_test.yaml they spawn temp projects
with `dart pub get` + `build_runner` and fill several GB under /tmp,
"never use them on small/disposable agents".

## 5. Format + final diff hygiene

```
$ dart format .
Formatted 2782 files (1 changed)   ← only the new test file; repo was clean

$ git status --porcelain
 M lib/src/cli/plugin_loader.dart
 M lib/src/commands/plugin_command.dart
?? .specify/bugs/1586-plugin-enable-disable-unmodifiable-set/
?? test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart
```

No unrelated files touched. Kernel caches cleaned after the final runs.

## 6. Verdict

The crash is dead at both the unit boundary and the real-CLI surface
(31/31 ids, both directions, persistence proven by post-invocation JSON
parse of `.zfa.json`), the full fast suite is green, analysis is clean,
and the only bytes that changed are the two production files documented
in `../fix.md` plus the new test and bug artifacts.
