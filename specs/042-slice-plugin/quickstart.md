# Quickstart: Slice Plugin Validation Guide

## Prerequisites

- Zuraffa repository checked out on `042-slice-plugin` branch
- Dart SDK ^3.12.0 installed
- A test fixture project with Zuraffa clean architecture structure (provided in `test/fixtures/slice_test_project/`)

## Validation Scenarios

### Scenario 1: Cut a Single-Entry Slice

**Purpose**: Verify the core extraction pipeline produces a valid slice from a single page entry point.

**Steps**:

1. Create or use a test fixture project with this minimal structure:
   ```
   lib/src/
   ├── domain/entities/product/product.dart
   ├── domain/usecases/product/get_product_usecase.dart
   ├── domain/repositories/product_repository.dart
   ├── data/repositories/data_product_repository.dart
   ├── di/usecases/get_product_usecase_di.dart
   ├── di/repositories/product_repository_di.dart
   ├── presentation/pages/product/product_view.dart
   ├── presentation/pages/product/product_controller.dart
   ├── presentation/pages/product/product_presenter.dart
   └── presentation/pages/product/product_state.dart
   ```

2. Run extraction:
   ```bash
   cd test/fixtures/slice_test_project
   zfa slice cut product_feature --entry product
   ```

3. Verify output:
   ```bash
   # Manifest exists and is valid YAML
   cat .zuraffa/slices/product_feature/slice.yaml

   # Entry point exists
   cat .zuraffa/slices/product_feature/main_slice.dart

   # Agent instructions exist
   cat .zuraffa/slices/product_feature/SLICE.md

   # All expected files are present
   ls .zuraffa/slices/product_feature/lib/src/presentation/pages/product/
   ls .zuraffa/slices/product_feature/lib/src/domain/entities/product/
   ls .zuraffa/slices/product_feature/lib/src/domain/usecases/product/
   ```

**Expected outcome**:
- `.zuraffa/slices/product_feature/` directory created
- `slice.yaml` contains all included files with hashes and ownership
- `main_slice.dart` imports the product view and sets up mock DI
- `SLICE.md` lists modifiable files, run command, and boundary interfaces
- Presentation files classified as `owned`
- Domain entity/interface files classified as `shared`
- No data layer files included (default depth is `feature`)

### Scenario 2: Merge Modified Files Back

**Purpose**: Verify the merge pipeline correctly copies only modified files and detects conflicts.

**Steps**:

1. After Scenario 1, modify a file in the sandbox:
   ```bash
   # Simulate agent modification
   echo "// Agent was here" >> .zuraffa/slices/product_feature/lib/src/presentation/pages/product/product_view.dart
   ```

2. Run merge:
   ```bash
   zfa slice merge product_feature
   ```

3. Verify:
   ```bash
   # The modification should appear in the main project
   tail -1 lib/src/presentation/pages/product/product_view.dart
   # Expected: "// Agent was here"

   # The slice directory should be deleted
   ls .zuraffa/slices/product_feature/
   # Expected: No such file or directory
   ```

**Expected outcome**:
- Only `product_view.dart` is copied back (the only modified file)
- The slice directory is cleaned up after successful merge
- Console output lists exactly which files were merged

### Scenario 3: List and Inspect Active Slices

**Purpose**: Verify operational introspection commands.

**Steps**:

1. Cut two slices:
   ```bash
   zfa slice cut product_feature --entry product
   zfa slice cut profile_feature --entry profile
   ```

2. List:
   ```bash
   zfa slice list
   ```

3. Inspect:
   ```bash
   zfa slice inspect product_feature
   ```

**Expected outcome**:
- `list` shows both slice names, entry points, dates, and file counts
- `inspect` shows detailed file list with ownership classification and modification status

### Scenario 4: Service Locator Detection

**Purpose**: Verify the engine correctly discovers `getIt<T>()` dependencies that aren't in import statements.

**Steps**:

1. Create a test presenter fixture:
   ```dart
   // product_presenter.dart
   import 'package:get_it/get_it.dart';
   final getIt = GetIt.instance;

   class ProductPresenter {
     ProductPresenter() {
       _getProduct = getIt<GetProductUseCase>();
       _updateProduct = getIt<UpdateProductUseCase>();
     }
     late final GetProductUseCase _getProduct;
     late final UpdateProductUseCase _updateProduct;
   }
   ```

2. Run extraction and check manifest:
   ```bash
   zfa slice cut product_test --entry product
   cat .zuraffa/slices/product_test/slice.yaml | grep -A5 boundaries
   ```

**Expected outcome**:
- `GetProductUseCase` and `UpdateProductUseCase` appear in the manifest's boundaries or included files
- Their corresponding DI registration files are included

## Running Unit Tests

```bash
# Fast unit tests for the slice plugin
dart test test/plugins/slice/

# Specific test file
dart test test/plugins/slice/engine/import_graph_walker_test.dart

# Full regression suite
dart test --preset=regression
```

## Running the CLI

```bash
# After building (or using dart run)
dart run bin/zfa.dart slice cut <name> --entry <page_name> [--depth feature]
dart run bin/zfa.dart slice merge <name>
dart run bin/zfa.dart slice list
dart run bin/zfa.dart slice inspect <name>
```
