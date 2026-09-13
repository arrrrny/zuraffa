# TDD test list — #1586 PluginConfig owns a mutable disabled set

Feature: 1586-plugin-enable-disable-unmodifiable-set
Suite: `test/commands/bug_1586_plugin_enable_disable_unmodifiable_set_test.dart`
Tier: fast (hermetic temp-dir unit pins, no Flutter, no CWD games)

| id | test | behavior under pin | red on master? |
| -- | ---- | ------------------ | -------------- |
| A-1586-1 | enable path — remove() on a loaded config does not throw (fresh scaffold: empty disabled array) | the exact `plugin_command.dart:51` mutation must not throw on the set loaded from `.zfa.json` | YES (threw `Unsupported operation: Cannot change an unmodifiable set` via `_UnmodifiableSetMixin.remove`) |
| A-1586-2 | disable path — add() on a loaded config does not throw (non-empty disabled array) | the exact `plugin_command.dart:53` mutation must not throw | YES (same throw) |
| A-1586-3 | round trip — mutate + save persists, reload reflects it | `await config.save()` persists the mutated disabled array; fresh `PluginConfig.load` sees it | YES (threw at the mutation; post-mutation persistence covered the fire-and-forget save loss) |
| A-1586-4 | defensive copy — caller-owned set is copied, mutation of the copy does not leak back | `PluginConfig` must not alias a caller-provided set | YES (`caller` gained `'state'` through the config) |
| A-1586-5 | must-not-break guard — `ZfaConfig.disabledPlugins` stays an unmodifiable view | the config snapshot's immutability contract is intact after the fix | NO (green pre-fix; must stay green — the fix lands at `PluginConfig`, not `ZfaConfig`) |

Plus the CLI-level end-to-end sweep (real compiled binary, issue's exact
repro shape): 31/31 ids × {enable, disable}, exit 0, stdout contract
(`Enabled plugin: <id>` / `Disabled plugin: <id>`), `.zfa.json`
persistence verified after each invocation. Recorded in
`verification.md` §2/§3.
