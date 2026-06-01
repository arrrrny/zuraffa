# Quickstart: Polymorphic Mock Data Generation

**Feature**: 006-fix-polymorphic-mock-data

## Prerequisites

- Zuraffa package 4.1.2+ with ZFA CLI
- A Dart project with entities defined in `lib/src/domain/entities/`

## Usage

### 1. Define a Sealed Class Entity

Create your entity file at `lib/src/domain/entities/category_config/category_config.dart`:

```dart
sealed class CategoryConfig {
  final String id;
  final String name;
  
  const CategoryConfig({required this.id, required this.name});
}

class PrimaryCategory extends CategoryConfig {
  final int priority;
  
  const PrimaryCategory({
    required super.id,
    required super.name,
    required this.priority,
  });
}

class SecondaryCategory extends CategoryConfig {
  final String parentId;
  
  const SecondaryCategory({
    required super.id,
    required super.name,
    required this.parentId,
  });
}
```

### 2. Generate Mock Data

```bash
zfa mock data CategoryConfig --force
```

### 3. Expected Output

The generator creates mock data files for each **concrete** subtype:

```
lib/src/data/mock/
├── primary_category_mock_data.dart    # Contains PrimaryCategoryMockData
└── secondary_category_mock_data.dart   # Contains SecondaryCategoryMockData
```

The sealed base class (`CategoryConfig`) does **not** get a mock data file — only concrete subtypes do.

### 4. Use in Tests

```dart
import 'path/to/primary_category_mock_data.dart';

void main() {
  test('should handle primary category', () {
    final category = PrimaryCategoryMockData.samplePrimaryCategory;
    expect(category.priority, greaterThan(0));
  });
}
```

### 5. Verify

```bash
# Check generated code compiles
dart analyze lib/src/data/mock/

# Run existing tests (should continue to pass)
dart test test/plugins/mock/
```

### Common Scenarios

| Entity Pattern | Command | Result |
|---------------|---------|--------|
| `sealed class` with 2 concrete subtypes | `zfa mock data MyEntity` | 2 mock data files (one per subtype) |
| `@Zorphy(explicitSubTypes: [A, B])` | `zfa mock data MyEntity` | 2 mock data files (unchanged behavior) |
| Regular non-polymorphic class | `zfa mock data MyEntity` | 1 mock data file (unchanged behavior) |
| Sealed class, all subtypes abstract | `zfa mock data MyEntity` | Warning message, no files generated |
| Non-existent entity | `zfa mock data BadName` | Error message, exits immediately |

### Troubleshooting

- **"No concrete subtypes found"**: Your sealed class has only abstract subtypes. Add at least one concrete subclass.
- **"Entity file not found"**: Verify the entity file exists at `lib/src/domain/entities/{snake_name}/{snake_name}.dart`.
- **Hang/Freeze**: This is the bug being fixed. The fix ensures all paths return within 10 seconds.
