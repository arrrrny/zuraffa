## [Unreleased]

### ✨ Features

#### GraphQL Support
- Added GraphQL command for schema introspection and code generation
- Added GraphQL schema models for introspection query responses
- Added GraphQL introspection service for fetching and parsing schemas
- Added GraphQL schema translator to convert Zorphy entities to GraphQL types
- Added GraphQL entity emitter for generating annotated entity classes
- Added comprehensive unit tests for GraphQL schema models and translator
- Added barrel export for GraphQL module

### 📝 Notes
- GraphQL parser is now ready for production use
- Supports introspection of remote GraphQL schemas
- Generates type-safe Dart code from GraphQL schemas
- Integrates with existing Zorphy entity system
- 
## [2.5.1] - 2026-02-05

### 📚 Documentation

#### Zuraffa CLI Skill
- Completely refined Zuraffa CLI skill with CLI-only philosophy
- Added comprehensive UI generation flags (--vpc, --vpcs, --pc, --pcs)
- Added "Golden Rules" section emphasizing CLI-only workflow
- Added "CLI vs Manual Work" comparison table
- Enhanced workflows for complete feature generation
- Updated Quick Reference with all latest features (v2.5.0 Sync UseCase, v2.4.0 GraphQL, Service pattern)
- Improved troubleshooting section with common mistakes and fixes
- Advanced features section with polymorphic patterns and GraphQL examples
- Clear distinction: CLI handles 95% of boilerplate, manual work only for business logic and UI customization

## [2.5.0] - 2026-02-05

### ✨ New Features

#### Sync UseCase
- Added `SyncUseCase` domain entity for synchronous operations
- Added sync method generation support for UseCases
- Added method appender for extending existing repositories and datasources
- Added sync feature documentation with comprehensive examples
- Updated CLI commands reference with sync usage
- Updated MCP server with sync capabilities


## [2.4.0] - 2026-02-05

### ✨ New Features

#### GraphQL Generation
- Added GraphQL query/mutation/subscription file generator
- Added `--gql` flag to enable GraphQL generation
- Added `--gql-type` flag to specify operation type (query, mutation, subscription)
- Added `--gql-returns` flag to specify return fields as comma-separated string
- Added `--gql-input-type` flag to specify input type name
- Added `--gql-input-name` flag to specify input variable name (default: input)
- Added `--gql-name` flag to specify custom GraphQL operation name
- Auto-detects operation types for entity methods (get/getList=query, create/update/delete=mutation, watch/watchList=subscription)

#### Service/Provider Pattern
- Added service pattern as alternative to repository for custom UseCases
- Added `--service` flag to generate service interface instead of repository
- Added `--service-method` flag to customize service method names
- Added provider generator for service implementations
- Generated files placed in `domain/services/` and `data/providers/`

### 📚 Documentation
- Updated README.md with service vs repository comparison and GraphQL generation examples
- Updated AGENTS.md with comprehensive GraphQL generation documentation
- Updated MCP_SERVER.md with GraphQL and service support in tool definitions
- Updated CLI_GUIDE.md with GraphQL flags and examples
- Updated website/docs/cli/commands.md with GraphQL generation section

### 🔧 Internal
- Added `GraphQLGenerator` class for GraphQL file generation
- Added `ProviderGenerator` class for service provider generation
- Updated `GeneratorConfig` model with GraphQL and service properties
- Updated MCP server tool definitions to support new flags

## [2.3.2] - 2026-02-05

### Chore
- Fixed meta transitive dependency

## [2.3.1] - 2026-02-05
- Updated Zorphy dependencies

## [2.2.2] - 2026-02-04
- Updated README

## [2.2.1] - 2026-02-04
- Updated README and website docs https://zuraffa.com

## [2.2.0] - 2026-02-04
- Updated examples and docs
- Bundled zorphy with zuraffa so no longer need a separate install

## [2.1.0] - 2026-02-04

### 🎉 Major Feature - Zorphy Entity Generation Integration

Zuraffa now includes **complete Zorphy entity generation** - making it a full-featured CLI for both Clean Architecture and entity management!

### ✨ New Features

#### Entity Generation Commands
- `zfa entity create` - Create Zorphy entities with fields
- `zfa entity new` - Quick-create simple entities
- `zfa entity enum` - Create enums with automatic barrel exports
- `zfa entity add-field` - Add fields to existing entities
- `zfa entity from-json` - Create entities from JSON files
- `zfa entity list` - List all entities in project
- `zfa build` - Run build_runner with --watch and --clean options

#### Entity Features
- ✅ Type-safe entities with null safety
- ✅ JSON serialization (built-in)
- ✅ Sealed classes for polymorphism
- ✅ Multiple inheritance support
- ✅ Generic types (`List<T>`, `Map<K,V>`)
- ✅ Nested entities with auto-imports
- ✅ Enum integration
- ✅ Self-referencing types (trees, graphs)
- ✅ `compareTo`, `copyWith`, `patch` methods
- ✅ Function-based copyWith option
- ✅ Explicit subtypes for polymorphism

#### MCP Server Integration
All entity commands now available via MCP:
- `entity_create` - Create entities from AI/IDE
- `entity_enum` - Create enums
- `entity_add_field` - Add fields to existing entities
- `entity_from_json` - Import from JSON
- `entity_list` - List all entities
- `entity_new` - Quick entity creation

### 🔄 Changes

#### Dependencies
- **Replaced** `zikzak_morphy` with `zorphy` (fully upgraded version)
- **Added** `zorphy_annotation` as runtime dependency
- **Added** `json_annotation` for entity serialization
- **Updated** SDK constraint to `>=3.8.0`
- **Added** `dependency_overrides` for compatibility

#### Documentation
- **Added** `ENTITY_GUIDE.md` - Comprehensive entity generation guide with 50+ examples
- **Updated** README.md with entity commands section
- **Updated** CLI help text with entity commands

### 📚 New Documentation

- **[ENTITY_GUIDE.md](ENTITY_GUIDE.md)** - Complete guide covering:
  - Basic entity creation
  - All field types (basic, nullable, generic, nested)
  - JSON serialization
  - Enums
  - Sealed classes & polymorphism
  - Inheritance & interfaces
  - Nested objects
  - Self-referencing types
  - Generic classes
  - Complete real-world examples (E-commerce, Social Media, Task Management)
  - Best practices
  - Integration with Clean Architecture

### 💡 Usage Examples

\`\`\`bash
# Create entity with fields
zfa entity create -n User --field name:String --field email:String? --field age:int

# Create enum
zfa entity enum -n Status --value active,inactive,pending

# Create polymorphic sealed class
zfa entity create -n PaymentMethod --sealed --subtype=$CreditCard --subtype=$PayPal

# Build all generated code
zfa build --watch

# Use with Clean Architecture
zfa entity create -n Product --field name:String --field price:double
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state
zfa build
\`\`\`

### 🐛 Fixes

- Fixed dependency conflicts between zorphy and flutter_test
- Fixed meta version constraints
- Fixed test_api version compatibility

### 📖 Migration from 2.0.1

No breaking changes! Entity commands are purely additive:

\`\`\`bash
# Old commands still work
zfa generate Product --methods=get,getList --vpc --state
zfa initialize

# New entity commands available
zfa entity create -n User --field name:String
zfa entity enum -n Status --value active,inactive
zfa build
\`\`\`

### 🎯 Benefits

1. **Single CLI for Everything** - No need to install separate tools
2. **Type-Safe Entities** - Compile-time safety for all data models
3. **Polymorphism Support** - Sealed classes with exhaustive checking
4. **Auto-Imports** - Nested entities automatically imported
5. **JSON Ready** - Built-in serialization/deserialization
6. **IDE Integration** - Full MCP server support
7. **Comprehensive Docs** - 50+ examples in ENTITY_GUIDE.md

### 🔗 Links

- [Zorphy GitHub](https://github.com/arrrrny/zorphy)
- [Entity Guide](ENTITY_GUIDE.md)
- [CLI Guide](CLI_GUIDE.md)
- [MCP Server](MCP_SERVER.md)

---

## [2.0.1] - 2026-02-03

### Chore

Updated examples and docs

## [2.0.0] - 2026-02-03

### 🚀 Major Release - Clean Architecture Framework

ZFA 2.0.0 transforms from a CRUD generator into a complete Clean Architecture framework with orchestration and polymorphic patterns.

### ⚠️ Breaking Changes

- **`--repos` → `--repo`**: Custom UseCases now accept single repository (enforces Single Responsibility Principle)
  - Old: `--repos=Cart,Order,Payment`
  - New: `--repo=Checkout` (one UseCase, one repository)
- **`--domain` required**: All custom UseCases must specify domain folder
  - Example: `--domain=search`, `--domain=checkout`
- **Repository method naming**: UseCase name automatically maps to repository method
  - `SearchProductUseCase` → `productRepo.searchProduct()`
  - `ProcessCheckoutUseCase` → `checkoutRepo.processCheckout()`
 - **`--repository` removed**: All entity based operations automaticaly creates the repository. Custom usecases create repository if non existed or add method to the existing repository with`--append` flag
 

### ✨ New Features

#### Orchestrator Pattern
Compose multiple UseCases into workflows:
```bash
zfa generate SearchProduct \
  --usecases=GenerateZiks,ParseZik,DetectCategory \
  --domain=search \
  --params=Spark \
  --returns=Listing
```

Generates UseCase that injects and orchestrates other UseCases (no repositories).

#### Polymorphic Pattern
Generate abstract base + concrete variants + factory:
```bash
zfa generate SparkSearch \
  --type=stream \
  --variants=Barcode,Url,Text \
  --domain=search \
  --repo=Search \
  --params=Spark \
  --returns=Listing
```

Generates:
- Abstract `SparkSearchUseCase`
- `BarcodeSparkSearchUseCase`, `UrlSparkSearchUseCase`, `TextSparkSearchUseCase`
- `SparkSearchUseCaseFactory` with runtime type switching

#### Domain Organization
UseCases organized by domain concept (DDD-style):
```
domain/usecases/
├── product/          # Product domain
├── search/           # Search domain
├── checkout/         # Checkout domain
└── zik/              # Custom domain
```

### Added

- **`--repo`**: Single repository injection (replaces `--repos`)
- **`--usecases`**: Comma-separated UseCases for orchestration
- **`--variants`**: Comma-separated variants for polymorphic pattern
- **`--domain`**: Required domain folder for custom UseCases
- **UseCase path resolution**: Convention-based with file search fallback
- **Automatic import resolution**: Finds and imports composed UseCases
- **`--append` flag** - Append methods to existing repository/datasource files without regenerating
  - Automatically finds and updates Repository, DataRepository, DataSource, RemoteDataSource, and MockDataSource
  - Generates UseCase file and appends method signatures to all related files
  - Gracefully handles missing files with warning messages
  - Example: `zfa generate WatchProduct --domain=product --repo=Product --params=String --returns=Stream<Product> --type=stream --append`

### Changed
- Allow `query-field=null` to disable ID-based queries (use `NoParams` instead)
- Simplified DI generation - removed UseCase, Presenter, and Controller registration (manual registration recommended)
- **Removed `--subdirectory` flag** - Use `--domain` instead for organizing custom UseCases
  - Custom UseCases now create files in `usecases/{domain}/` folder
  - Example: `--domain=product` creates `usecases/product/watch_product_usecase.dart`
- **Custom UseCases**: Now require `--domain` and `--repo` (except orchestrators/background)
- **UseCase organization**: Grouped by domain concept instead of flat structure
- **Repository method naming**: Auto-matches UseCase name (e.g., `SearchProduct` → `searchProduct()`)

### Fixed
- DataSource interface now includes `@override` annotations for watch methods
- Custom UseCases now respect `--domain` flag for folder organization

### Migration Guide (1.x → 2.0.0)

#### Before (1.x)
```bash
zfa generate ProcessCheckout --repos=Cart,Order,Payment --params=Request --returns=Order
```

#### After (2.0.0)

**Option 1: Single Repository (Recommended)**
```bash
zfa generate ProcessCheckout --repo=Checkout --domain=checkout --params=Request --returns=Order
```

**Option 2: Orchestrator Pattern**
```bash
# Create atomic UseCases
zfa generate ValidateCart --repo=Cart --domain=checkout --params=CartId --returns=bool
zfa generate CreateOrder --repo=Order --domain=checkout --params=OrderData --returns=Order
zfa generate ProcessPayment --repo=Payment --domain=checkout --params=PaymentData --returns=Receipt

# Orchestrate them
zfa generate ProcessCheckout \
  --usecases=ValidateCart,CreateOrder,ProcessPayment \
  --domain=checkout \
  --params=CheckoutRequest \
  --returns=Order
```

## [1.16.0] - 2026-02-02

### Added
- **`--query-field=null` Support**: Generate parameterless methods for singleton/global entities
  - Repository: `Future<T> get()` instead of `Future<T> get(String id)`
  - UseCase: `UseCase<T, NoParams>` instead of `UseCase<T, QueryParams<String>>`
  - DataSource, Presenter, Controller all use parameterless signatures
  - Works with `get`, `watch`, `update`, and `delete` methods
  - Automatic test generation with `NoParams`

### Changed
- **Simplified DI Generation**: Removed UseCase, Presenter, and Controller registration
  - `--di` now only generates DataSource and Repository registration
  - UseCases handled by Zuraffa's built-in mechanisms
  - Presenters and Controllers instantiated directly in Views
  - Cleaner DI with focus on infrastructure concerns only
- **Conditional List Updates**: Controller methods only update lists when list methods exist
  - `create` only adds to list if `getList` or `watchList` is generated
  - `update` only updates list if `getList` or `watchList` is generated
  - `delete` only removes from list if `getList` or `watchList` is generated
  - Prevents unnecessary state updates and compilation errors

### Fixed
- **Query Field Handling**: Fixed `--query-field=null` across all layers
  - DataSource interface generates parameterless methods
  - RemoteDataSource implementation matches interface
  - DataRepository (simple and cached) handle parameterless calls
  - Controller update method uses direct assignment instead of field comparison
  - Test generator creates correct mock expectations

## [1.15.0] - 2026-02-02

### Added
- **Automatic Cache Initialization**: Auto-generated cache files for Hive
  - `cache/` folder with entity-specific cache init files
  - `hive_registrar.dart` with `@GenerateAdapters` for all cached entities
  - `hive_manual_additions.txt` template for nested entities and enums
  - `timestamp_cache.dart` for cache policy timestamp storage
  - `initAllCaches()` function that registers adapters and opens all boxes
  - Automatic index file generation with exports
- **Cache Policy Generation**: Auto-generated cache policy implementations
  - Separate files per policy type: `daily_cache_policy.dart`, `app_restart_cache_policy.dart`, `ttl_<N>_minutes_cache_policy.dart`
  - Full Hive implementation with timestamp box operations
  - `--ttl=<minutes>` flag for custom TTL duration (default: 1440 = 24 hours)
- **Mock DataSource Support for Cache**: `--use-mock` now works with `--cache`
  - Registers mock datasource as remote datasource in cached repositories
  - Enables full development workflow without backend
- **Manual Adapter Registration**: `hive_manual_additions.txt` for nested entities
  - Simple format: `import_path|EntityName`
  - Auto-merged with cached entities in registrar
  - Supports enums, nested entities, and custom types
- **VPCS Flag**: New `--vpcs` flag for complete presentation layer generation
  - Generates View + Presenter + Controller + State in one command
  - Shorthand for `--vpc --state`

### Changed
- **DataRepository Type Safety**: Remote datasource now uses abstract `DataSource` type
  - Allows easy switching between implementations (remote, mock, etc.)
  - Example: `final ProductDataSource _remoteDataSource;` instead of `ProductRemoteDataSource`
- **Enum Mock Data**: Changed from `seed % 3` to `seed % 2` for safer enum value generation
  - Prevents index errors with enums that have only 2 values
- **Hive Registrar Import**: Uses `hive_ce_flutter` instead of `hive_ce`
  - Consistent with Flutter projects

### Fixed
- **Snake Case Entity Names**: Proper PascalCase conversion in Hive registrar
  - `category_config` → `CategoryConfig` (not `Category_config`)

## [1.14.0] - 2026-02-01

### Added
- **Dependency Injection Generation**: New `--di` flag generates get_it DI files
  - One file per component (datasource, repository, usecase, presenter, controller)
  - Auto-generated index files via directory scanning
  - Supports `--cache` for dual datasource registration
  - Supports `--use-mock` to register mock datasources instead of remote
- **Granular VPC Generation**: New flags for selective presenter/controller generation
  - `--pc`: Generate Presenter + Controller only (preserve custom View)
  - `--pcs`: Generate Presenter + Controller + State (preserve custom View)
  - `--vpc`: Still available for full View + Presenter + Controller generation
- **Mock DataSource Control**: New `--use-mock` flag
  - When used with `--di`, registers mock datasource instead of remote
  - Useful for development and testing without backend
- **Remote DataSource Always Generated**: `--data` now always generates remote datasource implementation
  - Previously only generated with `--cache`
  - More intuitive default behavior

### Changed
- **Presenter DI Registration**: Fixed to inject only repositories (not usecases)
  - Presenters create usecases internally via `registerUseCase()`
  - Matches actual presenter implementation pattern

### Fixed
- **DI Generation**: Removed extra closing parenthesis in presenter registration

## [1.13.0] - 2026-02-01

### Added
- **Cache Storage Default**: `--cache` now defaults to `--cache-storage=hive` automatically
- **Abstract DataSource Generation**: Always generate abstract datasource interface, even with `--cache`
- **Initialize Method Support**: Added `--init` flag support for cache datasources
  - Remote and local datasources implement initialize methods when `--init` is used
  - Data repository delegates initialization to remote datasource
  - Proper `@override` annotations on all interface implementations

### Fixed
- **VPC Generator**: Reverted to working presenter generation with proper `Presenter` base class and `registerUseCase()`
- **Mock Data Generation**:
  - Respect `--id-field` parameter in mock datasources (e.g., `--id-field=name`)
  - Use `const Duration()` for DateTime mock values for better performance
  - Fixed `DeleteParams` usage in mock datasource delete methods
  - Added proper spacing between generated methods
  - Fixed List<String> generation to use actual strings instead of `String()` constructors
  - Fixed duplicate map keys in generated mock data
  - Improved Zorphy entity support - parse generated `.zorphy.dart` files for complete field information
  - Only generate enum imports when entity actually contains enum fields
  - Exclude primitive types, generics, and enums from nested entity generation
  - Fixed seeded DateTime generation to remove invalid `const` usage
- **DataSource Generation**:
  - Remote and local datasources always include `with Loggable, FailureHandler` mixins
  - Proper `implements` clause ordering (after `with` mixins)
  - Added missing `@override` annotations for interface method implementations
  - Initialize methods properly added to both remote and local datasources when `--init` is used
- **Entity Analysis**: 
  - Never use fallback fields - only parse actual entity fields from source files
  - Improved class regex to handle `extends` and `implements` clauses
  - Better support for Zorphy generated classes with complex inheritance

### Improved
- **Mock Data Quality**: More realistic and varied mock data generation
- **Type Safety**: Better handling of complex generic types and nullable fields
- **Code Generation**: Cleaner generated code with proper formatting and annotations

## [1.12.1] - 2026-02-01

### Fixed
-  Mock data generation
- 
## [1.12.0] - 2026-02-01 

### Added
- **Mock Data Generation**: Comprehensive mock data generation system
  - `--mock` flag: Generate mock data files alongside other layers
  - `--mock-data-only` flag: Generate only mock data files
  - **Realistic Data**: Type-appropriate values for all field types (String, int, double, bool, DateTime, Object)
  - **Complex Types**: Full support for `List<T>`, `Map<K,V>`, nullable types
  - **Nested Entities**: Automatic detection and recursive generation with proper cross-references
  - **Zorphy Support**: Handles `$EntityName` syntax and zorphy annotations
  - **Smart Imports**: Single enum import (`enums/index.dart`) only when needed
  - **Large Datasets**: Generated methods for performance testing (100+ items)
  - **Null Safety**: Proper handling of optional fields with realistic null distribution

### Enhanced
- **Entity Analysis**: Improved entity field parsing with balanced brace matching
  - Handles complex generic types like `Map<String, String>` correctly
  - Fixed regex patterns for getter-style fields in abstract classes
  - Supports unlimited recursion depth for nested entity structures

- **MCP Server**: Added mock generation flags to Model Context Protocol server
  - `mock` and `mock_data_only` parameters available in MCP tools
  - Enhanced AI/IDE integration for mock data workflows

## [1.11.1] - 2026-02-01

### Fixed
- **Singleton Entity Key Collision**: Fixed Hive storage key collision for singleton entities
  - Now uses entity snake_case name as key instead of generic `'singleton'`
  - Each entity gets unique storage: `GoogleCookie` → `'google_cookie'`, `AppConfig` → `'app_config'`
  - Prevents data overwriting between different singleton entities

- **Data Layer Generator**: Fixed undefined `relativePath` variable in data repository generation
  - Added missing variable declaration in `generateDataRepository` method
  - Fixed import path string interpolation for data sources
  - Ensures correct import paths when using subdirectories and caching features

## [1.11.0] - 2026-02-01

### Added
- **Initialize Command**: New `zfa initialize` command to quickly create sample entities
  - `--entity` parameter to specify entity name (default: Product)
  - Creates realistic sample entity with common fields (id, name, description, price, category, isActive, createdAt, updatedAt)
  - Includes complete implementation with copyWith, equals, hashCode, toString, JSON serialization
  - Added to MCP server as `initialize` tool for AI agent integration
  - Updated CLI help and README documentation

- **Singleton Entity Support**: New `--id-field=null` flag for parameterless operations
  - Generates `get()` and `watch()` methods without ID parameters using `NoParams`
  - Perfect for singleton entities like app config, user sessions, global settings
  - Uses fixed `'singleton'` key for Hive storage instead of entity ID
  - Validation prevents usage with list methods (`getList`, `watchList`)

### Changed
- **Optimized Repository Imports**: Repository interfaces now conditionally import zuraffa
  - Only imports `package:zuraffa/zuraffa.dart` when using zuraffa types (ListQueryParams, UpdateParams, DeleteParams)
  - Simple repositories with only `get()` methods have no zuraffa import
  - Keeps repository interfaces clean and minimal

- **Improved Local DataSource Generation**: 
  - No `saveAll()` method generated for singleton entities (`--id-field=null`)
  - Uses `'singleton'` key for Hive operations instead of entity field access

### Fixed
- **Test Generation for Singleton Entities**: Fixed mock repository calls in generated tests
  - Parameterless methods now use `mockRepository.get()` instead of `mockRepository.get(any())`
  - Fixed both success and failure test scenarios for Future and Stream UseCases
  - Eliminates "too many arguments" compilation errors

## [1.12.0] - 2026-02-01

### Fixed
- **Background UseCase Generation**: Fixed `--returns` and `--params` parameters for background UseCases
  - Now properly uses specified return type instead of defaulting to `void`
  - Generates `context.sendData(result)` to return the processed result
  - Includes helper `processData()` method with correct type signatures
  - Auto-imports custom params and returns entity types

- **Custom UseCase File Structure**: Fixed custom UseCases to follow entity naming structure
  - Now generates in subfolders: `lib/src/domain/usecases/parsing_task/parsing_task_usecase.dart`
  - Updated import paths to account for subfolder structure (`../../entities/` instead of `../entities/`)
  - Consistent with entity-based UseCase organization

## [1.10.0] - 2026-02-01

### Added
- **Caching Support**: New dual datasource pattern for intelligent caching
  - `--cache` flag to enable caching with remote and local datasources
  - `--cache-policy` option: `daily`, `restart`, or `ttl` (default: daily)
  - `--cache-storage` option: `hive` for Hive implementation (more coming soon)
  - `CachePolicy` abstraction with `DailyCachePolicy`, `AppRestartCachePolicy`, and `TtlCachePolicy`
  - Automatic cache-aware repository generation with validity checks
  - Complete Hive implementation when `--cache-storage=hive` is specified
  - Local datasource with `save()`, `saveAll()`, `get()`, `getList()` methods
  - Remote datasource for API/external service calls
  - Cache invalidation support via `CachePolicy.invalidate()`

### Changed
- Remote and local datasources are now standalone implementations (no abstract interface)
- Updated to use `hive_ce_flutter` package for Hive support

### Fixed
- Import paths in generated datasources and repositories
- Repository imports now correctly use `../../domain/` paths

## [1.9.0] - 2026-01-31

### Added
- **Test Generation (`--test`)**: New flag to generate unit tests for generated UseCases with comprehensive mock setup and test scenarios.

## [1.8.0] - 2026-01-31

### Added
- **New Failure Types**: Added `StateFailure`, `TypeFailure`, `UnimplementedFailure`, `UnsupportedFailure`, and `PlatformFailure` to `AppFailure` for granular error handling.

### Changed
- **FailureHandler**:
  - Now uses a `switch` statement for improved performance and readability.
  - Correctly maps `PlatformException` (Flutter) to `PlatformFailure`.
  - Maps `MissingPluginException` to `UnsupportedFailure`.
  - Maps `ArgumentError`, `RangeError`, `FormatException` to `ValidationFailure`.
  - Maps `ConcurrentModificationError`, `StateError`, `StackOverflowError` to `StateFailure`.
- **Generated Repositories**: Fixed missing `zuraffa` import in generated repository files.


### Fixed
- **TodoDataSource**: Updated `InMemoryTodoDataSource` to fully implement the interface.

## [1.7.0] - 2026-01-31
### Added
- **Typed Updates (`--zorphy`)**: New flag to generate update operations using typed Patch objects (e.g., `CustomerPatch`) instead of Map-based partials.
- **Partial Updates**: Default update mechanism now uses `Partial<T>` (Map<String, dynamic>) with automatic field extraction for validation.
- **Validation**:
  - `UpdateParams.validate()` automatically checks fields against your entity definition.
  - `FailureHandler` now catches `ArgumentError` (common in validation) and converts it to `ValidationFailure`.
- **New Parameter Wrappers**:
  - `ListQueryParams`: Standardized params for list queries (filtering, sorting, pagination).
  - `DeleteParams`: Standardized params for delete operations.
  - `UpdateParams<T>`: Now generic over data type to support both Maps and Patch objects.
- **CLI Global Flags**:
  - `--zorphy`: Enable Zorphy-style patch objects.
  - `--id-field` & `--id-field-type`: Customize the identifier field name and type (default: 'id', 'String').
  - `--query-field` & `--query-field-type`: Customize the lookup field definition for `get`/`watch` methods.

### Changed
- **Scripts**: Updated `publish.sh` to support "promote unreleased" workflow.

## [1.6.2] - 2026-01-31

### Fix
- Subdirectory path issue on generated data repository

## [1.6.1] - 2026-01-31

### Fix
- Subdirectory path issue on generated presenters

## [1.6.1] - 2026-01-31

### Fix
- Subdirectory path issue on generated presenters

## [1.6.0] - 2026-01-31

### Change
- fixed not overriding onInitState from CleanView, updated state generation to generate entity

## [1.5.0] - 2026-01-30

### Fix
- mcp server connection fix

## [1.4.2] - 2026-01-27

### Change
- Release 1.4.2

## [1.4.1] - 2026-01-26

### Feat
- Added InitializationParams and --init flag to cli

## [1.5.0] - 2026-01-30

### Fix
- mcp server connection fix

## [1.4.2] - 2026-01-27

### Change
- Release 1.4.2

## [1.4.1] - 2026-01-26

### Feat
- Added InitializationParams and --init flag to cli

## [1.4.0] - 2026-01-24

### Feat
- Added --subdirectory flag to zfa cli

## [1.3.3] - 2026-01-24

### Chore
- testing CI

## [1.3.1] - 2026-01-24

### Chore
- CI chores

## [1.3.0] - 2026-01-24

### Chore
- CI chores

## [1.2.0] - 2026-01-24

### Changed
- Exposed Loggable mixin and added to generated DataRepos

## [1.1.0] - 2026-01-24

### Changed
- Updated MCP server method names and documentation.

## [1.0.1] - 2026-01-23

### Chore
- Updated description in pubspec.yaml to better reflect package purpose and fit the required 180 character limit.

## [1.0.0] - 2026-01-23

### Added

#### Core Framework
- **Result Type**: Type-safe error handling with `Result<S, F>` sealed class
- **AppFailure Hierarchy**: Comprehensive sealed class hierarchy for error classification
  - `ServerFailure` - HTTP 5xx errors
  - `NetworkFailure` - Connection issues
  - `ValidationFailure` - Input validation errors
  - `NotFoundFailure` - HTTP 404 / resource not found
  - `UnauthorizedFailure` - HTTP 401 / authentication required
  - `ForbiddenFailure` - HTTP 403 / access denied
  - `TimeoutFailure` - Request timeout
  - `CacheFailure` - Local storage errors
  - `ConflictFailure` - HTTP 409 / version conflicts
  - `CancellationFailure` - Operation cancelled
  - `UnknownFailure` - Catch-all for unclassified errors
- **UseCase**: Single-shot operations returning `Future<Result<T, AppFailure>>`
- **CompletableUseCase**: Operations returning `Result<void, AppFailure>`
- **StreamUseCase**: Reactive operations returning `Stream<Result<T, AppFailure>>`
- **BackgroundUseCase**: CPU-intensive operations on isolates with `BackgroundTask`
- **Controller**: State management with automatic cleanup and lifecycle hooks
- **Presenter**: Optional orchestration layer for complex business flows
- **CleanView & CleanViewState**: Base classes for views with automatic lifecycle management
- **ResponsiveViewState**: Responsive layouts with device-specific builders
- **ControlledWidgetBuilder**: Rebuild widgets when Controller calls `refreshUI()`
- **ControlledWidgetSelector**: Fine-grained rebuilds based on selected values
- **CancelToken**: Cooperative cancellation for long-running operations
- **NoParams**: Sentinel for parameterless UseCases
- **Observer**: Optional callback-based stream listener

#### CLI Tool
- **zfa CLI**: Powerful code generator for Clean Architecture boilerplate
  - Entity-based UseCase generation with `--methods`
  - Custom UseCase generation with `--params` and `--returns`
  - Repository interface generation with `--repository`
  - Presentation layer generation with `--vpc`
  - Data layer generation with `--data`
  - Data source generation with `--datasource`
  - State object generation with `--state`
  - JSON output format with `--format=json`
  - Stdin input support with `--from-stdin`
  - Dry run mode with `--dry-run`
  - Verbose logging with `--verbose`
  - Force overwrite with `--force`
- **zfa validate**: Validate JSON generation configs
- **zfa schema**: Get JSON schema for config validation
- **Dual executable support**: Both `zuraffa` and `zfa` commands available

#### MCP Server
- **zuraffa_mcp_server**: Model Context Protocol server for AI/IDE integration
  - `zuraffa_generate` tool for code generation
  - `zuraffa_schema` tool for schema retrieval
  - `zuraffa_validate` tool for config validation
  - Resource change notifications for generated files
  - Precompiled binary support for faster startup

#### Extensions & Utilities
- **Future Extensions**: Convert futures to `Result` type
- **Test Utilities**: Matchers and test helpers
- **Logging**: Global logging configuration via `Zuraffa.enableLogging()`
- **Controller Access**: `Zuraffa.getController<T>()` for accessing controllers from widget tree

#### Documentation
- Comprehensive README with quick start guide
- CLI Guide with all command options
- MCP Server documentation
- AI Agents guide for AI-assisted development
- Example application demonstrating all features

### Features

- **Type-safe error handling**: All operations return `Result<T, AppFailure>` for exhaustive error handling
- **Sealed class hierarchies**: Pattern matching with compile-time exhaustiveness checks
- **Automatic cleanup**: Controllers automatically cancel operations and subscriptions on dispose
- **Fine-grained rebuilds**: Optimized performance with selective widget updates
- **Cooperative cancellation**: CancelToken for cancelling long-running operations
- **Background processing**: Run CPU-intensive work on isolates without blocking UI
- **Reactive streams**: StreamUseCase for real-time data updates
- **CLI code generation**: Generate boilerplate with a single command
- **AI/IDE integration**: MCP server for seamless AI agent integration
- **Testable**: Pure domain layer with easy mocking and testing

### Dependencies

- `flutter`: ^3.10.0
- `args`: ^2.7.0
- `logging`: ^1.3.0
- `meta`: ^1.12.0
- `path`: ^1.9.0
- `provider`: ^6.1.5+1
- `responsive_builder`: ^0.7.1
- `flutter_lints`: ^6.0.0 (dev)
- `mocktail`: ^1.0.4 (dev)

### Documentation

- Added comprehensive README with examples
- Added CLI Guide with all options
- Added MCP Server documentation
- Added AI Agents guide
- Added contributing guidelines
- Added code of conduct

### Example Application

- Complete Todo app demonstrating all framework features
- UseCase examples (single-shot, stream, background)
- Controller and View examples
- Error handling examples
- Cancellation examples
- State management examples

### Planned Features

- Web support for BackgroundUseCase
- Additional code generation templates
- More validation failure types
- Performance monitoring utilities
- Extended documentation and tutorials

---

## Version Summary

- **1.0.0** - Initial release with complete Clean Architecture framework, CLI tool, and MCP server
