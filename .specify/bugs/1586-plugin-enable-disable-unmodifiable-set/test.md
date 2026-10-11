# Test — #1586 PluginConfig owns a mutable disabled set (red → green)

## Suite

`test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart`
(fast tier — hermetic unit pins against a real temp project root via
`ZfaConfig.save`/`PluginConfig.load(projectRoot:)`; no CWD games, no
Flutter). Five pins:

| id | pin | assertion |
| -- | --- | --------- |
| A-1586-1 | the #1586 crash, enable arm | `PluginConfig.load(projectRoot:)` from a config with an EMPTY disabled array (the fresh-scaffold shape) → `config.disabled.remove('state')` (the exact `plugin_command.dart:51` mutation) returns normally |
| A-1586-2 | the #1586 crash, disable arm | load from a config with a NON-EMPTY disabled array → `config.disabled.add('state')` (the exact `:53` mutation) returns normally |
| A-1586-3 | the round trip / persistence contract | mutate + `await config.save()` → the persisted `plugins.disabled` array reflects the mutation; a fresh `PluginConfig.load` sees it (guards the Class-B fire-and-forget-save loss) |
| A-1586-4 | the defensive-copy contract | `PluginConfig(disabled: callerSet)` must not alias the caller's set — mutating the copy never leaks back |
| A-1586-5 | the must-not-break guard | `ZfaConfig.load().disabledPlugins` STILL throws on mutation — the fix must not weaken the config snapshot's immutability contract |

## RED (pre-fix working tree = pristine master behavior)

```
dart test test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart
→ 00:00 +0 -4: Some tests failed.

Failing:
  A-1586-1 ... returns normally
     Actual: <Closure> threw:
       Unsupported operation: Cannot change an unmodifiable set
       dart:collection  _UnmodifiableSetMixin.remove
  A-1586-2 ... returns normally
     Actual: <Closure> threw: Unsupported operation: Cannot change an unmodifiable set
  A-1586-3 ... [E]
     Unsupported operation: Cannot change an unmodifiable set
     dart:collection  _UnmodifiableSetMixin.remove
  A-1586-4 ... [E]
     Expected: not contains 'state'
       Actual: Set:['route', 'state']
     PluginConfig must own a copy, not alias the caller set

Passing: A-1586-5 (the guard — red for the right reasons: exactly the
four defect pins are red, the immutability contract pin was already
green and must stay green).
```

CLI-level RED (real binary compiled from pristine master, issue's exact
repro shape):

```
$ zfa setup calculator --dart --no-git && cd calculator
$ zfa plugin enable state
❌ Error: Unsupported operation: Cannot change an unmodifiable set
--> fix: re-run with --verbose to capture the stack trace, then run `zfa doctor`
(exit 1)
$ zfa plugin disable state
❌ Error: Unsupported operation: Cannot change an unmodifiable set
(exit non-zero)
$ zfa plugin list | wc -l → 31      # every id affected
```

## GREEN (post-fix)

```
dart test test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart
→ 00:00 +5: All tests passed!
```

Sibling tests for the changed lib files (plugin_loader, plugin_command
surfaces) — no new failures, no collateral damage:

```
dart test test/cli/plugin_loader_test.dart \
          test/commands/plugin_command_add_test.dart \
          test/commands/plugin_command_mcp_test.dart \
          test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart
→ 00:01 +13: All tests passed!
```

CLI-level GREEN (real binary recompiled from the fixed tree, same
calculator fixture; persistence verified by parsing `.zfa.json` after
each invocation):

```
$ zfa plugin disable state
Disabled plugin: state                      (exit 0)
$ jq .plugins.disabled .zfa.json → ["state"]   ← PERSISTED

$ zfa plugin enable state
Enabled plugin: state                       (exit 0)
$ jq .plugins.disabled .zfa.json → []          ← PERSISTED

$ for id in $(zfa plugin list | awk '{print $2}'); do
    zfa plugin enable "$id" && zfa plugin disable "$id" >/dev/null
  done
SWEEP enable+disable: pass=31 fail=0
$ zfa plugin disable state
$ jq .plugins.disabled .zfa.json
→ ["agent","api","benchmark","cache","cli","controller","datasource",
   "di","feature","graphql","gym","mcp","method_append","mock","module",
   "presenter","provider","repository","route","service","skeleton",
   "skin","slice","sqlite","state","strategy","sync","test","tui",
   "usecase","view"]                        ← all 31 persisted correctly
```

## Full fast suite (chunked, disk-safe runner)

See `tdd/verification.md` §4 for the fresh chunked-suite result recorded
from the real run on this branch.
