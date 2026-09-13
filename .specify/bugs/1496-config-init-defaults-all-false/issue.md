# Issue — #1496: `zfa config init` writes all 24 plugins false; first `zfa make` gives "No active plugins to run."

- **Slug**: 1496-config-init-defaults-all-false
- **Source**: https://github.com/arrrrny/zuraffa/issues/1496
- **Fetched**: 2026-09-13
- **Related**: #1194 (mock-first default intent), #1465, #1349, #1379

## Report

`zfa config init` writes `.zfa.json` with `plugins.defaults` containing
all 24 builtin plugins set to `false`. The first `zfa make Task` in a
fresh project then resolves ZERO plugins and prints
"No active plugins to run." The framework's standard clean-architecture
stack is opt-in, not default — the exact inverse of the documented
intent (the presets, the doctor checks, and #1194's mock-first default
all assume the stack is present).

### Reproduction (verbatim from the issue, re-confirmed on master b621f38b)

```bash
mkdir /tmp/probe && cd /tmp/probe && zfa config init
zfa make Task
# ❌ No active plugins to run.

zfa make Task --preset=crud
# ✅ Created: 18 files — works perfectly
```

Same project, same entity, same version — only difference is
`--preset=crud`.

## Root cause (confirmed against the tree)

`lib/src/config/zfa_config.dart:19-49` — `_builtinPluginDefaults` has
every plugin `false`. `ZfaConfig()` spreads this verbatim
(zfa_config.dart:110-123), `init()` writes it as-is (zfa_config.dart:398-416),
and `isPluginEnabledByDefault` returns `pluginDefaults[pluginId] ?? false`
(zfa_config.dart:212-217). With all defaults false,
`plan_resolver.dart:49-53` resolves zero plugins from config, and
`lib/src/commands/make_command.dart:745-749` prints the dead-end
"No active plugins to run." line.

## Expected (from the issue)

1. `_builtinPluginDefaults` sets the clean-architecture stack to `true`:
   `di`, `datasource`, `repository`, `usecase`, `mock`, `test`,
   `method_append`, `route`, `provider`, `presenter`, `controller`,
   `cache`.
2. Opt-in plugins stay `false`: `graphql`/`gql`, `sqlite`, `view`,
   `skin`, `state`, `feature`, `gym`, `xray`, `agent`.
3. The empty-plan message names the remedy (`--preset=crud` or
   `--with=<plugin>`).
4. `zfa config init --minimal` keeps the all-off behaviour for teams who
   want it.

## Hard constraints

- Fix ONLY `_builtinPluginDefaults` and the empty-plan remedy text.
  Do NOT change the plugin registry, plan resolver logic, or the state
  machine.
- Must not break existing projects with custom configs (the change only
  affects new projects / `init` output).
- Must pass `dart analyze` with no new warnings.
