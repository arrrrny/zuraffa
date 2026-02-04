# Mock Data

Zuraffa provides comprehensive mock data generation for development and testing. The `--mock` and `--mock-data-only` flags generate realistic mock data for your entities and complete DataSource implementations, including complex nested entities.

## Overview

Mock data in Zuraffa serves multiple purposes:

1. **Development**: Work without backend services
2. **Testing**: Comprehensive test data
3. **Prototyping**: Quick UI development
4. **Offline**: Fallback when online services unavailable

## Basic Mock Generation

### 1. Generate with Mock Data

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --mock
```

This generates:
- Mock DataSource implementation
- Realistic sample data
- Complete CRUD operations with seeded data
- Support for complex nested entities

### 2. Mock Data Only

Generate only mock data files without other layers:

```bash
zfa generate Product --mock-data-only
```

Useful for:
- Sharing mock data across projects
- Testing without generating full architecture
- Prototyping data structures

## Generated Mock Architecture

### Mock DataSource with Nested Entities

```dart
// lib/src/data/data_sources/product/product_mock_data_source.dart
import '../../../domain/entities/product/product.dart';

class ProductMockDataSource {
  static List<Product> _data = [
    Product(
      id: '1',
      name: 'Laptop',
      description: 'High-performance laptop',
      price: 999.99,
      category: 'Electronics',
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1640995200000 + 1 * 86400000),
      // Complex nested entity example
      specifications: ProductSpecifications(
        weight: 2.5,
        dimensions: Dimensions(height: 1.5, width: 14.0, depth: 9.5),
        features: [
          Feature(name: 'Processor', value: 'Intel i7'),
          Feature(name: 'RAM', value: '16GB'),
          Feature(name: 'Storage', value: '512GB SSD'),
        ],
      ),
    ),
    Product(
      id: '2',
      name: 'Smartphone',
      description: 'Latest smartphone model',
      price: 699.99,
      category: 'Electronics',
      isActive: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1640995200000 + 2 * 86400000),
      specifications: ProductSpecifications(
        weight: 0.2,
        dimensions: Dimensions(height: 6.0, width: 3.0, depth: 0.3),
        features: [
          Feature(name: 'Screen', value: '6.1 inch'),
          Feature(name: 'Camera', value: '12MP'),
          Feature(name: 'Battery', value: '3000mAh'),
        ],
      ),
    ),
    // ... more generated data with nested entities
  ];

  Future<Product> get(String id) async {
    final product = _data.firstWhere((p) => p.id == id);
    return product;
  }

  Future<List<Product>> getList() async {
    return _data;
  }

  Future<Product> create(Product product) async {
    final newProduct = product.copyWith(id: (_data.length + 1).toString());
    _data.add(newProduct);
    return newProduct;
  }

  Future<Product> update(Product product) async {
    final index = _data.indexWhere((p) => p.id == product.id);
    if (index == -1) throw Exception('Product not found');
    
    _data[index] = product;
    return product;
  }

  Future<void> delete(String id) async {
    _data.removeWhere((p) => p.id == id);
  }
}
```

## Complex Nested Entity Generation

Zuraffa now generates mock data for complex nested entities with proper relationships:

### Example: Nested Entity Structure

For an entity with nested objects like:

```dart
class BarcodeListing {
  final String barcode;
  final String id;
  final String title;
  final String imageUrl;
  final List<ListingOffer> offers;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BarcodeListing({
    required this.barcode,
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.offers,
    required this.createdAt,
    required this.updatedAt,
  });
}
```

Zuraffa generates:

```dart
// lib/src/data/data_sources/barcode_listing/barcode_listing_mock_data_source.dart
import '../../../domain/entities/barcode_listing/barcode_listing.dart';
import '../listing_offer/listing_offer_mock_data.dart';

class BarcodeListingMockDataSource {
  static List<BarcodeListing> _data = [
    BarcodeListing(
      barcode: 'barcode 1',
      id: 'id 1',
      title: 'title 1',
      imageUrl: 'imageUrl 1',
      offers: [
        ListingOfferMockData.listingOffers[1],
        ListingOfferMockData.listingOffers[2],
        ListingOfferMockData.listingOffers[0],
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    BarcodeListing(
      barcode: 'barcode 2',
      id: 'id 2',
      title: 'title 2',
      imageUrl: 'imageUrl 2',
      offers: [
        ListingOfferMockData.listingOffers[2],
        ListingOfferMockData.listingOffers[0],
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      updatedAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    BarcodeListing(
      barcode: 'barcode 3',
      id: 'id 3',
      title: 'title 3',
      imageUrl: 'imageUrl 3',
      offers: [
        ListingOfferMockData.listingOffers[0],
        ListingOfferMockData.listingOffers[1],
        ListingOfferMockData.listingOffers[2],
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      updatedAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
  ];

  // CRUD operations...
}
```

### Generated Mock Data Class

```dart
// lib/src/data/data_sources/barcode_listing/barcode_listing_mock_data.dart
import '../../domain/entities/barcode_listing/barcode_listing.dart';
import '../listing_offer/listing_offer_mock_data.dart';

class BarcodeListingMockData {
  static final List<BarcodeListing> barcodeListings = [
    BarcodeListing(
      barcode: 'barcode 1',
      id: 'id 1',
      title: 'title 1',
      imageUrl: 'imageUrl 1',
      offers: [
        ListingOfferMockData.listingOffers[1],
        ListingOfferMockData.listingOffers[2],
        ListingOfferMockData.listingOffers[0],
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    BarcodeListing(
      barcode: 'barcode 2',
      id: 'id 2',
      title: 'title 2',
      imageUrl: 'imageUrl 2',
      offers: [
        ListingOfferMockData.listingOffers[2],
        ListingOfferMockData.listingOffers[0],
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      updatedAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    BarcodeListing(
      barcode: 'barcode 3',
      id: 'id 3',
      title: 'title 3',
      imageUrl: 'imageUrl 3',
      offers: [
        ListingOfferMockData.listingOffers[0],
        ListingOfferMockData.listingOffers[1],
        ListingOfferMockData.listingOffers[2],
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
      updatedAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
  ];

  static BarcodeListing get sampleBarcodeListing => barcodeListings.first;
  static List<BarcodeListing> get sampleList => barcodeListings;
  static List<BarcodeListing> get emptyList => [];

  static List<BarcodeListing> get largeBarcodeListingList =>
      List.generate(100, (index) => _createBarcodeListing(index + 1000));

  static BarcodeListing _createBarcodeListing(int seed) {
    return BarcodeListing(
      barcode: 'barcode $seed',
      id: 'id $seed',
      title: 'title $seed',
      imageUrl: 'imageUrl $seed',
      offers: [
        ListingOfferMockData.listingOffers[seed % 3],
        ListingOfferMockData.listingOffers[(seed + 1) % 3],
      ],
      createdAt: DateTime.now().subtract(Duration(days: seed * 30)),
      updatedAt: DateTime.now().subtract(Duration(days: seed * 30)),
    );
  }
}
```

## Data Generation Capabilities

### Primitive Types
- **String**: Sequential strings with index-based values
- **int**: Sequential or random numbers based on seed
- **double**: Decimal values with appropriate precision
- **bool**: Balanced true/false distribution based on seed
- **DateTime**: Recent dates with realistic ranges

### Complex Types
- **List&lt;T&gt;**: Arrays with 1-5 items of type T
- **Map&lt;K, V&gt;**: Key-value pairs with indexed data
- **Enums**: All possible enum values
- **Nested Entities**: Complete object graphs with proper relationships

### Seeded Data
Mock data is deterministic based on the entity name and field, ensuring consistency across generations while supporting complex nested structures.

## ZFA Patterns and Mock Data

### Entity-Based Pattern

Perfect for standard entity mocking with nested structures:

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --mock
```

### Single Repository Pattern

Mock data works with custom UseCases and complex nested entities:

```bash
zfa generate ProcessCheckout \
  --domain=checkout \
  --repo=Checkout \
  --params=CheckoutRequest \
  --returns=OrderConfirmation \
  --mock
```

### Orchestrator Pattern

Each composed UseCase can have its own mock data strategy with nested entity support.

## Advanced Mock Features

### Large Dataset Generation

For performance testing, Zuraffa generates methods for large datasets:

```dart
// Generated method for large datasets
Future<List<Product>> getListLarge(int count) async {
  final List<Product> largeList = [];
  for (int i = 0; i < count; i++) {
    largeList.add(_generateProduct(i));
  }
  return largeList;
}
```

### Null Safety Handling

Mock generation properly handles nullable fields with realistic null distribution:

```dart
// Field that can be null gets realistic null values
updatedAt: seed % 3 == 0 ? null : DateTime.now(), // 33% chance of null
```

### Zorphy Support

When using `--zorphy`, mock data generation handles Patch objects correctly:

```bash
zfa generate Product --methods=update --zorphy --mock
```

## Using Mock Data in Development

### 1. Development Setup

```bash
# Generate with mock data and DI
zfa generate Product \
  --methods=get,getList \
  --data \
  --mock \
  --di
```

### 2. Configure DI for Mock

Use `--use-mock` flag to register mock datasources:

```bash
zfa generate Product --data --mock --di --use-mock
```

This registers `ProductMockDataSource` instead of `ProductRemoteDataSource`.

### 3. Runtime Switching

Switch between mock and real data at runtime:

```dart
// In your main.dart
Future<void> setupDependencies(GetIt getIt) async {
  if (kDebugMode) {
    // Use mock in debug mode
    await registerProductMockDataSource(getIt);
  } else {
    // Use real API in release mode
    await registerProductRemoteDataSource(getIt);
  }

  await registerProductRepository(getIt);
}
```

## Mock Data Customization

### Custom ID Fields

Mock generation respects custom ID fields:

```bash
zfa generate Product --id-field=productId --id-field-type=int --mock
```

Generates mock data with `productId` instead of `id`.

### Query Field Mocking

Respects custom query fields:

```bash
zfa generate User --query-field=email --mock
```

Generates mock data that can be queried by email.

## Combining with Other Features

### Mock + Caching

```bash
zfa generate Product \
  --methods=get,getList \
  --data \
  --mock \
  --cache \
  --use-mock
```

Uses mock data as the remote source for caching.

### Mock + Testing

```bash
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --mock \
  --test
```

Generates both mock data and tests using the mock data.

### Mock + VPC

```bash
zfa generate Product \
  --methods=get,getList \
  --data \
  --mock \
  --vpc \
  --state
```

Complete development stack with mock data.

## Mock Data Quality

### Type Safety

All generated mock data maintains type safety with your entity definitions and properly handles nested entities.

### Consistency

Same entity name and field structure always generates the same mock data (deterministic).

### Relationship Integrity

Nested entities maintain proper relationships and references to other entities in the system.

## Best Practices

### 1. Development Workflow

```bash
# Start with mock data
zfa generate Product --methods=get,getList --data --mock --di --use-mock

# Add more methods as needed
zfa generate Product --methods=create,update --data --mock --di --use-mock --force

# Switch to real API when ready
zfa generate Product --methods=get,getList,create,update,delete --data --di
```

### 2. Testing Strategy

```bash
# Generate comprehensive test data with nested entities
zfa generate Product --methods=get,getList,create,update,delete --data --mock --test
```

### 3. Prototyping

```bash
# Quick prototype with mock data only
zfa generate Product --mock-data-only
```

## Troubleshooting

### Mock Data Not Loading

Ensure your repository is configured to use the mock datasource:

```dart
// If using --use-mock flag, your repository should inject mock datasource
DataProductRepository(
  getIt<ProductMockDataSource>(), // Not ProductRemoteDataSource
);
```

### Type Mismatch Errors

Make sure your entity fields match the generated mock data types.

### Large Dataset Performance

For large datasets, use the generated `getListLarge(count)` method instead of regular `getList()`.

## Next Steps

- [Caching](./caching) - Use mock data as remote source for caching
- [Testing](./testing) - Use mock data in unit tests
- [Dependency Injection](./dependency-injection) - Register mock data sources with DI
- [CLI Reference](../cli/commands) - Complete mock data flag documentation
