# Fix — #1496: config init enables the clean-architecture stack; remedy line; --minimal flag

- **Slug**: 1496-config-init-defaults-all-false
- **Branch**: `fix/1496-config-init-defaults-all-false`
- **Fixes**: https://github.com/arrrrny/zuraffa/issues/1496

## Change 1 — `_builtinPluginDefaults` enables the clean-architecture stack

`lib/src/config/zfa_config.dart:19-55`:

- The 12 stack plugins are now `true`: `di`, `datasource`, `repository`,
  `usecase`, `mock`, `test`, `method_append`, `route`, `provider`,
  `presenter`, `controller`, `cache`.
- The opt-in tier stays `false`: `view`, `state`, `feature`, `service`,
  `gym`, `sqlite`, `gql`, `graphql`, `skin`, `xray`, `agent` — plus the
  removed `observer` (#1149), also `false`.
- The map is the single source of truth for all three surfaces, so one
  change fixes them coherently:
  - `ZfaConfig()`'s constructor spread (the in-memory "no config"
    answer), zfa_config.dart:110-123,
  - `ZfaConfig.init()`'s on-disk output (`zfa config init`),
  - `isPluginEnabledByDefault`'s `?? false` fallback for keys a legacy
    config never listed (zfa_config.dart:212-217 — the operator line is
    unchanged; the map behind it carries the intent).

Constraint compliance: the plugin registry, plan resolver logic, and
state machine are untouched. `PlanResolver.resolve` still asks
`config?.isPluginEnabledByDefault(plugin.id)` per registry plugin
(plan_resolver.dart:49-53); with a stack-enabled config the same three
lines now resolve the full stack. Custom configs are not broken:
`fromJson` merges the file's `plugins.defaults` OVER the builtin map
(zfa_config.dart:307-310), and legacy top-level keys
(`diByDefault: false` …) ride the same override surface
(zfa_config.dart:442-451) — an explicit `false` still wins; only keys a
config never listed move from off to on, i.e. fresh `init` output and
legacy configs that never listed the plugin.

## Change 2 — the empty-plan message names the remedy

`lib/src/commands/make_command.dart:745-760`:

- The empty-plan branch keeps its verdict line and appends the WHY
  (no flags and .zfa.json enables none by default) and the FIX in the
  repo's `--> fix:` house style:
  - `--preset=crud` for the standard data slice, or
  - `--with=<plugin>` for individual plugins.
- No behavior change beyond output: the branch still returns before any
  generation.

## Change 3 — `zfa config init --minimal` (the all-off opt-out)

- `lib/src/config/zfa_config.dart` — `init({String? projectRoot, bool
  minimal = false})` writes `ZfaConfig.minimal()` (a NEW factory: every
  builtin id `false` — the pre-#1496 map) when `--minimal` is passed,
  and prints which tier the file carries (stack-on vs minimal) so the
  operator can see the intent at init time.
- `lib/src/commands/config_command.dart` — `_handleInit` parses
  `--minimal`/`-m` positionally-agnostic (`init --minimal <root>` and
  `init <root> --minimal` both work); `_printHelp` documents the flag.
- `lib/src/cli/cli_runner.dart` — `_ConfigCommand` now uses
  `ArgParser.allowAnything()` and forwards `arguments` (the
  `_InitializeCommand` pattern) so the root parser no longer rejects
  the flag before it reaches the config command.
