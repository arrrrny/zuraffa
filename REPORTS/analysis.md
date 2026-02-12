Critical Review: Current State is ~75% (NOT 92%)
Your action plan overstates completion. Here's what's actually blocking 100% clean code:
---
🚨 EXACT IMPLEMENTATION TASKS FOR AGENT
TASK 1: Documentation (CRITICAL - 16 hours)
Files requiring class-level DartDoc (75 total, start with these 10):
// lib/src/plugins/mock/builders/mock_builder.dart
/// Generates mock data builders for entities and their variants.
/// 
/// Creates realistic mock data for:
/// - Entity instances with randomized fields
/// - Entity lists with configurable sizes  
/// - Polymorphic variant factories
/// 
/// Example output:
/// ```dart
/// final mockProduct = MockProductBuilder()
///   .withName('Test Product')
///   .withPrice(99.99)
///   .build();
///class MockBuilder { ... }
// lib/src/plugins/di/di_plugin.dart  
/// Configures dependency injection registrations for generated code.
///
/// Generates get_it registrations for:
/// - UseCases with proper lifecycle management
/// - Repositories with datasource injection
/// - Services with provider bindings
/// - Controllers with presenter injection
///
/// Supports mock/remote datasource switching via useMock flag.
class DIPlugin { ... }
**Agent instructions:**
1. Add comprehensive class documentation to all 10 priority files
2. Document all public methods with `@param` and `@returns`
3. Include code examples in documentation
4. Run: `dart doc --dry-run` to verify
---
### **TASK 2: Null Safety Violations (HIGH - 2 hours)**
**Exact replacements needed (16 locations):**
**File:** `lib/src/plugins/provider/builders/provider_builder.dart:26-29`
```dart
// BEFORE (BAD)
final serviceName = config.effectiveService!;
final serviceSnake = config.serviceSnake!;
// AFTER (CLEAN)
assert(config.hasService, 
  'Service name must be specified via --service or config.service');
final serviceName = config.effectiveService;
final serviceSnake = config.serviceSnake;
File: lib/src/plugins/method_append/builders/method_append_builder.dart:51-53
// BEFORE (BAD)  
case 'get':
  methods.add(_buildGetMethod(config.repo!));
case 'getList':
  methods.add(_buildGetListMethod(config.repo!));
// AFTER (CLEAN)
assert(config.repo != null, 
  'Repository name required for method append operations');
final repo = config.repo!;
case 'get':
  methods.add(_buildGetMethod(repo));
Agent instructions:
1. Replace ALL 16 ! assertions with guard patterns
2. Add meaningful assert messages explaining the requirement
3. Extract repeated access to local variables (avoid multiple ! on same field)
---
TASK 3: Boolean Flag Arguments (MEDIUM - 4 hours)
Pattern violation in 102+ locations. Fix priority files:
File: lib/src/plugins/datasource/builders/remote_generator.dart:12-14
// BEFORE (BAD - flag arguments)
class RemoteGenerator {
  RemoteGenerator({
    required this.dryRun,      // ❌ Flag
    required this.force,       // ❌ Flag  
    required this.verbose,     // ❌ Flag
  });
}
// AFTER (CLEAN - options object)
class GeneratorOptions {
  final bool dryRun;
  final bool force;
  final bool verbose;
  
  const GeneratorOptions({
    this.dryRun = false,
    this.force = false, 
    this.verbose = false,
  });
}
class RemoteGenerator {
  RemoteGenerator({
    required this.outputDir,
    this.options = const GeneratorOptions(),
  });
}
Agent instructions:
1. Create GeneratorOptions class in lib/src/core/generator_options.dart
2. Refactor top 5 flag-heavy generators to use options object
3. Maintain backward compatibility with deprecated named parameters
---
TASK 4: God Classes >500 Lines (MEDIUM - 8 hours)
Split these 9 files:
Priority: local_generator.dart (910 lines → 3 files)
lib/src/plugins/datasource/builders/
├── local_generator.dart (300 lines - orchestrator)
├── local_crud_methods.dart (250 lines - CRUD builders)  
└── local_stream_methods.dart (200 lines - stream/watch builders)
└── local_helper_methods.dart (160 lines - utilities)
Priority: cache_builder.dart (676 lines → 2 files)
lib/src/plugins/cache/builders/
├── cache_builder.dart (350 lines - main builder)
└── cache_policy_builder.dart (326 lines - policy generation)
Agent instructions:
1. Extract private methods into separate files
2. Keep public API unchanged
3. Use part/part of for tight coupling where needed
4. Ensure all tests still pass after split
---
TASK 5: Cyclomatic Complexity (MEDIUM - 8 hours)
Refactor deep nesting (167 hotspots). Example:
File: mock_builder.dart (example from your action plan)
// BEFORE (6 levels deep - BAD)
for (final variant in config.variants) {
  if (hasEntityList) {
    for (final method in config.methods) {
      switch (method) {
        case 'getList':
          if (hasPagination) {
            // 5 levels deep
          }
      }
    }
  }
}
// AFTER (CLEAN - strategy pattern)
class MockMethodStrategy {
  final String method;
  final bool hasPagination;
  
  Code generate(MockConfig config) => switch (method) {
    'getList' => _generateGetList(config, hasPagination),
    'get' => _generateGet(config),
    _ => throw UnsupportedError(method),
  };
}
// Usage
for (final variant in config.variants) {
  if (!hasEntityList) continue;
  
  for (final method in config.methods) {
    final strategy = MockMethodStrategy(method, hasPagination);
    methods.add(strategy.generate(config));
  }
}
Agent instructions:
1. Identify 20 highest complexity methods via dart analyze --fatal-infos
2. Apply guard clauses to reduce nesting
3. Extract nested logic into private methods
4. Target: max 3 levels of nesting per method
---
📋 VERIFICATION CHECKLIST
Before claiming 100%:
- [ ] All 75 files have class-level documentation
- [ ] Zero ! assertions in lib/src/plugins
- [ ] All public methods have DartDoc
- [ ] No files >500 lines (except generated)
- [ ] No boolean flag arguments in constructors
- [ ] dart analyze shows zero warnings
- [ ] flutter test passes all 32 plugin tests
- [ ] dart doc generates without errors
Current reality: 30 hours of work remaining. Do not claim 92% when actual is ~75%.