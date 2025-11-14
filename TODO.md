# 🦒 Zuraffa Development Checklist

**Goal:** Single command → Flutter app displays data automatically

```bash
$ zuraffa create usecase GetProduct --from-json product.json
# → Flutter app shows Product on screen
```

---

## 📦 Phase 1: Core Package Setup (Week 1)

### Project Structure
- [ ] Create package structure (lib/, bin/, test/)
- [ ] Setup pubspec.yaml with dependencies
- [ ] Create basic CLI entry point (bin/zuraffa.dart)
- [ ] Setup dart pub global activate workflow
- [ ] Add .gitignore

### JSON Parser (Primitives Only)
- [ ] Implement JSON type inference (String, int, double, bool, DateTime)
- [ ] Detect nested objects → separate entities
- [ ] Detect List<T> → handle arrays
- [ ] Handle nullable fields (null in JSON → T?)
- [ ] ISO 8601 DateTime detection
- [ ] Tests for JSON parser (100% coverage)

### Morphy Entity Generator
- [ ] Generate @morphy abstract class $Entity
- [ ] Handle nested references with $ prefix ($Customer, List<$OrderItem>)
- [ ] Add @Morphy(generateJson: true) annotation
- [ ] Generate proper imports
- [ ] Naming: PascalCase for entities, camelCase for fields
- [ ] Tests for entity generator

### Build Runner Integration
- [ ] Auto-detect when entities need generation
- [ ] Run `dart run build_runner build` automatically
- [ ] Handle build_runner errors gracefully
- [ ] Delete conflicting outputs option
- [ ] Show progress during build

---

## 🧪 Phase 2: TDD Engine (Week 2)

### AI Test Generator
- [ ] Setup Anthropic Claude API integration
- [ ] Read API key from .env or environment
- [ ] Generate UseCase tests (success, failure, edge cases)
- [ ] Generate Repository tests (cache-first logic)
- [ ] Generate DataSource tests (remote, local, mock)
- [ ] Generate Entity tests (JSON round-trip, equality, copyWith)
- [ ] Target: 15-20 test cases per UseCase
- [ ] Use mocktail for mocking

### TDD Workflow (Red-Green-Refactor)
- [ ] 🔴 RED: Generate tests first
- [ ] Run tests, expect failures
- [ ] Verify 0% coverage initially
- [ ] 🟢 GREEN: Generate implementation
- [ ] Run tests, expect success
- [ ] Verify 100% coverage
- [ ] 🔵 REFACTOR: AI suggestions (optional for v1.0)
- [ ] Block generation if STRICT_TDD=true and tests fail

### Test File Generation
- [ ] Generate test files with proper imports
- [ ] Generate mock classes (MockProductRepository, etc.)
- [ ] Generate test fixtures from JSON samples
- [ ] Setup setUp() and tearDown() properly
- [ ] Use `test/fixtures/` for JSON samples

---

## 🏗️ Phase 3: DataSource + Repository Generation (Week 2)

### DataSource Interface (Domain Layer)
- [ ] Generate abstract ProductDataSource
- [ ] Methods return Future<Map<String, dynamic>> (raw JSON)
- [ ] Include getX, searchX, saveX methods
- [ ] Place in lib/domain/datasources/

### Remote DataSource (Data Layer)
- [ ] Generate RemoteProductDataSource
- [ ] Inject Dio HTTP client
- [ ] Handle GET/POST/PUT/DELETE
- [ ] Map HTTP errors to exceptions (NetworkException, etc.)
- [ ] Include auth headers (Bearer token)
- [ ] Place in lib/data/datasources/

### Local DataSource (Data Layer)
- [ ] Generate LocalProductDataSource
- [ ] Inject Hive Box
- [ ] Implement cache with expiry (_cachedAt timestamp)
- [ ] Throw CacheException when not found
- [ ] Throw CacheExpiredException when expired
- [ ] Place in lib/data/datasources/

### Mock DataSource (Test Layer)
- [ ] Generate MockProductDataSource
- [ ] Accept Map<String, Map<String, dynamic>> mock data
- [ ] Simulate network delay (configurable)
- [ ] Throw exceptions for missing data
- [ ] Place in test/mocks/ (optional) or lib/data/datasources/

### Repository Interface (Domain Layer)
- [ ] Generate abstract ProductRepository
- [ ] Methods return Future<Product> (typed entities)
- [ ] Place in lib/domain/repositories/

### Repository Implementation (Data Layer)
- [ ] Generate DataProductRepository
- [ ] Inject remote + local DataSources
- [ ] Implement cache-first logic:
  - Try local cache first
  - On cache miss → fetch remote → save to cache
  - On cache expired → refresh from remote
- [ ] Convert JSON to entities via Product.fromJson()
- [ ] Handle all exceptions properly
- [ ] Place in lib/data/repositories/

---

## 🎯 Phase 4: UseCase Generation (Week 3)

### UseCase Base Classes
- [ ] Create UseCase<Success, Failure, Params> base class
- [ ] Create StreamUseCase variant
- [ ] Create Result<Success, Failure> sealed class
- [ ] Create Success, Failure, Loading subtypes
- [ ] Implement .when() pattern matching
- [ ] Add .fold() for functional style

### UseCase Generator
- [ ] Generate GetProductUseCase
- [ ] Inject repository via ZuraffaDI
- [ ] Implement execute() method
- [ ] Wrap in try-catch → return Result<T>
- [ ] Map exceptions to Failure types
- [ ] Return Success on happy path
- [ ] Place in lib/domain/usecases/

### Exception Handling
- [ ] Define AppException base class
- [ ] ProductNotFoundException
- [ ] NetworkException
- [ ] CacheException
- [ ] InvalidInputException
- [ ] ServerException
- [ ] Map repository exceptions → AppException

---

## 💉 Phase 5: Dependency Injection (Week 3)

### ZuraffaDI Service Locator
- [ ] Implement simple service locator (or use GetIt)
- [ ] ZuraffaDI.register<T>(instance)
- [ ] ZuraffaDI.get<T>()
- [ ] Support named instances
- [ ] ZuraffaDI.reset() for tests
- [ ] Thread-safe implementation

### DI Setup Generator
- [ ] Generate setupDependencies() for main.dart
- [ ] Register all DataSources (Remote, Local)
- [ ] Register all Repositories
- [ ] Read API_BASE_URL from .env
- [ ] Initialize Hive boxes
- [ ] Setup Dio with interceptors

### Test DI Setup
- [ ] Generate setupTestDependencies()
- [ ] Register MockDataSources
- [ ] Load fixtures from test/fixtures/
- [ ] Easy to swap different mocks per test

---

## 🖥️ Phase 6: CLI Implementation (Week 4)

### Command Structure
- [ ] Use `args` package for CLI parsing
- [ ] Implement `zuraffa init <project_name>`
- [ ] Implement `zuraffa create usecase <name> --from-json <file>`
- [ ] Implement `zuraffa create usecase <name> --from-api <url>`
- [ ] Implement `zuraffa create feature <name> --interactive`
- [ ] Implement `zuraffa test generate <file>`
- [ ] Add --help for all commands
- [ ] Add --version flag

### Configuration Loading
- [ ] Read .env file (STRICT_TDD, API_BASE_URL, etc.)
- [ ] Read zuraffa.yaml config
- [ ] Merge .env + zuraffa.yaml + CLI flags
- [ ] Validate configuration
- [ ] Show warnings for missing config

### File System Operations
- [ ] Create directories if they don't exist
- [ ] Write files with proper formatting
- [ ] Add "Generated by Zuraffa" headers
- [ ] Preserve existing files (ask before overwrite)
- [ ] Color-coded terminal output (success, error, warning)

### AI Integration
- [ ] Setup Anthropic SDK
- [ ] Create prompts for test generation
- [ ] Create prompts for implementation generation
- [ ] Handle API errors gracefully
- [ ] Show progress during AI generation
- [ ] Cache API responses (optional optimization)

### Interactive Mode
- [ ] Prompt user for JSON input (paste mode)
- [ ] Detect Ctrl+D for end of input
- [ ] Validate JSON before processing
- [ ] Show preview of what will be generated
- [ ] Ask for confirmation before writing files

---

## 📱 Phase 7: Flutter Integration (Week 4)

### Example Flutter App
- [ ] Create example/ folder with Flutter app
- [ ] Implement main.dart with DI setup
- [ ] Create sample Product entity
- [ ] Create ProductPage with state management
- [ ] Show loading/error/success states with Result<T>.when()
- [ ] Display product data on screen
- [ ] Add refresh functionality
- [ ] Add error retry button

### State Management in UI
- [ ] Use StatefulWidget with setState
- [ ] Call UseCase from initState()
- [ ] Update state with Result<T>
- [ ] Rebuild UI with .when() pattern matching
- [ ] Show CircularProgressIndicator for loading
- [ ] Show error message + retry for failure
- [ ] Show actual data for success

### Example Flow (End-to-End)
- [ ] User runs: `zuraffa create usecase GetProduct --from-json product.json`
- [ ] Zuraffa generates all files
- [ ] User adds DI setup to main.dart (copy-paste from CLI output)
- [ ] User creates ProductPage
- [ ] User runs app
- [ ] App fetches product and displays it
- [ ] **SUCCESS!** Single command → Flutter app works

---

## 🧩 Phase 8: Polish & Documentation (Week 4)

### Error Handling
- [ ] Graceful error messages
- [ ] Suggest fixes for common errors
- [ ] Validate JSON before processing
- [ ] Check for missing dependencies
- [ ] Handle build_runner failures

### Logging
- [ ] Add verbose mode (--verbose flag)
- [ ] Log all file operations
- [ ] Log API calls to Claude
- [ ] Log test results
- [ ] Save logs to zuraffa.log

### Documentation
- [ ] Complete README.md
- [ ] API documentation
- [ ] Tutorial: Your First UseCase
- [ ] Tutorial: Building ZikZak
- [ ] Architecture diagram
- [ ] Contributing guidelines

### Examples
- [ ] Simple CRUD example
- [ ] ZikZak price comparison example
- [ ] Nested entities example
- [ ] Offline-first example
- [ ] Integration tests example

---

## 🚀 Phase 9: Testing & Validation (Week 5)

### Unit Tests (Zuraffa Package Itself)
- [ ] Test JSON parser
- [ ] Test entity generator
- [ ] Test DataSource generator
- [ ] Test Repository generator
- [ ] Test UseCase generator
- [ ] Test TDD workflow
- [ ] Test CLI commands
- [ ] Target: 100% coverage for Zuraffa package

### Integration Tests
- [ ] Generate sample project
- [ ] Run generated tests
- [ ] Verify 100% coverage
- [ ] Build Flutter app
- [ ] Run Flutter app
- [ ] Verify UI displays data

### Real-World Test: ZikZak
- [ ] Run Zuraffa on actual ZikZak JSON
- [ ] Generate price comparison feature
- [ ] Verify all tests pass
- [ ] Integrate into ZikZak app
- [ ] Test offline mode
- [ ] Test error handling
- [ ] **Validate: Single command works end-to-end**

---

## 📦 Phase 10: Publishing (Week 5)

### Package Preparation
- [ ] Set version to 1.0.0
- [ ] Complete CHANGELOG.md
- [ ] Add LICENSE (MIT)
- [ ] Verify pubspec.yaml metadata
- [ ] Add repository URL
- [ ] Add homepage URL
- [ ] Add documentation URL

### Pub.dev Publishing
- [ ] Run `dart pub publish --dry-run`
- [ ] Fix all warnings
- [ ] Verify package score will be high
- [ ] Publish to pub.dev
- [ ] Verify package page looks good

### GitHub Release
- [ ] Tag v1.0.0
- [ ] Create GitHub release
- [ ] Write release notes
- [ ] Attach binaries (if applicable)

### Documentation Site
- [ ] Create docs/ folder
- [ ] Setup GitHub Pages
- [ ] Add tutorials
- [ ] Add API reference
- [ ] Add examples

---

## ✅ Success Criteria

### v1.0 is DONE when:

1. **Single Command Works:**
   ```bash
   $ zuraffa create usecase GetProduct --from-json product.json
   ✓ 18 tests passing, 100% coverage, 6.8s
   ```

2. **Flutter Integration Works:**
   - User copies DI setup to main.dart
   - User creates ProductPage
   - App fetches and displays product
   - No manual code writing needed

3. **TDD Enforced:**
   - Tests always generated first
   - Implementation passes all tests
   - 100% coverage guaranteed

4. **ZikZak Use Case:**
   - Generate price comparison feature from actual JSON
   - All tests pass
   - Integrates into ZikZak app
   - Works offline

5. **Documentation Complete:**
   - README is clear
   - Tutorials work
   - Examples run
   - API docs complete

---

## 🎯 Current Status

**Phase:** 0 - Setup
**Progress:** 0%
**Next Task:** Create package structure

---

## 📊 Progress Tracking

- [ ] Phase 1: Core Package Setup (0/5 sections)
- [ ] Phase 2: TDD Engine (0/3 sections)
- [ ] Phase 3: DataSource + Repository (0/6 sections)
- [ ] Phase 4: UseCase Generation (0/3 sections)
- [ ] Phase 5: Dependency Injection (0/3 sections)
- [ ] Phase 6: CLI Implementation (0/5 sections)
- [ ] Phase 7: Flutter Integration (0/3 sections)
- [ ] Phase 8: Polish & Documentation (0/4 sections)
- [ ] Phase 9: Testing & Validation (0/3 sections)
- [ ] Phase 10: Publishing (0/3 sections)

**Total Progress: 0/280 tasks complete**

---

**Last Updated:** 2025-11-14
**By:** Claude (Anthropic)
