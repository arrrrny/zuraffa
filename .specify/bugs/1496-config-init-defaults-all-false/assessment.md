# Bug Assessment — #1496: `zfa config init` writes all 24 plugins false; first `zfa make` gives "No active plugins to run."

- **Slug**: 1496-config-init-defaults-all-false
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1496
- **Verdict**: valid
- **Severity**: high (a fresh `config init` project is a dead end for the
  documented happy path: the first bare `zfa make` resolves zero plugins
  and exits 0 having produced nothing — a silent no-op that reads like
  success but generates nothing)

## Report (verbatim, condensed)

> `zfa config init` writes `.zfa.json` with `plugins.defaults`
> containing all 24 builtin plugins set to `false`. First `zfa make
> Task` resolves zero plugins and prints "No active plugins to run."
> The framework's standard clean-architecture stack is opt-in, not
> default.

Re-confirmed on master b621f38b (2026-09-13, Dart 3.13.3):

```
$ zfa config init
✅ Created configuration file: /tmp/probe/.zfa.json
$ jq '.plugins.defaults' .zfa.json        # all 24 keys false
$ zfa make Task                            # entity exists
❌ No active plugins to run.               # exit 0 — silent no-op
$ zfa make Task --preset=crud
✅ Done.                                   # 18 files, MOCKED tier banner
```

## Root cause (confirmed against the tree)

Two cooperating defects, both in config-land (the plan resolver is
functionally innocent — it faithfully reads what init wrote):

**Defect 1 — the builtin defaults contradict the framework's own
documented stack.** `lib/src/config/zfa_config.dart:19-49`
(`_builtinPluginDefaults`) hard-codes `false` for every one of the 24
builtin plugin ids. `ZfaConfig()`'s constructor spreads this map
verbatim (zfa_config.dart:110-123), so the object model's "no config
file" answer is also all-off. `ZfaConfig.init()` (zfa_config.dart:398)
then materialises `ZfaConfig()` to disk. The defaults-map is the single
source of truth for all three surfaces (in-memory default, `config
init` output, `isPluginEnabledByDefault` fallback), so fixing the map
fixes all three coherently.

**Defect 2 — the empty-plan message is a dead end.**
`lib/src/commands/make_command.dart:745-749` prints
`❌ No active plugins to run.` and returns — exit 0, no remedy, no
pointer to `--preset=crud` / `--with=<plugin>`. The operator is told
nothing happened and not why or what to do.

### Why the resolver/registry/state machine stay untouched

`PlanResolver.resolve` (plan_resolver.dart:49-53) iterates the registry
and asks `config?.isPluginEnabledByDefault(plugin.id)` — with a config
whose stack plugins are `true`, the same three lines produce the full
stack plan. The registry and sort order are already correct (the
`--preset=crud` path proves it). Per the issue's hard constraint the
fix is therefore confined to (a) `_builtinPluginDefaults`, (b) the
empty-plan remedy text, plus (c) the `--minimal` opt-out for `config
init` that the issue explicitly requires.

### Blast radius (checked against the test tree)

- `test/config/zfa_config_test.dart:27-36` encodes the BUGGY behaviour
  (`init` → `testByDefault`/`mockByDefault` false) — must flip to the
  new intent as part of GREEN.
- `plan_resolver_test.dart`, `plugin_manager_test.dart`,
  `compare_outputs_test.dart`, `config_precedence_test.dart` all either
  pass explicit `pluginDefaults` overrides (which win over the map) or
  run the resolver with `config: null`/absent-config workspaces — the
  defaults-map change only adds plugins the fake registries don't
  contain (never requested → no unknown-plugin warnings, since the
  config-default loop iterates REGISTRY plugins only,
  plan_resolver.dart:49-53).
- Existing projects with custom configs are unaffected: `fromJson`
  merges the file's `plugins.defaults` OVER the builtin map
  (zfa_config.dart:307-310), so any explicit key — including an
  explicit `false` — still wins. Only projects WITHOUT the key move
  from off to on, i.e. fresh `init` output and legacy configs that
  never listed the plugin.
- Legacy top-level keys (`diByDefault: false` etc.) map through
  `_legacyPluginDefaults` (zfa_config.dart:442-451) onto the same
  override surface — they keep winning too.

## Remediation plan (TDD)

| Behavior | Test |
| -------- | ---- |
| B1 — `ZfaConfig.init` writes the 12 stack plugins `true`; opt-in plugins stay `false` | unit, temp dir |
| B2 — `ZfaConfig()` (no file) enables the stack via `isPluginEnabledByDefault`; opt-ins stay off; resolver turns an empty-options plan into the stack | unit |
| B3 — a config that explicitly sets a stack plugin `false` keeps it off (custom configs not broken) | unit |
| B4 — `config init --minimal` writes the all-off map (teams keeping the old behaviour) | unit, temp dir |
| B5 — bare `zfa make <Entity>` in an init'ed project resolves the stack and generates (end-to-end) | integration, temp dir |
| B6 — empty-plan message names the remedy (`--preset=crud` / `--with=<plugin>`) | unit |

Constraint check after GREEN: registry, plan resolver logic, and state
machine diffs = zero; `dart analyze` clean on changed files.
