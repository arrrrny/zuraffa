# Zuraffa Roadmap

## Next Feature: DI Integration

### `--di=get_it` Flag

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

**Implementation Priority:** High - This completes the full-stack code generation experience.

---

*Focus: Developer experience through complete automation, not feature bloat.*
