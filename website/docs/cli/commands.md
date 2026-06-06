# CLI Commands Reference

Zuraffa v5 centers the CLI around one primary generation command: `zfa make`.

The canonical workflow is:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

`zfa feature scaffold` still exists, but it is documented as a wrapper over the feature preset.

---

## Commands overview

| Command                | Description                                    |
| ---------------------- | ---------------------------------------------- |
| `zfa entity`           | Create and manage Zorphy entities              |
| `zfa make`             | Canonical architecture/code generation command |
| `zfa feature scaffold` | Wrapper over `zfa make --preset=feature`       |
| `zfa build`            | Run the build/codegen step                     |
| `zfa mock`            | Generate mock data (Dart or JSON)              |
| `zfa config`           | Manage `.zfa.json` project defaults            |
| `zfa manifest`         | Inspect available plugins and capabilities     |
| `zfa apply`            | Execute a previously generated plan            |
| `zfa doctor`           | Inspect tooling and environment health         |

---

## `zfa entity create`

Use this to create entities under the fixed v5 domain layout.

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double
```

Entity path contract:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

---

## `zfa make`

The primary command for generating architecture.

### Syntax

```bash
zfa make <Name> <plugin1> <plugin2> ... [options]
```

### Preset-driven examples

```bash
zfa make Product --preset=crud --methods=get,getList,create,update,delete
```

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test
```

### Explicit-plugin example

```bash
zfa make Product usecase repository datasource view presenter controller state di test \
  --methods=get,getList,create,update,delete
```

### Common flags and selectors

| Selector / Flag      | Purpose                                           |
| -------------------- | ------------------------------------------------- |
| `--preset=crud`      | Resolve the CRUD generation preset                |
| `--preset=feature`   | Resolve the feature preset                        |
| `--with=vpc`         | Expand the VPC alias to view/presenter/controller |
| `--without=<plugin>` | Exclude a plugin or alias from the final plan     |
| `--state`            | Add the state plugin                              |
| `--di`               | Add dependency injection generation               |
| `--test`             | Add tests                                         |
| `--mock`             | Add mock data generation                          |
| `--json`             | Generate JSON mock data (with --mock)            |
| `--cache`            | Add cache generation                              |
| `--gql`              | Add gql string generation                         |
| `--plan`             | Print the normalized plan and exit                |
| `--explain`          | Explain plan resolution and exit                  |
| `--format=json`      | Emit machine-readable output                      |

### Planning examples

```bash
zfa make Product --preset=crud --with=vpc --plan
```

```bash
zfa make Product --preset=crud --with=vpc --plan --format=json
```

### JSON input

```json
{
  "name": "Product",
  "preset": "crud",
  "with": ["vpc"],
  "methods": ["get", "getList", "create", "update", "delete"]
}
```

```bash
zfa make --from-json make_config.json --plan --format=json
```

---

## `zfa feature scaffold`

This command remains available, but in v5 it is documented as wrapper syntax.

Equivalent intent:

```bash
zfa make Product --preset=feature --plan
```

```bash
zfa feature scaffold Product --plan
```

Prefer `zfa make` in tutorials, automation, and AI guidance.

---

## `zfa mock`

Generate mock data for testing and prototyping. Supports Dart code generation and JSON output (v5.1.0).

### Generate Dart mock data

```bash
zfa mock Product
zfa mock data Product    # Mock data fixtures only
```

### Generate JSON mock data

```bash
zfa mock json Product
zfa mock json Product --domain=catalog --force
```

JSON mock output:
```
data/mock_json/{domain}/
├── {entity}.mock.json        # 3 mock instances
├── {entity}.mock.json.meta   # Generation metadata
└── {entity}_mock_json.dart   # fromJson-based helper
```

### Options

| Flag         | Description                                |
| ------------ | ------------------------------------------ |
| `--data-only` | Generate only mock data fixtures (Dart)   |
| `--json`     | Generate JSON mock data with fromJson helper |
| `--force` / `-f` | Overwrite existing files               |
| `--dry-run`  | Preview without writing files              |
| `--verbose` / `-v` | Enable detailed logging               |

---

## `zfa build`

Use `zfa build` after entity or architecture generation.

```bash
zfa build
zfa build --watch
zfa build --clean
```

---

## `.zfa.json` and `.zfa/`

- **`.zfa.json`** stores active project defaults.
- **`.zfa/`** is the canonical v5 project-memory model.

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

During the migration period, some internals may still reference older storage paths. Public-facing docs should still describe `.zfa/` as the forward contract.

---

## Related docs

- [Getting Started](../guides/getting-started)
- [Entity Commands Reference](./entity-commands)
- [Migration Guide: v4 → v5](../guides/migration-v4-to-v5)
