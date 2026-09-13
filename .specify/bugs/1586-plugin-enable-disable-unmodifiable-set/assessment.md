# Assessment — #1586 `zfa plugin enable`/`disable` crashes: the unmodifiable disabled set is passed by reference and mutated in place

Date: 2026-09-13
Branch: `fix/1586-plugin-enable-disable-unmodifiable-set`
Scope: the set ownership at the `PluginConfig` boundary ONLY — `lib/src/cli/plugin_loader.dart` (constructor + the await discipline of its save caller in `lib/src/commands/plugin_command.dart`). No config-format, save-pipeline, or registry-builder edits.

## Evidence (reproduced on pristine master)

A freshly scaffolded project (`zfa setup calculator --dart --no-git`,
`.zfa.json` present, `plugins.disabled: []`):

```
$ zfa plugin enable state
❌ Error: Unsupported operation: Cannot change an unmodifiable set
--> fix: re-run with --verbose to capture the stack trace, then run `zfa doctor`
(exit 1)

$ zfa plugin disable state
❌ Error: Unsupported operation: Cannot change an unmodifiable set
(exit non-zero)

$ zfa plugin list | wc -l
31        # all 31 ids hit the same path
```

Because the unmodifiable view is installed by the `ZfaConfig`
constructor for EVERY loaded config (even with an empty `disabled`
array), the crash is unconditional in any project that has a
`.zfa.json` — 31/31 ids, both directions.

## Root cause

An ownership bug, not a data-structure bug. The set's lifecycle:

1. **`ZfaConfig` constructor (`zfa_config.dart:124`)** wraps the loaded
   array in `Set.unmodifiable(...)` — correct and intentional; the
   config object is a value-like snapshot and its immutability contract
   is guarded by tests (`zfa_config_test.dart`).
2. **`PluginConfig.load()` (`plugin_loader.dart:46-49`)** passes
   `config?.disabledPlugins` into `PluginConfig(disabled: ...)`, whose
   initializer is `disabled = disabled ?? {}` — a pure aliasing
   assignment. `PluginConfig` therefore does NOT own its `disabled`
   set; it holds a reference to the config snapshot's frozen view.
   Note the aliasing also leaks in the opposite direction:
   `PluginConfig(disabled: someMutableSet)` aliases the caller's set.
3. **`plugin_command.dart:51/53`** — the `enable`/`disable` arms mutate
   the set in place (`remove`/`add`) and then call `config.save()`.
   The mutation is the documented contract of the command ("removes the
   id from the disabled set"), so the defensible fix point is the
   ownership boundary, not the mutator.

Two failure classes fall out:

- **Class A (the reported crash)**: any mutation of the aliased
  unmodifiable view throws `Unsupported operation: Cannot change an
  unmodifiable set` → the command exits non-zero, config untouched.
- **Class B (found during the fix cycle, persisted-state variant)**:
  once Class A is fixed, the save silently loses the mutation in the
  real CLI: `PluginConfig.save()` was `void` and did not await the
  async `ZfaConfig.save` (`FileUtils.writeFile` pipeline), while
  `_runDispatched` (`cli_runner.dart:397-398`) calls `_exit(exitCode)`
  immediately after the command future resolves. `exit()` kills the
  pending write before the bytes land — `enable`/`disable` printed
  success and exited 0 but `.zfa.json` was unchanged. Verified
  empirically: `disable state` → `plugins.disabled` stayed `[]`.
  The established pattern elsewhere (`config_command.dart:90`) awaits
  the same call; the issue's Expected clause ("saves `.zfa.json`")
  makes awaiting in-scope for this bug.

## Fix contract (what the pins demand)

1. `PluginConfig` OWNS a mutable copy of the set taken at the
   constructor — `Set.of(disabled ?? const <String>{})` — so mutation
   never touches the `ZfaConfig` snapshot and never aliases a caller's
   set (defensive copy, both directions).
2. `ZfaConfig.disabledPlugins` STAYS an unmodifiable view — the fix
   must not weaken the config snapshot's immutability contract.
3. The mutated set must be durably persisted by the time the command
   returns: `PluginConfig.save()` exposes its future, the command
   awaits it. Same pipeline (`load existing → copyWith → ZfaConfig.save`),
   same file format.
4. `PluginLoader.buildRegistry()` / `listPlugins()` keep reading the
   same set — no registry-builder changes.

## Constraints audit

- Config format: unchanged (`toJson` untouched; persisted bytes identical).
- Save logic: unchanged pipeline; only the await discipline fixed (see Class B).
- Registry builder: untouched.
- `dart analyze`: no new warnings (verified on the changed files + test file).
