# RED Evidence — #1496 config init writes all 24 plugins false

- **Date**: 2026-09-13
- **Tree**: master b621f38b + bug artifacts (no fix code)
- **Live CLI reproduction** (fresh dir `/tmp/probe`, Dart 3.13.3):

```
$ zfa config init
✅ Created configuration file: /tmp/probe/.zfa.json

$ jq '.plugins.defaults' .zfa.json
{ "agent": false, "cache": false, "controller": false, "datasource": false,
  "di": false, "feature": false, "gql": false, "graphql": false, "gym": false,
  "method_append": false, "mock": false, "observer": false, "presenter": false,
  "provider": false, "repository": false, "route": false, "service": false,
  "skin": false, "sqlite": false, "state": false, "test": false,
  "usecase": false, "view": false, "xray": false }

$ zfa make Task        # entity file exists at lib/src/domain/entities/task/task.dart
❌ No active plugins to run.
(exit 0 — silent no-op)

$ zfa make Task --preset=crud
✅ Done.                # repository/datasource/usecase/mock/di files generated
```

- **New suite**: `dart test test/commands/bug_1496_config_init_defaults_test.dart`

## B1 — init writes the clean-architecture stack true — FAIL (pre-fix)

```
Expected: isTrue
  Actual: <false>
   Left: config.pluginDefaults['di']   // and 11 more stack keys
```

## B2 — in-memory default + resolver produce the stack — FAIL (pre-fix)

```
Expected: isTrue
  Actual: <false>
   Left: config.isPluginEnabledByDefault('usecase')
→ resolver.resolve(name: 'Task').pluginIds: []   (expected: contains usecase)
```

## B4 — `config init --minimal` is not supported — FAIL (pre-fix)

```
Expected: file with all-false defaults exists
  Actual: unhandled — _handleInit has no --minimal flag; a minimal config
          is impossible to opt into
```

## B5 — bare `zfa make` in an init'ed project is a dead end — FAIL (pre-fix)

```
❌ No active plugins to run.    (exit 0, zero files written)
```

## B6 — empty-plan message names no remedy — FAIL (pre-fix)

```
Expected: output contains '--preset=crud'
  Actual: "❌ No active plugins to run."
```

Red state: all target behaviors failing against pristine master, for
exactly the reason the assessment names — `_builtinPluginDefaults` is
all-false and the empty-plan branch offers no remedy.
