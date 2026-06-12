# Data Model & Architecture: Declarative UseCase Registration

**Feature**: Declarative UseCase Registration
**Branch**: `010-usecase-registration`
**Date**: 2026-06-12

---

## Overview

This document defines the design for adding CLI-based use case registration to Zuraffa's Presenter, Controller, and State layers. The design follows the existing `zfa di <Name>` pattern and reuses the `AppendExecutor` infrastructure.

---

## Architecture

### Component Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                        CLI Layer                                   │
│                                                                     │
│  RegisterCommand (NEW)                                              │
│  ┌──────────────────────────────────────────────┐                  │
│  │ zfa register <Name> [controller presenter    │                  │
│  │                    state di]                  │                  │
│  └──────────┬───────────────────────────────────┘                  │
│             │ delegates to                                         │
│             ▼                                                      │
│  Individual Commands (extended)                                    │
│  ┌──────────────┐ ┌─────────────────┐ ┌──────────────┐            │
│  │PresenterCmd   │ │ControllerCmd    │ │StateCmd      │            │
│  │ register <N>  │ │ register <N>    │ │ register <N> │            │
│  └──────┬───────┘ └───────┬─────────┘ └──────┬───────┘            │
│         │                 │                  │                     │
└─────────┼─────────────────┼──────────────────┼─────────────────────┘
          │                 │                  │
          ▼                 ▼                  ▼
┌────────────────────────────────────────────────────────────────────┐
│                       Capability Layer                              │
│                                                                     │
│  RegisterPresenterCap (NEW)  RegisterControllerCap (NEW)           │
│  ┌──────────────────────┐  ┌──────────────────────────┐            │
│  │ plan() / execute()   │  │ plan() / execute()       │            │
│  │ → find presenter file│  │ → find controller file   │            │
│  │ → build append req   │  │ → build append req       │            │
│  │ → run AppendExecutor │  │ → run AppendExecutor     │            │
│  └──────────┬───────────┘  └───────────┬──────────────┘            │
│             │                          │                           │
│  RegisterStateCap (NEW)               │                           │
│  ┌──────────────────────┐             │                           │
│  │ plan() / execute()   │             │                           │
│  │ → find state file    │             │                           │
│  │ → build append req   │             │                           │
│  │ → run AppendExecutor │             │                           │
│  └──────────┬───────────┘             │                           │
│             │                          │                           │
└─────────────┼──────────────────────────┼───────────────────────────┘
              │                          │
              ▼                          ▼
┌────────────────────────────────────────────────────────────────────┐
│                    Reuse Layer (Existing)                           │
│                                                                     │
│  AppendExecutor        FieldAppendStrategy                          │
│  ┌────────────────┐   ┌──────────────────────┐                     │
│  │ execute(req)   │──▶│ canHandle() / apply()│──▶ Parsed AST      │
│  │ undo(req)      │   │ → add field to class │   using analyzer   │
│  └────────────────┘   └──────────────────────┘                     │
│                                                                     │
│  ConstructorAppendStrategy  ImportAppendStrategy                    │
│  ┌────────────────────────┐ ┌────────────────────┐                │
│  │ → add constructor stmt │ │ → add import       │                │
│  └────────────────────────┘ └────────────────────┘                │
└────────────────────────────────────────────────────────────────────┘
```

### Key Files

| File | Status | Purpose |
|------|--------|---------|
| `lib/src/commands/register_command.dart` | NEW | Batch `zfa register` command |
| `lib/src/plugins/presenter/capabilities/register_presenter_capability.dart` | NEW | Register use case in Presenter |
| `lib/src/plugins/controller/capabilities/register_controller_capability.dart` | NEW | Register use case in Controller |
| `lib/src/plugins/state/capabilities/register_state_capability.dart` | NEW | Register field in State |
| `lib/src/plugins/presenter/presenter_plugin.dart` | MODIFIED | Add `RegisterPresenterCap` to capabilities |
| `lib/src/plugins/controller/controller_plugin.dart` | MODIFIED | Add `RegisterControllerCap` to capabilities |
| `lib/src/plugins/state/state_plugin.dart` | MODIFIED | Add `RegisterStateCap` to capabilities |
| `lib/src/commands/presenter_command.dart` | MODIFIED | Add `register` subcommand |
| `lib/src/commands/controller_command.dart` | MODIFIED | Add `register` subcommand |
| `lib/src/commands/state_command.dart` | MODIFIED | Add `register` subcommand |

### No New Files Needed for Existing Infrastructure

The following existing components will be used as-is:
- `AppendExecutor` — dispatches append requests to the right strategy
- `FieldAppendStrategy` — adds fields to existing classes
- `ConstructorAppendStrategy` — adds constructor statements
- `ImportAppendStrategy` — adds import directives
- `AppendRequest` — data object containing source, className, target, memberSource
- `AppendResult` — result object with modified source

---

## Capability Design

### RegisterPresenterCapability

**Purpose**: Register a use case in an existing Presenter by appending a field + constructor registration + import.

**Input Schema**:
```json
{
  "target": "string (e.g., GetProduct)",
  "entity": "string (optional, overrides auto-inferred entity name)",
  "domain": "string (optional, overrides auto-inferred domain)",
  "presenterName": "string (optional, overrides auto-inferred presenter class name)",
  "dryRun": "boolean (default: false)",
  "force": "boolean (default: false)",
  "verbose": "boolean (default: false)"
}
```

**Execution Flow**:
1. Parse `target` to extract use case class name (`${target}UseCase`)
2. Infer entity name by stripping known verb prefixes from `target`
3. Infer domain by scanning filesystem for the use case file
4. Locate presenter file: `lib/src/presentation/pages/{domain}/{entity_snake}_presenter.dart`
5. Parse presenter file, find the class name (e.g., `ProductPresenter`)
6. Build field source: `late final ${UseCaseName} _${fieldName};`
7. Build constructor statement: `_${fieldName} = registerUseCase(getIt<${UseCaseName}>());`
8. Build import: `import 'package:.../${entity_snake}_usecase.dart';`
9. Create `AppendRequest`s and execute via `AppendExecutor`
10. Write modified source back to file

### RegisterControllerCapability

**Purpose**: Register a use case in an existing Controller by appending a field + constructor registration + import.

**Input Schema**: Same as RegisterPresenterCapability (using `controllerName` instead of `presenterName`).

**Execution Flow**: Same pattern as Presenter, targeting the controller file instead.

### RegisterStateCapability

**Purpose**: Register a field in an existing State class by appending a field + copyWith support.

**Input Schema**:
```json
{
  "target": "string (e.g., product)",
  "type": "string (e.g., Product?, List<Product>)",
  "entity": "string (optional)",
  "domain": "string (optional)",
  "stateName": "string (optional)",
  "dryRun": "boolean",
  "force": "boolean",
  "verbose": "boolean"
}
```

**Execution Flow**:
1. Locate state file: `lib/src/presentation/pages/{domain}/{entity_snake}_state.dart`
2. Parse state file, find the state class
3. Build field source: `final ${Type} ${fieldName};`
4. Build copyWith entry
5. Create `AppendRequest`s and execute

---

## Batch Command Design

### RegisterCommand

**CLI Syntax**:
```
zfa register <UseCaseName> [options]

OPTIONS:
  --controller, -c       Register in Controller
  --presenter, -p        Register in Presenter
  --state, -s            Register in State
  --di, -d               Register in DI
  --all, -a              Register in all layers (controller, presenter, state, di)
  --domain               Domain name
  --entity               Entity name (overrides auto-inference)
  --dry-run              Preview without writing
  --force                Overwrite existing
  --verbose              Verbose output
```

**Examples**:
```
zfa register GetProduct --all                # All layers
zfa register GetProduct -c -p                # Only controller + presenter
zfa register GetProduct -a --dry-run         # Preview all layers
zfa register CreateCustomer -c -d --domain=customer
```

**Execution Flow**:
1. Parse layer flags from arguments
2. For each requested layer, delegate to the corresponding capability
3. If `--all` or no layer flags, register in all 4 layers
4. Aggregate results from all capabilities

---

## Name Resolution Rules

### From Use Case Name to Entity Name

The system maintains a list of known verb prefixes. When resolving a use case name:

1. Check if `target` ends with `UseCase`; if so, strip it
2. Check against known verb prefixes; if a match is found, strip it
3. The remainder is the entity base name

**Examples**:

| Input | Stripped | Entity |
|-------|----------|--------|
| `GetProduct` | Strip `Get` | `Product` |
| `CreateProduct` | Strip `Create` | `Product` |
| `ResolveInAppLink` | Strip `Resolve` | `InAppLink` |
| `SearchProducts` | Strip `Search` | `Products` |
| `CustomAction` | No match | `CustomAction` |

### From Entity Name to File Path

```dart
String _entityToFileName(String entity, String domain) {
  final snake = camelToSnake(entity);  // e.g., "InAppLink" → "in_app_link"
  return 'lib/src/presentation/pages/$domain/${snake}_presenter.dart';
}
```

### From Use Case File to Domain

Scan `lib/src/domain/usecases/` subdirectories for the use case file matching the target name. The first matching subdirectory name is the domain.

---

## Append Request Building

### Presenter Append Example

Given a presenter file containing:
```dart
class ProductPresenter extends Presenter {
  late final GetProductUseCase _getProduct;
  late final CreateProductUseCase _createProduct;

  ProductPresenter() {
    _getProduct = registerUseCase(getIt<GetProductUseCase>());
    _createProduct = registerUseCase(getIt<CreateProductUseCase>());
  }

  Future<void> getProduct(String id) async {
    // ...
  }
}
```

After `zfa presenter register DeleteProduct`:
```dart
class ProductPresenter extends Presenter {
  late final GetProductUseCase _getProduct;
  late final CreateProductUseCase _createProduct;
  late final DeleteProductUseCase _deleteProduct;

  ProductPresenter() {
    _getProduct = registerUseCase(getIt<GetProductUseCase>());
    _createProduct = registerUseCase(getIt<CreateProductUseCase>());
    _deleteProduct = registerUseCase(getIt<DeleteProductUseCase>());
  }

  Future<void> getProduct(String id) async {
    // ...
  }
}
```

### Append Request Construction

```dart
// 1. Field append
final fieldRequest = AppendRequest(
  source: originalSource,
  target: AppendTarget.field,
  className: 'ProductPresenter',
  memberSource: 'late final DeleteProductUseCase _deleteProduct;',
);

// 2. Constructor statement append
final constructorRequest = AppendRequest(
  source: fieldResult.source, // use modified source from field append
  target: AppendTarget.constructor,
  className: 'ProductPresenter',
  memberSource: '_deleteProduct = registerUseCase(getIt<DeleteProductUseCase>());',
);

// 3. Import append
final importRequest = AppendRequest(
  source: constructorResult.source,
  target: AppendTarget.import,
  memberSource: "import 'package:your_app/domain/usecases/product/delete_product_usecase.dart';",
);
```

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Presenter file not found | Print error listing discovered domains/entities |
| Class not found in file | Print error with available class names |
| Use case already registered | No-op (field exists, skip) |
| Target file has no constructor | Print error; user needs to add constructor first |
| Invalid use case name | Print error with expected format |
| Duplicate registration attempt | Skip with warning unless `--force` |
