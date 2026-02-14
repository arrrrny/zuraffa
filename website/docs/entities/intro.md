# Entity Generation

Zuraffa v3 includes Zorphy entity generation for type-safe models, enums, and JSON-ready data classes.

## Why Entity Generation?

Entity generation provides the foundation for your Flutter application's data layer. Instead of writing boilerplate data classes, you can focus on your business logic while Zuraffa generates type-safe, production-ready entities.

### Benefits

- Type-safe models with null safety
- JSON serialization out of the box
- Sealed classes and inheritance options
- Generics for lists and maps
- Auto-imports for nested entities
- Generated helpers like `copyWith` and `patch`

## What Makes Zorphy Different?

Unlike other code generators, Zorphy creates **immutable abstract classes** with concrete implementations generated separately. This design gives you:

1. **Clean Separation**: Your entity definition stays separate from generated code
2. **Immutability**: All entities are immutable by default
3. **Type Safety**: Compiler ensures all fields are properly typed
4. **Extensibility**: Add business logic to concrete implementations if needed
5. **JSON-First**: Serialization built-in from the start

## Quick Start

### Create Your First Entity

```bash
zfa entity create -n User --field name:String --field email:String?
```

This creates:
```
lib/src/domain/entities/user/
├── user.dart           # Your definition (editable)
├── user.zorphy.dart    # Generated implementation (read-only)
└── user.g.dart          # JSON serialization (read-only)
```

### The Generated Code

```dart
// lib/src/domain/entities/user/user.dart
import 'package:zorphy_annotation/zorphy_annotation.dart';
part 'user.zorphy.dart';
part 'user.g.dart';

@Zorphy(generateJson: true, generateCompareTo: true)
abstract class $User {
  String get name;
  String? get email;
}
```

### Using Your Entity

```dart
// Create instance
final user = User(name: 'John', email: 'john@example.com');

// JSON serialization - perfect for APIs
final json = user.toJson();
// {"name":"John","email":"john@example.com"}

final restored = User.fromJson(json);

// Immutability with copyWith
final updated = user.copyWith(email: 'newemail@example.com');

// Convenience patch method
final patched = user.patch(email: 'another@email.com');

// Comparison
if (user1.compareTo(user2) < 0) {
  print('user1 comes before user2');
}
```

## Entity Workflow

The typical workflow for entity-driven development:

### 1. Design Your Data Model

Start by defining what entities you need:
- What data does your app need?
- What are the relationships between entities?
- What are the fixed values (enums)?

### 2. Create Enums First

Enums represent fixed values in your domain:

```bash
# Define status values
zfa entity enum -n OrderStatus \
  --value pending,processing,shipped,delivered,cancelled

# Define user roles
zfa entity enum -n UserRole --value admin,user,guest

# Define payment methods
zfa entity enum -n PaymentMethod --value credit_card,paypal,bank_transfer
```

### 3. Create Core Entities

Start with independent entities that don't depend on others:

```bash
# Address is used by multiple entities
zfa entity create -n Address \
  --field street:String \
  --field city:String \
  --field state:String \
  --field zipCode:String \
  --field country:String

# Product is independent
zfa entity create -n Product \
  --field id:String \
  --field sku:String \
  --field name:String \
  --field description:String? \
  --field price:double \
  --field categoryId:String
```

### 4. Create Dependent Entities

Now create entities that reference the core entities:

```bash
# Customer references Address
zfa entity create -n Customer \
  --field id:String \
  --field email:String \
  --field name:String \
  --field phone:String? \
  --field shippingAddress:$Address \
  --field billingAddress:$Address

# Order references Customer and Product
zfa entity create -n Order \
  --field id:String \
  --field customer:$Customer \
  --field items:List<$OrderItem> \
  --field status:OrderStatus \
  --field total:double \
  --field createdAt:DateTime
```

### 5. Build Generated Code

Run the code generator to implement your entities:

```bash
zfa build
```

This generates the concrete implementations and JSON serialization code.

### 6. Verify with List Command

Check what was created:

```bash
zfa entity list
```

Output:
```
📂 Zorphy Entities in lib/src/domain/entities:

📄 Customer
   Path: lib/src/domain/entities/customer/customer.dart
   ✓ JSON support

📄 Order
   Path: lib/src/domain/entities/order/order.dart
   ✓ JSON support
   ✓ compareTo enabled

📂 Enums:
   📋 OrderStatus
   📋 UserRole
   📋 PaymentMethod

📦 Barrel file: lib/src/domain/entities/enums/index.dart
```

## Integration with Clean Architecture

Once you have entities, generate the complete Clean Architecture around them:

```bash
# Generate UseCases, Repositories, VPC layer
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data \
  --vpc \
  --state \
  --di

# Build everything
zfa build
```

This creates a complete feature:
- Domain layer (UseCases + Repository interface)
- Data layer (DataRepository + DataSource)  
- Presentation layer (View, Presenter, Controller, State)
- Dependency injection setup

## Real-World Example: E-commerce

Let's build a complete e-commerce domain model:

### Step 1: Define Enums

```bash
# Order and payment statuses
zfa entity enum -n OrderStatus \
  --value pending,processing,shipped,delivered,cancelled,refunded

zfa entity enum -n PaymentStatus \
  --value pending,completed,failed,refunded

# Product categories
zfa entity enum -n ProductCategory \
  --value electronics,clothing,home,books,sports
```

### Step 2: Create Shared Entities

```bash
# Address used by customers and orders
zfa entity create -n Address \
  --field street:String \
  --field street2:String? \
  --field city:String \
  --field state:String \
  --field zipCode:String \
  --field country:String \
  --field isDefault:bool

# Money value object
zfa entity create -n Money \
  --field amount:double \
  --field currency:String
```

### Step 3: Create Core Entities

```bash
# Product catalog
zfa entity create -n Product \
  --field id:String \
  --field sku:String \
  --field name:String \
  --field description:String? \
  --field price:Money \
  --field compareAtPrice:Money? \
  --field category:ProductCategory \
  --field imageUrl:String? \
  --field isActive:bool \
  --field stock:int \
  --field createdAt:DateTime
```

### Step 4: Create Domain Entities

```bash
# Customer with multiple addresses
zfa entity create -n Customer \
  --field id:String \
  --field email:String \
  --field passwordHash:String \
  --field firstName:String \
  --field lastName:String \
  --field phone:String? \
  --field addresses:List<$Address> \
  --field defaultAddressId:String? \
  --field createdAt:DateTime \
  --field lastLoginAt:DateTime?

# Shopping cart
zfa entity create -n Cart \
  --field id:String \
  --field customerId:String? \
  --field items:List<$CartItem> \
  --field subtotal:Money \
  --field expiresAt:DateTime
```

### Step 5: Create Transactional Entities

```bash
# Order line item
zfa entity create -n OrderItem \
  --field productId:String \
  --field productName:String \
  --field quantity:int \
  --field unitPrice:Money \
  --field totalPrice:Money

# Order with customer and items
zfa entity create -n Order \
  --field id:String \
  --field orderNumber:String \
  --field customerId:String \
  --field items:List<$OrderItem> \
  --field subtotal:Money \
  --field tax:Money \
  --field total:Money \
  --field status:OrderStatus \
  --field paymentStatus:PaymentStatus \
  --field shippingAddress:$Address \
  --field billingAddress:$Address \
  --field notes:String? \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?
```

### Step 6: Generate Complete Architecture

```bash
# Generate Clean Architecture for each entity
zfa generate Product \
  --methods=get,getList,create,update,delete \
  --data --vpc --state --di

zfa generate Order \
  --methods=get,getList,create \
  --data --vpc --state --di

zfa generate Customer \
  --methods=get,getList,create \
  --data --vpc --state --di

# Build everything
zfa build --watch
```

## Key Concepts

### Immutability

All generated entities are immutable. To modify an entity, use `copyWith` or `patch`:

```dart
// ✅ Good - Create new instance
final updated = user.copyWith(email: 'new@email.com');

// ❌ Bad - Can't mutate directly
user.email = 'new@email.com'; // Compilation error!
```

### Type Safety

Zorphy enforces type safety at compile-time:

```dart
// ✅ Type-safe
final product = Product(name: 'Widget', price: Money(amount: 9.99, currency: 'USD'));

// ❌ Type error - wrong type
final product = Product(name: 'Widget', price: 9.99); // Error: expecting Money

// ❌ Type error - missing field
final product = Product(name: 'Widget'); // Error: missing required field 'price'
```

### Sealed Classes

Sealed classes enable exhaustive pattern matching:

```dart
// Define sealed class
zfa entity create -n PaymentMethod --sealed

// Create implementations
zfa entity create -n CreditCard \
  --field cardNumber:String \
  --field expiryDate:String \
  --extends=$$PaymentMethod

// Exhaustive checking - compiler ensures all cases covered
String processPayment($$PaymentMethod method) {
  return switch (method) {
    $CreditCard() => 'Processing card ending in ${method.cardNumber.substring(11)}',
    $PayPal() => 'Processing PayPal payment',
    // Compiler error if you forget a case!
  };
}
```

### Nested Entities

Nested entities are automatically imported:

```dart
// You don't need to manage imports manually
zfa entity create -n User \
  --field name:String \
  --field address:$Address \
  --field orders:List<$Order>

// Generated code includes auto-imports:
import 'package:zorphy_annotation/zorphy_annotation.dart';
import '../address/address.dart';  // Auto-added!
import '../order/order.dart';      // Auto-added!

part 'user.zorphy.dart';
part 'user.g.dart';
```

### Self-Referencing Types

Build complex structures like trees and graphs:

```dart
// Category tree
zfa entity create -n CategoryNode \
  --field id:String \
  --field name:String \
  --field parentId:String? \
  --field children:List<$CategoryNode>

// Usage - build hierarchies
final electronics = CategoryNode(
  id: '1',
  name: 'Electronics',
  parentId: null,
  children: [
    CategoryNode(
      id: '2',
      name: 'Phones',
      parentId: '1',
      children: [],
    ),
  ],
);
```

## Querying, Filtering, Sorting

Zuraffa ships with `QueryParams` and `ListQueryParams` so filtering and sorting is type-safe out of the box.

### Local data source example

```dart
Future<List<Product>> getList(ListQueryParams<Product> params) async {
  return _box.values.filter(params.filter).orderBy(params.sort);
}
```

### Available filters

- Eq, Neq
- Gt, Gte, Lt, Lte
- Contains, InList
- And, Or
- Filter.always()

### Example usage

```dart
final params = ListQueryParams<Product>(
  filter: And([
    Eq(ProductFields.status, ProductStatus.available),
    Gt(ProductFields.price, 10),
  ]),
  sort: Sort(ProductFields.price, descending: true),
  limit: 20,
  offset: 0,
);
```

## Best Practices

### 1. Design Before You Code

Think about your domain model before creating entities:
- What are your core entities?
- What are the relationships?
- What values are fixed (enums)?
- What values change (fields)?

### 2. Create in Dependency Order

Create independent entities first, then dependent ones:

```bash
# ✅ Good - Create Address first
zfa entity create -n Address --field street:String
zfa entity create -n User --field address:$Address

# ❌ Bad - User references Address that doesn't exist yet
zfa entity create -n User --field address:$Address  # Error!
```

### 3. Use Enums for Fixed Values

```bash
# ✅ Good - Type-safe, exhaustive
zfa entity enum -n Status --value active,inactive
zfa entity create -n Account --field status:Status

// Switch will enforce exhaustiveness
switch (account.status) {
  case Status.active: /* ... */
  case Status.inactive: /* ... */
  // Compiler error if you miss a case!
}

# ❌ Avoid - Runtime errors
zfa entity create -n Account --field status:String
// What if someone passes "pending"? It's not a valid status!
```

### 4. Enable JSON for API Models

```bash
# ✅ Good - API models need JSON
zfa entity create -n ApiUser --json=true

# ✅ Good - Local models don't need JSON
zfa entity create -n CacheEntry --json=false
```

### 5. Use Meaningful Names

```bash
# ✅ Good - Clear, descriptive
zfa entity create -n ShoppingCart --field items:List<$CartItem>

# ❌ Avoid - Vague names
zfa entity create -n Thing --field stuff:List<$OtherThing>
```

## What's Next?

- [Field Types Reference](./field-types) - Complete field type guide
- [Advanced Patterns](./advanced-patterns) - Sealed classes, inheritance, generics
- [Real-World Examples](./examples) - E-commerce, Social Media, Task Management
- [CLI Commands](../cli/entity-commands) - Complete entity CLI reference
