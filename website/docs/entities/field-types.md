# Field Types Reference

Reference for field types supported by Zorphy entity generation in v3.

## Basic Types

### String

```bash
zfa entity create -n User \
  --field name:String \
  --field email:String \
  --field bio:String?
```

**Usage:**
```dart
final user = User(name: 'John', email: 'john@example.com');
```

### Integer

```bash
zfa entity create -n Counter \
  --field count:int \
  --field max:int?
```

**Usage:**
```dart
final counter = Counter(count: 42);
```

### Double

```bash
zfa entity create -n Price \
  --field amount:double \
  --field taxRate:double?
```

**Usage:**
```dart
final price = Price(amount: 99.99, taxRate: 0.08);
```

### Boolean

```bash
zfa entity create -n Settings \
  --field isActive:bool \
  --field notificationsEnabled:bool?
```

**Usage:**
```dart
final settings = Settings(isActive: true, notificationsEnabled: false);
```

### DateTime

```bash
zfa entity create -n Event \
  --field startDate:DateTime \
  --field endDate:DateTime? \
  --field createdAt:DateTime
```

**Usage:**
```dart
final event = Event(
  startDate: DateTime.now(),
  endDate: DateTime.now().add(Duration(hours: 2)),
  createdAt: DateTime.now(),
);
```

## Nullable Types

Add `?` to make any field nullable:

```bash
zfa entity create -n Profile \
  --field nickname:String \
  --field bio:String? \
  --field website:String? \
  --field age:int?
```

**Usage:**
```dart
final profile = Profile(
  nickname: 'John',
  bio: null,      // Optional
  website: null,  // Optional
  age: null,      // Optional
);
```

## Collection Types

### List

```bash
# List of primitives
zfa entity create -n Article \
  --field title:String \
  --field tags:List<String>

# List of entities
zfa entity create -n Category \
  --field name:String \
  --field products:List<$Product>

# List of enums
zfa entity create -n Task \
  --field title:String \
  --field labels:List<TaskLabel>
```

**Usage:**
```dart
final article = Article(
  title: 'My Article',
  tags: ['dart', 'flutter', 'clean-architecture'],
);
```

### Set

```bash
zfa entity create -n PermissionGroup \
  --field name:String \
  --field permissions:Set<String>
```

**Usage:**
```dart
final group = PermissionGroup(
  name: 'Admin',
  permissions: {'read', 'write', 'delete'},
);
```

### Map

```bash
# Map with dynamic values
zfa entity create -n Metadata \
  --field data:Map<String,dynamic>

# Map with typed values
zfa entity create -n Config \
  --field settings:Map<String,bool> \
  --field limits:Map<String,int>
```

**Usage:**
```dart
final metadata = Metadata(
  data: {
    'version': '1.0.0',
    'count': 42,
    'active': true,
  },
);
```

## Nested Entities

### Single Nested Entity

```bash
# First create the nested entity
zfa entity create -n Address \
  --field street:String \
  --field city:String \
  --field country:String

# Then use it
zfa entity create -n User \
  --field name:String \
  --field address:$Address
```

**Generated:**
```dart
@Zorphy(generateJson: true)
abstract class $User {
  String get name;
  $Address get address;  // Nested entity
}
```

**Usage:**
```dart
final user = User(
  name: 'John',
  address: Address(
    street: '123 Main St',
    city: 'New York',
    country: 'USA',
  ),
);
```

### List of Nested Entities

```bash
zfa entity create -n Order \
  --field id:String \
  --field items:List<$OrderItem>
```

**Usage:**
```dart
final order = Order(
  id: '123',
  items: [
    OrderItem(product: 'Widget', quantity: 2),
    OrderItem(product: 'Gadget', quantity: 1),
  ],
);
```

## Enums

### Create Enum

```bash
zfa entity enum -n Status --value active,inactive,pending
```

### Use Enum in Entity

```bash
zfa entity create -n Account \
  --field username:String \
  --field status:Status
```

**Usage:**
```dart
final account = Account(
  username: 'john_doe',
  status: Status.active,
);
```

### Multiple Enum Fields

```bash
zfa entity enum -n Priority --value low,medium,high,critical
zfa entity enum -N TaskStatus --value todo,in_progress,done

zfa entity create -n Task \
  --field title:String \
  --field priority:Priority \
  --field status:TaskStatus
```

## Generic Types

### Single Generic

```bash
zfa entity create -n ApiResponse \
  --field success:bool \
  --field data:T? \
  --field errorMessage:String?
```

**Usage:**
```dart
final response = ApiResponse<String>(
  success: true,
  data: 'Hello',
);

final userResponse = ApiResponse<User>(
  success: true,
  data: User(name: 'John'),
);
```

### Multiple Generics

```bash
zfa entity create -n KeyValuePair \
  --field key:K \
  --field value:V
```

**Usage:**
```dart
final pair = KeyValuePair<String, int>(
  key: 'count',
  value: 42,
);
```

## Self-Referencing Types

### Tree Structure

```bash
zfa entity create -n CategoryNode \
  --field id:String \
  --field name:String \
  --field children:List<$CategoryNode>? \
  --field parent:$CategoryNode?
```

**Usage:**
```dart
final root = CategoryNode(
  id: '1',
  name: 'Electronics',
  children: [
    CategoryNode(
      id: '2',
      name: 'Phones',
      parent: root,
    ),
  ],
  parent: null,
);
```

### Graph Structure

```bash
zfa entity create -n Node \
  --field id:String \
  --field label:String \
  --field connections:List<$Node>
```

## Complex Types

### Mixed Nested Collections

```bash
zfa entity create -n Survey \
  --field title:String \
  --field questions:List<$Question> \
  --field responses:Map<String, List<$Response>>
```

### Deep Nesting

```bash
zfa entity create -n Company \
  --field name:String \
  --field address:$Address \
  --field departments:List<$Department>
  # where Department has List<Employee> and Employee has Address
```

## JSON Serialization

All types automatically support JSON serialization when `--json=true` (default):

```bash
zfa entity create -n User \
  --field name:String \
  --field email:String? \
  --field tags:List<String> \
  --field address:$Address

# JSON is enabled by default
final user = User(name: 'John', email: 'john@example.com');

// To JSON
final json = user.toJson();
// {"name":"John","email":"john@example.com","tags":[],"address":{...}}

// From JSON
final restored = User.fromJson(json);
```

## Type Conversions

### DateTime to/from JSON

DateTime fields are automatically serialized as ISO 8601 strings:

```dart
final event = Event(
  startDate: DateTime(2026, 2, 4, 14, 30),
);

final json = event.toJson();
// {"startDate":"2026-02-04T14:30:00.000Z"}

final restored = Event.fromJson(json);
print(restored.startDate); // DateTime(2026, 2, 4, 14, 30)
```

### Nested Entities to/from JSON

Nested entities are recursively serialized:

```dart
final user = User(
  name: 'John',
  address: Address(street: '123 Main', city: 'NYC'),
);

final json = user.toJson();
// {"name":"John","address":{"street":"123 Main","city":"NYC"}}
```

## Best Practices

### 1. Use Appropriate Types

```bash
# ✅ Good - Type-safe
zfa entity create -n Price --field amount:double

# ❌ Avoid - Lose type safety
zfa entity create -n Price --field amount:String
```

### 2. Make Fields Nullable When Appropriate

```bash
# ✅ Good - Optional data
zfa entity create -n User \
  --field name:String \
  --field nickname:String? \
  --field bio:String?

# ❌ Avoid - Everything required
zfa entity create -n User \
  --field name:String \
  --field nickname:String \
  --field bio:String
```

### 3. Use Enums for Fixed Values

```bash
# ✅ Good - Compile-time safety
zfa entity enum -n Status --value active,inactive
zfa entity create -n Account --field status:Status

# ❌ Avoid - Runtime errors
zfa entity create -n Account --field status:String
```

### 4. Prefer Lists Over Sets for JSON

```bash
# ✅ Good - Better JSON support
zfa entity create -n Group --field members:List<String>

# ⚠️  Sets serialize to Lists in JSON anyway
zfa entity create -n Group --field members:Set<String>
```

## Querying, Filtering, Sorting

Zuraffa includes `QueryParams` and `ListQueryParams` to keep querying type-safe.

```dart
Future<List<Product>> getList(ListQueryParams<Product> params) async {
  return _box.values.filter(params.filter).orderBy(params.sort);
}
```

```dart
final params = ListQueryParams<Product>(
  filter: And([
    Eq(ProductFields.status, ProductStatus.available),
    Gt(ProductFields.price, 10),
  ]),
  sort: Sort(ProductFields.price, descending: true),
  limit: 20,
);
```

## What's Next?

- [Advanced Patterns](./advanced-patterns) - Polymorphism, inheritance, generics
- [Real-World Examples](./examples) - Complete entity structures
- [CLI Commands](../cli/entity-commands) - Complete CLI reference
