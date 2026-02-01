# Zuraffa Roadmap

## Next Features

### 1. Mock DataSource Generation (`--mock`)

**Goal**: Generate mock data sources with realistic test data for rapid prototyping and testing.

**Usage:**
```bash
# Generate mock data source with sample data
zfa generate Product --methods=get,getList,create --mock

# Generate mock data only
zfa generate Product --mock-data-only
```

**Generated Files:**
- `lib/src/data/mock/product_mock_data.dart` - Centralized mock data
- `lib/src/data/data_sources/product/product_mock_data_source.dart` - Mock implementation

**Benefits:**
- ✅ Rapid prototyping without backend
- ✅ Realistic test data for UI development  
- ✅ Reusable mock data across tests and previews
- ✅ Different scenarios (success, error, edge cases)
- ✅ Works with any entity structure

**Implementation Approach**: Mock files (not constructor-based) for better reusability and maintainability.

### 2. DI Integration (`--di=get_it`)

**Goal**: Complete the "one command, full feature" experience by automatically generating dependency injection registration code.

**Usage:**
```bash
# Generate complete feature with DI registration
zfa generate Product --methods=get,getList,create --repository --data --vpc --di=get_it

# Additive mode for existing projects
zfa generate Product --methods=get,getList --repository --di=get_it --additive
```

**Generated Output:**
- All existing files (UseCases, Repository, DataSources, VPC)
- New: `lib/src/di/product_di.dart` with GetIt registration code
- Automatic registration of all generated dependencies

**Benefits:**
- ✅ Eliminates last manual step in Clean Architecture setup
- ✅ Follows GetIt best practices
- ✅ Works with existing GetIt configurations
- ✅ Additive mode prevents breaking existing registrations
- ✅ High impact, low complexity implementation

---

*Focus: Developer experience through complete automation, not feature bloat.*
