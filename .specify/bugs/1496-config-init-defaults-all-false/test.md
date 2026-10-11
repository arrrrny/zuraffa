# Test — #1496: config init enables the clean-architecture stack; remedy line; --minimal flag

- **Slug**: 1496-config-init-defaults-all-false
- **Suite**: `test/commands/bug_1496_config_init_defaults_test.dart`
  (tagged `slow`; run with `dart test --preset=all <file>`)

## Test map

| Test | Level | Pins |
| ---- | ----- | ---- |
| B1 — `ZfaConfig.init` writes the 12 stack plugins `true` and the opt-in set `false` | unit (temp dir) | fix 1: the defaults map carries the stack-on intent into the on-disk config for all 24 builtin ids |
| B2 — the in-memory default enables the stack; `PlanResolver` turns a bare `make` into the stack plan | unit + real registry (PluginLoader) | fix 1 on the no-config surface: `isPluginEnabledByDefault` true for the stack, false for opt-ins; the resolver path that produced "No active plugins" now resolves `containsAll(stack)` |
| B3 — an explicit `false` in a custom `.zfa.json` still wins | unit (temp dir) | fix 1 does not break existing projects: `fromJson` merge order keeps explicit keys (mock/route opted out stay off; untouched stack members stay on) |
| B4 — `zfa config init --minimal` keeps the all-off behaviour | integration (CliRunner) | fix 3: the flag flows through the CLI, writes every builtin `false`, and announces `Minimal mode` |
| B5 — bare `zfa make <Entity>` in an init-ed project generates the stack | integration (CliRunner, real generation, temp project) | the issue's headline symptom inverted: no "No active plugins", repository + datasource + di + mock artifacts on disk WITHOUT `--preset=crud` |
| B6 — the empty-plan message names the remedy | integration (CliRunner, all-off config workspace) | fix 2: the dead-end line now carries `--preset=crud` and `--with=` |

Updated alongside (pre-existing suite that encoded the BUGGY intent):
`test/config/zfa_config_test.dart` — `init creates default config file`
now expects `testByDefault`/`mockByDefault` **true** (#1496).

## Result — GREEN (fresh run, real execution)

```
$ dart test --preset=all test/commands/bug_1496_config_init_defaults_test.dart
00:02 +6: All tests passed!
```

Post-format re-run (with zfa_config_test + plan_resolver_test):

```
$ dart test --preset=all test/commands/bug_1496_config_init_defaults_test.dart test/config/zfa_config_test.dart test/core/planning/plan_resolver_test.dart
00:03 +13: All tests passed!
```

## Regression verification (all real runs)

| Scope | Result |
| ----- | ------ |
| `dart analyze` on the 6 changed files | 1 pre-existing info only (`prefer_collection_literals` at make_command.dart, verified identical on stashed master); 0 new warnings |
| Chunk 1 — `test/config` + `test/core/planning` + `test/core/plugin_system` | +62 All tests passed! |
| Chunk 2 — `test/agent` + `test/plugins/graphql` + `test/graphql` + `test/regression/compare_outputs_test.dart` | +438 All tests passed! |
| Chunk 3 — `test/cli` | +235 All tests passed! |
| Chunk 4 — `test/commands` | +370 All tests passed! |
| Full chunked fast suite (`tools/run_tests_chunked.sh` semantics, 105 chunks) | 99 chunks green; 6 chunks fail IDENTICALLY on pristine master: 3 × `flutter pub get` missing (no Flutter SDK: controller/view/templates compile gates), 3 × empty fast tier ("No tests ran" — all suites slow-tagged: integration, tdd/scenarios, tdd/077) |
| Live CLI repro (fresh dir, entity present) | `config init` → 12 true defaults; bare `make Task` → `✅ Done.` + 30 files; all-off config → remedy line with `--preset=crud` / `--with=` |

## Constraint check

- Plugin registry: untouched (0 diff lines in registry files).
- Plan resolver logic: untouched (`plan_resolver.dart` has no diff;
  `plan_resolver_test.dart` green untouched).
- State machine: untouched.
- Existing custom configs: explicit keys still win (B3).
