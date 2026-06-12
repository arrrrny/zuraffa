# CLI Contracts: UseCase Registration Commands

**Feature**: Declarative UseCase Registration
**Date**: 2026-06-12

---

## 1. `zfa presenter register`

Register a use case in an existing Presenter by appending field + constructor + import.

### Usage

```
zfa presenter register <UseCaseName> [options]
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<UseCaseName>` | ✅ | Name of the use case (e.g., `GetProduct`, `CreateCustomer`). Do not include `UseCase` suffix. |

### Options

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--domain` | `-d` | *inferred* | Domain folder where the use case is located |
| `--entity` | `-e` | *inferred* | Entity name (overrides auto-inference from use case name) |
| `--presenter-name` | | *inferred* | Presenter class name (overrides auto-inference) |
| `--dry-run` | | `false` | Preview what would be changed without writing |
| `--force` | `-f` | `false` | Allow replacing existing fields |
| `--verbose` | `-v` | `false` | Verbose output |

### Examples

```
zfa presenter register GetProduct
zfa presenter register CreateCustomer --domain=customer
zfa presenter register ResolveInAppLink --entity=Listing
zfa presenter register DeleteProduct --dry-run
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — use case registered |
| 1 | Error — file not found, parse error, or other failure |

---

## 2. `zfa controller register`

Register a use case in an existing Controller by appending field + constructor + import.

### Usage

```
zfa controller register <UseCaseName> [options]
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<UseCaseName>` | ✅ | Name of the use case (e.g., `GetProduct`) |

### Options

Same options as `zfa presenter register`, except uses `--controller-name` instead of `--presenter-name`.

### Examples

```
zfa controller register GetProduct
zfa controller register CreateCustomer --domain=customer
zfa controller register DeleteProduct --dry-run
```

---

## 3. `zfa state register`

Register a field in an existing State class by appending field + copyWith support.

### Usage

```
zfa state register <FieldName> [options]
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<FieldName>` | ✅ | Name of the field to add (e.g., `product`, `items`) |

### Options

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--type` | `-t` | *required* | Type of the field (e.g., `Product?`, `List<Item>`) |
| `--domain` | `-d` | *inferred* | Domain folder |
| `--entity` | `-e` | *inferred* | Entity name |
| `--state-name` | | *inferred* | State class name |
| `--dry-run` | | `false` | Preview without writing |
| `--force` | `-f` | `false` | Allow replacing existing fields |
| `--verbose` | `-v` | `false` | Verbose output |

### Examples

```
zfa state register product --type=Product?
zfa state register items --type=List<Item> --domain=customer
zfa state register selectedId --type=String? --dry-run
```

---

## 4. `zfa register` (batch)

Register a use case across multiple layers in a single command.

### Usage

```
zfa register <UseCaseName> [options]
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<UseCaseName>` | ✅ | Name of the use case (e.g., `GetProduct`) |

### Options

| Option | Alias | Default | Description |
|--------|-------|---------|-------------|
| `--controller` | `-c` | `false` | Register in Controller |
| `--presenter` | `-p` | `false` | Register in Presenter |
| `--state` | `-s` | `false` | Register in State |
| `--di` | `-d` | `false` | Register in DI |
| `--all` | `-a` | `false` | Register in all layers |
| `--domain` | | *inferred* | Domain folder |
| `--entity` | `-e` | *inferred* | Entity name |
| `--state-type` | | *required if --state* | Field type for state registration |
| `--dry-run` | | `false` | Preview without writing |
| `--force` | `-f` | `false` | Allow replacing existing |
| `--verbose` | `-v` | `false` | Verbose output |

### Behavior

- If no layer flags are specified, defaults to `--all`
- Layer flags are processed in order: DI → Presenter → Controller → State
- Each layer is independent; failure in one does not block others
- Results are aggregated and reported per layer

### Examples

```
zfa register GetProduct --all
zfa register GetProduct -c -p
zfa register CreateCustomer -a --domain=customer
zfa register GetProduct -c -p -s --state-type=Product? --dry-run
zfa register DeleteProduct -a --dry-run --verbose
```
