# Advanced Patterns

Advanced entity patterns in v3: polymorphism, inheritance, generics, and self-referencing types.

## Sealed Classes & Polymorphism

### Basic Sealed Class

Create a sealed abstract class for exhaustive pattern matching:

```bash
zfa entity create -n PaymentMethod --sealed
```

**Generated:**
```dart
@Zorphy()
abstract class $$PaymentMethod {
  // Sealed class - can't be instantiated directly
}
```

### Sealed Class with Implementations

```bash
# Create the sealed base
zfa entity create -n Shape --sealed

# Create implementations
zfa entity create -n Circle \
  --field radius:double \
  --extends=$$Shape

zfa entity create -n Rectangle \
  --field width:double \
  --field height:double \
  --extends=$$Shape

zfa entity create -n Triangle \
  --field base:double \
  --field height:double \
  --extends=$$Shape
```

**Generated:**
```dart
@Zorphy()
abstract class $$Shape {}

@Zorphy(generateJson: true)
abstract class $Circle implements $$Shape {
  double get radius;
}

@Zorphy(generateJson: true)
abstract class $Rectangle implements $$Shape {
  double get width;
  double get height;
}

@Zorphy(generateJson: true)
abstract class $Triangle implements $$Shape {
  double get base;
  double get height;
}
```

**Exhaustive Pattern Matching:**
```dart
String describeShape($$Shape shape) {
  return switch (shape) {
    $Circle() => 'Circle with radius ${shape.radius}',
    $Rectangle() => 'Rectangle ${shape.width}x${shape.height}',
    $Triangle() => 'Triangle with base ${shape.base}',
  };
  // Compiler ensures all cases are covered!
}

final circle = Circle(radius: 5.0);
print(describeShape(circle)); // Circle with radius 5.0
```

### Sealed Class with Explicit Subtypes

Define subtypes in the base class:

```bash
zfa entity create -n Notification \
  --sealed \
  --subtype=$EmailNotification \
  --subtype=$PushNotification \
  --subtype=$SmsNotification \
  --field recipient:String

zfa entity create -n EmailNotification \
  --field subject:String \
  --field body:String \
  --extends=$$Notification

zfa entity create -n PushNotification \
  --field title:String \
  --field message:String \
  --extends=$$Notification

zfa entity create -n SmsNotification \
  --field phoneNumber:String \
  --field text:String \
  --extends=$$Notification
```

**Generated with shared field:**
```dart
@Zorphy(explicitSubTypes: [$EmailNotification, $PushNotification, $SmsNotification])
abstract class $$Notification {
  String get recipient;  // Shared field
}

@Zorphy(generateJson: true)
abstract class $EmailNotification implements $$Notification {
  String get subject;
  String get body;
  // Inherits: recipient
}
```

## Inheritance

### Single Inheritance

```bash
# Create interface
zfa entity create -n Timestamped --non-sealed \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?

# Create entity implementing interface
zfa entity create -n Article \
  --field title:String \
  --field content:String \
  --extends=$Timestamped
```

**Usage:**
```dart
final article = Article(
  title: 'My Article',
  content: 'Content here...',
  createdAt: DateTime.now(),
  updatedAt: null,
);

// Access inherited fields
print(article.createdAt);
print(article.title);
```

### Multiple Inheritance

```bash
# Create multiple interfaces
zfa entity create -n Timestamped --non-sealed \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?

zfa entity create -n Identifiable --non-sealed \
  --field id:String

zfa entity create -n Trackable --non-sealed \
  --field createdBy:String \
  --field updatedBy:String?

# Create entity implementing all
zfa entity create -n Post \
  --field title:String \
  --field content:String \
  --extends=$Timestamped \
  --extends=$Identifiable \
  --extends=$Trackable
```

**Generated:**
```dart
@Zorphy()
abstract class $Post implements $Timestamped, $Identifiable, $Trackable {
  String get title;
  String get content;
  // Inherits: id, createdAt, updatedAt, createdBy, updatedBy
}
```

### Interface Methods

Add abstract methods to interfaces:

```bash
zfa entity create -n Validator --non-sealed

# Then implement manually in the concrete class
# The generated class will include the interface
```

## Generics

### Single Generic Type

```bash
zfa entity create -n Result \
  --field success:bool \
  --field data:T? \
  --field errorMessage:String?
```

**Usage:**
```dart
// String result
final stringResult = Result<String>(
  success: true,
  data: 'Hello',
);

// User result
final userResult = Result<User>(
  success: true,
  data: User(name: 'John'),
);

// List result
final listResult = Result<List<Product>>(
  success: true,
  data: products,
);
```

### Multiple Generic Types

```bash
zfa entity create -n KeyValuePair \
  --field key:K \
  --field value:V
```

**Usage:**
```dart
final pair1 = KeyValuePair<String, int>(key: 'age', value: 30);
final pair2 = KeyValuePair<int, String>(key: 1, value: 'one');
final pair3 = KeyValuePair<User, Address>(key: user, value: address);
```

### Generic with Constraints

```dart
// Generated generic classes work with any type
zfa entity create -n Box \
  --field value:T \
  --field isActive:bool
```

### Nested Generics

```bash
zfa entity create -n ApiResponse \
  --field data:List<T>? \
  --field total:int \
  --field page:int

# Usage with nested generics
final response = ApiResponse<List<Product>>(
  data: products,
  total: 100,
  page: 1,
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
final electronics = CategoryNode(
  id: '1',
  name: 'Electronics',
  parent: null,
);

final phones = CategoryNode(
  id: '2',
  name: 'Phones',
  parent: electronics,
  children: null,
);

final laptops = CategoryNode(
  id: '3',
  name: 'Laptops',
  parent: electronics,
  children: null,
);

// Add children to parent
electronics = electronics.copyWith(
  children: [phones, laptops],
);
```

### Graph Structure

```bash
zfa entity create -n Node \
  --field id:String \
  --field label:String \
  --field connections:List<$Node>
```

**Usage:**
```dart
final node1 = Node(id: '1', label: 'Node 1', connections: []);
final node2 = Node(id: '2', label: 'Node 2', connections: []);
final node3 = Node(id: '3', label: 'Node 3', connections: []);

// Create connections
node1 = node1.copyWith(connections: [node2, node3]);
node2 = node2.copyWith(connections: [node1, node3]);
node3 = node3.copyWith(connections: [node1, node2]);
```

### Doubly Linked List

```bash
zfa entity create -n ListNode \
  --field value:int \
  --field next:ListNode? \
  --field prev:ListNode?
```

**Usage:**
```dart
final node1 = ListNode(value: 1, next: null, prev: null);
final node2 = ListNode(value: 2, next: null, prev: node1);
final node3 = ListNode(value: 3, next: null, prev: node2);

node1 = node1.copyWith(next: node2);
node2 = node2.copyWith(next: node3);
```

## Polymorphic Collections

### List of Sealed Class Types

```bash
zfa entity create -n Animal --sealed

zfa entity create -n Dog \
  --field name:String \
  --field breed:String \
  --extends=$$Animal

zfa entity create -n Cat \
  --field name:String \
  --field indoor:bool \
  --extends=$$Animal

zfa entity create -n Zoo \
  --field name:String \
  --field animals:List<$$Animal>
```

**Usage:**
```dart
final zoo = Zoo(
  name: 'City Zoo',
  animals: [
    Dog(name: 'Buddy', breed: 'Golden Retriever'),
    Cat(name: 'Whiskers', indoor: true),
    Dog(name: 'Max', breed: 'Bulldog'),
  ],
);

// Pattern match on each animal
for (final animal in zoo.animals) {
  print(switch (animal) {
    Dog() => 'Dog: ${animal.name} (${animal.breed})',
    Cat() => 'Cat: ${animal.name} (${animal.indoor ? 'indoor' : 'outdoor'})',
  });
}
```

## Advanced JSON Patterns

### Nested JSON Structure

```bash
zfa entity create -n Config \
  --field name:String \
  --field metadata:Map<String,dynamic> \
  --field settings:List<$Setting>

zfa entity create -n Setting \
  --field key:String \
  --field value:String \
  --field enabled:bool
```

**JSON:**
```json
{
  "name": "app-config",
  "metadata": {
    "version": "1.0.0",
    "environment": "production"
  },
  "settings": [
    {"key": "theme", "value": "dark", "enabled": true},
    {"key": "notifications", "value": "all", "enabled": true}
  ]
}
```

### Recursive JSON

Self-referencing types serialize correctly:

```bash
zfa entity create -n Menu \
  --field title:String \
  --field icon:String? \
  --field children:List<$Menu>?

# Serializes to recursive JSON structure
```

## Mixin Pattern with Interfaces

```bash
# Create reusable behaviors
zfa entity create -n Serializable --non-sealed \
  --field serializationVersion:int

zfa entity create -n Trackable --non-sealed \
  --field createdAt:DateTime \
  --field modifiedAt:DateTime?

zfa entity create -n SoftDeletable --non-sealed \
  --field isDeleted:bool \
  --field deletedAt:DateTime?

# Mix and match
zfa entity create -n User \
  --field username:String \
  --field email:String \
  --extends=$Serializable \
  --extends=$Trackable \
  --extends=$SoftDeletable

zfa entity create -n Product \
  --field name:String \
  --field price:double \
  --extends=$Serializable \
  --extends=$Trackable \
  --extends=$SoftDeletable
```

## Factory Pattern with Sealed Classes

```bash
# Define result types
zfa entity create -n Result --sealed \
  --subtype=$Success \
  --subtype=$Error

zfa entity create -n Success \
  --field data:String

zfa entity create -n Error \
  --field errorCode:int \
  --field errorMessage:String

# Usage in a function
Result<String> processInput(String input) {
  if (input.isEmpty) {
    return Error(errorCode: 400, errorMessage: 'Empty input');
  }
  return Success(data: input.toUpperCase());
}

// Handle with exhaustive pattern matching
void handleResult(Result<String> result) {
  switch (result) {
    case Success():
      print('Success: ${result.data}');
    case Error():
      print('Error ${result.errorCode}: ${result.errorMessage}');
  }
}
```

## Type-Safe State Machine

```bash
zfa entity create -n AppState --sealed \
  --subtype=$LoadingState \
  --subtype=$DataState \
  --subtype=$ErrorState

zfa entity create -n LoadingState

zfa entity create -n DataState \
  --field data:List<$Product>

zfa entity create -n ErrorState \
  --field error:String \
  --field retryable:bool
```

**Usage:**
```dart
AppState currentState = LoadingState();

void render(AppState state) {
  switch (state) {
    case LoadingState():
      print('⏳ Loading...');
    case DataState():
      print('✅ Data: ${state.data.length} products');
    case ErrorState():
      print('❌ Error: ${state.error}');
  }
}
```

## Best Practices

### 1. Use Sealed Classes for Exhaustive Checking

```dart
// ✅ Good - Compiler enforces exhaustiveness
PaymentMethod method = ...;
switch (method) {
  case $CreditCard(): /* handle */
  case $PayPal(): /* handle */
  // All cases must be handled
}
```

### 2. Prefer Composition Over Deep Nesting

```bash
# ✅ Good - Flat structure with references
zfa entity create -n Order \
  --field customerId:String \
  --field customerAddressId:String

# ❌ Avoid - Too deep
zfa entity create -n Order \
  --field customer:$Customer \
  # where Customer has Address, which has Geo, etc.
```

### 3. Use Generics for Flexibility

```bash
# ✅ Good - Reusable
zfa entity create -n ApiResult \
  --field success:bool \
  --field data:T?

# Works with any type
final userResult = ApiResult<User>(...);
final productResult = ApiResult<Product>(...);
```

### 4. Document Self-Referencing Structures

```dart
// Always document expected usage
/// Tree structure of categories
/// 
/// Use [parent] to navigate up the tree
/// Use [children] to navigate down
/// Root nodes have [parent] == null
/// Leaf nodes have [children] == null or empty
@Zorphy(generateJson: true)
abstract class $CategoryNode {
  String get id;
  String get name;
  List<$CategoryNode>? get children;
  $CategoryNode? get parent;
}
```

## What's Next?

- [Real-World Examples](./examples) - Complete working examples
- [Field Types Reference](./field-types) - All supported field types
- [CLI Commands](../cli/entity-commands) - Complete command reference
