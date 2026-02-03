# Zuraffa CLI Testing Suite

This document contains a comprehensive list of all possible commands and options for the Zuraffa CLI, organized by functionality for testing purposes.

## Main Commands

### 1. Generate Command (`zfa generate`)
Generate Clean Architecture code for entities or custom usecases.

#### Basic Usage
```
zfa generate <Name> [options]
```

#### Entity-Based Generation Options
- `--methods=<list>` - Comma-separated methods: get,getList,create,update,delete,watch,watchList
- `-r, --repository` - Generate repository interface
- `-d, --data` - Generate data repository implementation + data source
- `--datasource` - Generate DataSource only
- `--init` - Generate initialize method for repository and datasource
- `--id-field=<name>` - ID field name (default: id)
- `--id-field-type=<t>` - ID field type (default: String)
- `--query-field=<name>` - Query field name for get/watch (default: id)
- `--query-field-type=<t>` - Query field type (default: matches id-field-type)
- `--morphy` - Use Morphy-style typed patches (e.g. EntityPatch)

#### Caching Options
- `--cache` - Enable caching with dual datasources (remote + local)
- `--cache-policy=<p>` - Cache policy: daily, restart, ttl (default: daily)
- `--cache-storage=<s>` - Local storage hint: hive, sqlite, shared_preferences
- `--ttl=<minutes>` - TTL duration in minutes (default: 1440 = 24 hours)

#### Mock Data Options
- `--mock` - Generate mock data source with sample data
- `--mock-data-only` - Generate only mock data file (no data source)
- `--use-mock` - Use mock datasource in DI (default: remote datasource)

#### Dependency Injection Options
- `--di` - Generate dependency injection files (get_it)

#### Custom UseCase Options
- `--repos=<list>` - Comma-separated repositories to inject
- `--type=<type>` - usecase|stream|background|completable (default: usecase)
- `--params=<type>` - Params type (default: NoParams)
- `--returns=<type>` - Return type (default: void)

#### VPC Layer Options
- `--vpc` - Generate View + Presenter + Controller
- `--vpcs` - Generate View + Presenter + Controller + State
- `--pc` - Generate Presenter + Controller only (preserve View)
- `--pcs` - Generate Presenter + Controller + State (preserve View)
- `--view` - Generate View only
- `--presenter` - Generate Presenter only
- `--controller` - Generate Controller only
- `--state` - Generate State object with granular loading states
- `--observer` - Generate Observer class
- `-t, --test` - Generate Unit Tests

#### Input/Output Options
- `-j, --from-json` - JSON configuration file
- `--from-stdin` - Read JSON from stdin
- `-o, --output` - Output directory (default: lib/src)
- `--format=json|text` - Output format (default: text)
- `--dry-run` - Preview without writing files
- `--force` - Overwrite existing files
- `-v, --verbose` - Verbose output
- `-q, --quiet` - Minimal output

#### Example Commands
```
# Entity-based CRUD with VPC and State
zfa generate Product --methods=get,getList,create,update,delete --repository --vpc --state

# With data layer (repository impl + datasource)
zfa generate Product --methods=get,getList,create,update,delete --repository --data

# Stream usecases
zfa generate Product --methods=watch,watchList --repository

# Custom usecase with multiple repos
zfa generate ProcessOrder --repos=OrderRepo,PaymentRepo --params=OrderRequest --returns=OrderResult

# Background usecase
zfa generate ProcessImages --type=background --params=ImageBatch --returns=ProcessedImage

# From JSON
zfa generate Product -j product.json

# From stdin (AI-friendly)
echo '{"name":"Product","methods":["get","getList"]}' | zfa generate Product --from-stdin --format=json
```

### 2. Initialize Command (`zfa initialize`)
Initialize a test entity to quickly try out Zuraffa.

#### Basic Usage
```
zfa initialize [options]
zfa init [options]
```

#### Options
- `-e, --entity` - Entity name to generate (default: Product)
- `-o, --output` - Output directory (default: lib/src)
- `-f, --force` - Overwrite existing files
- `--dry-run` - Preview what would be generated without writing files
- `-v, --verbose` - Enable verbose output
- `-h, --help` - Show help

#### Example Commands
```
zfa initialize                           # Generate Product entity
zfa initialize --entity=User             # Generate User entity
zfa init -e Order --output=lib/src       # Generate Order entity in lib/src
zfa initialize --dry-run                 # Preview without writing files
```

### 3. Create Command (`zfa create`)
Create architecture folders and files.

#### Basic Usage
```
zfa create [options]
```

#### Options
- `-p, --page <name>` - Creates a page with the given name (snake_case format)
- `-h, --help` - Show help

#### Example Commands
```
zfa create --page user_profile
zfa create --page product_detail
zfa create
```

### 4. Schema Command (`zfa schema`)
Output JSON schema for configuration.

#### Basic Usage
```
zfa schema
```

### 5. Validate Command (`zfa validate`)
Validate JSON configuration file.

#### Basic Usage
```
zfa validate <json-file>
```

#### Example Commands
```
zfa validate config.json
```

### 6. Help Command (`zfa help`)
Show help information.

#### Basic Usage
```
zfa help
zfa --help
zfa -h
```

### 7. Version Command (`zfa version`)
Show version information.

#### Basic Usage
```
zfa version
zfa --version
zfa -v
```

## Common Flags and Options

### Global Options
- `--dry-run` - Preview without writing files (available for most commands)
- `--force` - Overwrite existing files
- `--verbose, -v` - Verbose output
- `--help, -h` - Show help
- `--quiet, -q` - Minimal output

### Method Types for Entity-Based Generation
- `get` - Single item retrieval
- `getList` - Multiple items retrieval
- `create` - Item creation
- `update` - Item update
- `delete` - Item deletion
- `watch` - Single item streaming
- `watchList` - Multiple items streaming

### UseCase Types
- `usecase` - Standard usecase
- `stream` - Streaming usecase
- `background` - Background processing usecase
- `completable` - Completable usecase

### Cache Policies
- `daily` - Daily cache policy (default)
- `restart` - Cache until app restart
- `ttl` - Time-to-live cache policy

### Cache Storage Options
- `hive` - Hive storage (default when cache enabled)
- `sqlite` - SQLite storage
- `shared_preferences` - Shared preferences storage

## Expected Behavior and Outcomes

### Success Cases
- Commands execute without errors
- Files are generated in the correct locations
- Generated code follows Clean Architecture patterns
- Dependencies are properly injected
- Tests are generated when requested

### Error Handling
- Invalid command combinations produce helpful error messages
- Missing required parameters trigger appropriate error messages
- File conflicts are handled according to --force flag
- Invalid entity names are rejected with clear messaging

### Dry Run Mode
- No files are written to disk
- Preview of what would be generated is displayed
- All validation checks still occur
- Exit code indicates success/failure of validation

## Testing Scenarios

### Positive Test Cases
1. Basic entity generation with all methods
2. Custom usecase generation with parameters
3. VPC layer generation with state management
4. Data layer generation with caching
5. Mock data generation
6. Dependency injection file generation
7. Page creation with create command
8. Entity initialization

### Negative Test Cases
1. Invalid method combinations
2. Missing required parameters for custom usecases
3. Conflicting options
4. Invalid entity names
5. Non-existent JSON configuration files
6. Permission errors for file writing
7. Invalid cache policies

### Edge Cases
1. Empty method lists
2. Very long entity names
3. Special characters in entity names
4. Nested directory structures
5. Large numbers of methods
6. Complex parameter types