# Issue — #1586 `zfa plugin enable`/`disable` crashes — "Cannot change an unmodifiable set" in every project with `.zfa.json`

## Reproduction (fresh scaffold, reproduced on this branch's base)

```bash
zfa setup calculator          # scaffolding creates .zfa.json
cd calculator
zfa plugin enable state
# ❌ Error: Unsupported operation: Cannot change an unmodifiable set
--> fix: re-run with --verbose to capture the stack trace, then run `zfa doctor`
# exit 1; .zfa.json not written
```

All 31 plugin ids reported by `zfa plugin list` fail the same way
(31/31). `zfa plugin disable <id>` walks the same mutation path and is
equally broken. The crash requires `.zfa.json` to exist: a directory
without one falls back to `PluginConfig`'s mutable `{}` default and
works — which is why every unit test that runs in a bare temp dir
missed it while every real project hits it.

## Root cause (three hops, each correct in isolation)

1. `lib/src/config/zfa_config.dart:124` — `ZfaConfig` stores the set as
   an **unmodifiable view**:

   ```dart
   disabledPlugins = Set.unmodifiable(disabledPlugins ?? const <String>{}),
   ```

2. `lib/src/cli/plugin_loader.dart:44` — `PluginConfig.load()` hands
   that set through **by reference**:

   ```dart
   PluginConfig({Set<String>? disabled}) : disabled = disabled ?? {};
   ```

3. `lib/src/commands/plugin_command.dart:51/53` — the command
   **mutates** it:

   ```dart
   if (action == 'enable') {
     config.disabled.remove(id);   // :51 — throws
   } else {
     config.disabled.add(id);      // :53 — throws
   }
   ```

## Expected

`zfa plugin enable <id>` removes the id from the disabled set, saves
`.zfa.json`, prints `Enabled plugin: <id>`, exit 0.

## Impact

`zfa plugin list | enable | disable` is the documented plugin-management
surface, and "enable all plugins in the new project" is a standard step
of the golden-path setup flow. On every fresh app the step fails every
single time, with a fix hint (`run zfa doctor`) that does not apply.
Related defaults-policy problem tracked separately in #1496.
