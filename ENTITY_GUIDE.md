# 🎯 Zorphy Entity Generation Guide

Complete guide to generating entities, enums, and managing data models with Zuraffa's integrated Zorphy CLI.

## Table of Contents

- [Quick Start](#quick-start)
- [Basic Entity Creation](#basic-entity-creation)
- [Field Types](#field-types)
- [JSON Serialization](#json-serialization)
- [Enums](#enums)
- [Sealed Classes & Polymorphism](#sealed-classes--polymorphism)
- [Inheritance & Interfaces](#inheritance--interfaces)
- [Nested Objects](#nested-objects)
- [Self-Referencing Types](#self-referencing-types)
- [Generic Classes](#generic-classes)
- [Advanced Features](#advanced-features)
- [Complete Examples](#complete-examples)

## Quick Start

### Create Your First Entity

```bash
# Interactive creation
zfa entity create -n User

# Create with fields
zfa entity create -n User \
  --field name:String \
  --field email:String? \
  --field age:int

# Build generated code
zfa build
```

### Generated Structure

```
lib/src/domain/entities/
├── user/
│   ├── user.dart              # Entity definition
│   ├── user.zorphy.dart       # Generated implementation
│   └── user.g.dart            # JSON serialization (if enabled)
└── enums/
    ├── index.dart             # Enum barrel file
    └── (enum files)
```

## Basic Entity Creation

### Command Syntax

```bash
zfa entity create [options]
```

### Options

| Option | Alias | Description | Default |
|--------|-------|-------------|---------|
| `--name` | `-n` | Entity name (required) | - |
| `--output` | `-o` | Output directory | `lib/src/domain/entities` |
| `--field` | `-f` | Add fields directly | Interactive prompt |
| `--fields` | `-f` | Interactive field prompts | `true` |
| `--json` | - | Enable JSON serialization | `true` |
| `--copywith-fn` | - | Function-based copyWith | `false` |
| `--compare` | - | Enable compareTo | `true` |
| `--sealed` | - | Create sealed class (`$$` prefix) | `false` |
| `--non-sealed` | - | Non-sealed abstract class | `false` |
| `--extends` | - | Interface to extend | - |
| `--subtype` | - | Explicit subtypes | - |

### Examples

```bash
# Simple entity
zfa entity create -n Product

# Entity with multiple fields
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double \
  --field inStock:bool

# Entity with nullable fields
zfa entity create -n User \
  --field name:String \
  --field email:String? \
  --field phone:String? \
  --field age:int?

# Entity without JSON
zfa entity create -n CacheEntry --json=false

# Sealed class for polymorphism
zfa entity create -n PaymentMethod --sealed

# Non-sealed abstract class
zfa entity create -n BaseEntity --non-sealed
```

## Field Types

### Basic Types

```bash
zfa entity create -n Item \
  --field id:String \
  --field name:String \
  --field count:int \
  --field price:double \
  --field isActive:bool \
  --field rating:double
```

### Nullable Types

Add `?` to make a field nullable:

```bash
zfa entity create -n Profile \
  --field bio:String? \
  --field website:String? \
  --field avatarUrl:String?
```

### Generic Types

```bash
# Lists
zfa entity create -n Category \
  --field name:String \
  --field tags:String? \
  --field products:List<Product>

# Sets
zfa entity create -n PermissionSet \
  --field permissions:Set<String>

# Maps
zfa entity create -n Metadata \
  --field data:Map<String,dynamic> \
  --field settings:Map<String,bool>
```

### Nested Entities

Reference other Zorphy entities with `$` prefix:

```bash
# Create Address first
zfa entity create -n Address \
  --field street:String \
  --field city:String \
  --field country:String

# Create User with nested Address
zfa entity create -n User \
  --field name:String \
  --field address:\$Address
```

### Enums

First create an enum:

```bash
zfa entity enum -n Status --value active,inactive,pending
```

Then use it in entities:

```bash
zfa entity create -n Account \
  --field username:String \
  --field status:Status
```

## JSON Serialization

### Enable JSON Support

```bash
# JSON is enabled by default
zfa entity create -n Product --field name:String

# Explicitly enable/disable
zfa entity create -n CacheData --json=false
zfa entity create -n ApiModel --json=true
```

### Usage

```dart
// Generated methods
final product = Product(id: '1', name: 'Widget');

// To JSON
final json = product.toJson();

// From JSON
final restored = Product.fromJson(json);
```

### Complex JSON Example

```bash
zfa entity create -n Order \
  --field id:String \
  --field customer:\$Customer \
  --field items:List<\$OrderItem> \
  --field total:double \
  --field status:OrderStatus \
  --field createdAt:DateTime
```

## Enums

### Create Enum

```bash
zfa entity enum -n UserStatus --value active,inactive,suspended,pending
```

### Generated Structure

```dart
// lib/src/domain/entities/enums/user_status.dart
enum UserStatus { 
  active, 
  inactive, 
  suspended, 
  pending 
}

// Auto-exported in lib/src/domain/entities/enums/index.dart
export 'user_status.dart';
```

### Use in Entities

```dart
// Import automatically added
import '../enums/index.dart';

zfa entity create -n Account \
  --field username:String \
  --field status:UserStatus
```

### Multiple Enums

```bash
zfa entity enum -n UserRole --value admin,user,guest
zfa entity enum -N LogLevel --value debug,info,warn,error
```

## Sealed Classes & Polymorphism

### Create Sealed Class

```bash
# Create sealed abstract class
zfa entity create -n Shape --sealed

# Create implementations
zfa entity create -n Circle \
  --field radius:double \
  --extends:\$\$Shape

zfa entity create -n Rectangle \
  --field width:double \
  --field height:double \
  --extends:\$\$Shape
```

### Explicit Subtypes

Define subtypes in the sealed class:

```bash
zfa entity create -n PaymentMethod \
  --sealed \
  --subtype=\$CreditCard \
  --subtype=\$PayPal \
  --subtype=\$BankTransfer
```

### Generated Code

```dart
// Sealed class
@Zorphy(explicitSubTypes: [$CreditCard, $PayPal, $BankTransfer])
abstract class $$PaymentMethod {
  String get displayName;
}

// Implementation
@Zorphy(generateJson: true)
abstract class $CreditCard implements $$PaymentMethod {
  String get cardNumber;
  String get expiryDate;
  
  @override
  String get displayName => 'Credit Card';
}
```

### Usage

```dart
// Type-safe handling
String processPayment($$PaymentMethod method) {
  return switch (method) {
    $CreditCard() => 'Processing card payment...',
    $PayPal() => 'Processing PayPal...',
    $BankTransfer() => 'Processing transfer...',
  };
}
```

## Inheritance & Interfaces

### Multiple Inheritance

```bash
# Create interfaces
zfa entity create -n Timestamped \
  --non-sealed \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?

zfa entity create -n Identifiable \
  --non-sealed \
  --field id:String

# Create entity implementing both
zfa entity create -n Post \
  --field title:String \
  --field content:String \
  --extends=\$Timestamped \
  --extends=\$Identifiable
```

### Generated Code

```dart
@Zorphy()
abstract class $Post implements $Timestamped, $Identifiable {
  String get title;
  String get content;
  // Inherits: id, createdAt, updatedAt
}
```

## Nested Objects

### Create Nested Structure

```bash
# Create address entity
zfa entity create -n Address \
  --field street:String \
  --field city:String \
  --field zipCode:String

# Create person with nested address
zfa entity create -n Person \
  --field name:String \
  --field address:\$Address

# Create company with nested people
zfa entity create -n Company \
  --field name:String \
  --field employees:List<\$Person>
```

### Auto-Import Management

Zorphy automatically adds imports for nested entities:

```dart
import 'package:zorphy_annotation/zorphy_annotation.dart';
import '../address/address.dart';  // Auto-added
import '../person/person.dart';     // Auto-added

part 'company.zorphy.dart';
part 'company.g.dart';

@Zorphy(generateJson: true)
abstract class $Company {
  String get name;
  List<$Person> get employees;
}
```

## Self-Referencing Types

### Tree Structures

```bash
zfa entity create -n CategoryNode \
  --field id:String \
  --field name:String \
  --field children:List<\$CategoryNode>? \
  --field parent:\$CategoryNode?
```

### Generated Code

```dart
@Zorphy(generateJson: true)
abstract class $CategoryNode {
  String get id;
  String get name;
  List<$CategoryNode>? get children;
  $CategoryNode? get parent;
}
```

### Usage

```dart
final root = CategoryNode(
  id: '1',
  name: 'Electronics',
  children: [
    CategoryNode(
      id: '2',
      name: 'Phones',
      parent: root,  // Self-reference
    ),
  ],
  parent: null,
);
```

## Generic Classes

### Generic Entity

```bash
zfa entity create -n ApiResponse \
  --field success:bool \
  --field data:T? \
  --field errorMessage:String?
```

### Generic Lists

```bash
zfa entity create -n ListResponse \
  --field total:int \
  --field items:List<T> \
  --field page:int \
  --field pageSize:int
```

### Multiple Generics

```bash
zfa entity create -n KeyValuePair \
  --field key:K \
  --field value:V
```

### Usage

```dart
final response = ApiResponse<String>(
  success: true,
  data: 'Hello',
);

final listResponse = ListResponse<Product>(
  total: 100,
  items: products,
  page: 1,
  pageSize: 20,
);
```

## Advanced Features

### Function-based CopyWith

```bash
zfa entity create -n Counter \
  --field value:int \
  --field label:String \
  --copywith-fn
```

### CompareTo

```bash
zfa entity create -n Document \
  --field title:String \
  --field version:int \
  --field createdAt:DateTime \
  --compare
```

### Patch Method (Zorphy 1.0+)

Zorphy generates a `patch()` method for easy updates:

```dart
final user = User(id: '1', name: 'John', email: 'john@example.com');

// Patch returns copyWith applied
final updated = user.patch(email: 'newemail@example.com');
```

## Complete Examples

### E-commerce Entities

```bash
# Enums
zfa entity enum -n OrderStatus --value pending,processing,shipped,delivered,cancelled
zfa entity enum -n PaymentStatus --value pending,completed,failed,refunded

# Base entities
zfa entity create -n Address \
  --field street:String \
  --field city:String \
  --field state:String \
  --field zipCode:String \
  --field country:String

zfa entity create -n Customer \
  --field id:String \
  --field name:String \
  --field email:String \
  --field phone:String? \
  --field address:\$Address

zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field description:String? \
  --field price:double \
  --field stock:int \
  --field category:String \
  --field imageUrl:String? \
  --field active:bool

zfa entity create -n OrderItem \
  --field product:\$Product \
  --field quantity:int \
  --field unitPrice:double

zfa entity create -n Order \
  --field id:String \
  --field customer:\$Customer \
  --field items:List<\$OrderItem> \
  --field status:OrderStatus \
  --field paymentStatus:PaymentStatus \
  --field total:double \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?
```

### Social Media Entities

```bash
# Enums
zfa entity enum -N PostVisibility --value public,followers,private

# Entities
zfa entity create -n User \
  --field id:String \
  --field username:String \
  --field displayName:String \
  --field bio:String? \
  --field avatarUrl:String? \
  --field followersCount:int \
  --field followingCount:int \
  --field createdAt:DateTime

zfa entity create -n Post \
  --field id:String \
  --field author:\$User \
  --field content:String \
  --field imageUrl:String? \
  --field likes:int \
  --field comments:int \
  --field visibility:PostVisibility \
  --field createdAt:DateTime \
  --field updatedAt:DateTime?

zfa entity create -n Comment \
  --field id:String \
  --field post:\$Post \
  --field author:\$User \
  --field content:String \
  --field createdAt:DateTime
```

### Task Management

```bash
# Enums
zfa entity enum -n TaskPriority --value low,medium,high,critical
zfa entity enum -n TaskStatus --value todo,in_progress,review,done,cancelled

# Sealed class for task types
zfa entity create -n TaskType --sealed

zfa entity create -n BugTask \
  --field severity:String \
  --field reproductionSteps:List<String> \
  --extends=\$\$TaskType

zfa entity create -n FeatureTask \
  --field storyPoints:int \
  --field acceptanceCriteria:List<String> \
  --extends=\$\$TaskType

# Main entities
zfa entity create -n Task \
  --field id:String \
  --field title:String \
  --field description:String? \
  --field assignee:\$User? \
  --field status:TaskStatus \
  --field priority:TaskPriority \
  --field type:\$\$TaskType \
  --field dueDate:DateTime? \
  --field createdAt:DateTime

zfa entity create -n Project \
  --field id:String \
  --field name:String \
  --field description:String? \
  --field tasks:List<\$Task> \
  --field members:List<\$User> \
  --field startDate:DateTime \
  --field endDate:DateTime?
```

## Entity Management Commands

### List All Entities

```bash
zfa entity list

# Custom directory
zfa entity list --output=lib/src/domain/entities
```

### Add Fields to Existing Entity

```bash
zfa entity add-field -n User \
  --field phone:String? \
  --field address:\$Address
```

### Quick Create (Simple Entity)

```bash
# Creates entity with basic defaults
zfa entity new -n SimpleEntity

# With JSON disabled
zfa entity new -n CacheEntry --json=false
```

### Create from JSON

```bash
# Single entity
zfa entity from-json user.json

# With custom name
zfa entity from-json data.json --name UserProfile

# With options
zfa entity from-json api_response.json \
  --name ApiResponse \
  --prefix-nested=false
```

### JSON File Example

```json
{
  "id": "123",
  "name": "John Doe",
  "email": "john@example.com",
  "address": {
    "street": "123 Main St",
    "city": "New York",
    "country": "USA"
  },
  "orders": [
    {
      "id": "order-1",
      "total": 99.99
    }
  ]
}
```

## Build & Regenerate

### Run Code Generation

```bash
# One-time build
zfa build

# Clean and rebuild
zfa build --clean

# Watch for changes
zfa build --watch
```

### What Gets Generated

```
user/
├── user.dart           # Your definition
├── user.zorphy.dart    # Concrete implementation
└── user.g.dart         # JSON serialization
```

## Best Practices

### 1. Use Sealed Classes for Polymorphism

```dart
// ✅ Good - Exhaustive checking
$$PaymentMethod method = ...;
switch (method) {
  case $CreditCard(): /* handle card */
  case $PayPal(): /* handle PayPal */
}
```

### 2. Leverage Enums for Fixed Values

```bash
# ✅ Good - Type-safe
zfa entity enum -n Status --value active,inactive
zfa entity create -n Account --field status:Status

# ❌ Avoid - Magic strings
zfa entity create -n Account --field status:String
```

### 3. Use Nested Entities for Composition

```bash
# ✅ Good - Reusable
zfa entity create -n Address --field street:String
zfa entity create -n User --field address:\$Address
zfa entity create -n Company --field address:\$Address

# ❌ Avoid - Duplication
zfa entity create -n User \
  --field street:String \
  --field city:String
zfa entity create -n Company \
  --field street:String \
  --field city:String
```

### 4. Enable JSON for API Models

```bash
# ✅ API models
zfa entity create -n ApiUser --json=true

# ✅ Local-only models
zfa entity create -n CacheEntry --json=false
```

## Integration with Zuraffa

### Use Entities in Clean Architecture

```bash
# 1. Create entity
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double

# 2. Generate Clean Architecture
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state

# 3. Build everything
zfa build
```

### Generated Structure

```
lib/src/
├── domain/
│   ├── entities/
│   │   └── product/          # Created by zfa entity
│   ├── repositories/         # Generated by zfa generate
│   └── usecases/
├── data/
│   └── repositories/         # Generated by zfa generate
└── presentation/
    └── pages/
        └── product/          # Generated by zfa generate
```

## Troubleshooting

### Import Errors

If you see import errors after creating entities:

```bash
# Rebuild
zfa build --clean
```

### Missing Enums

Ensure enums are created before using them:

```bash
# 1. Create enum first
zfa entity enum -n Status --value active,inactive

# 2. Then use in entity
zfa entity create -n Account --field status:Status

# 3. Build
zfa build
```

### Circular References

Avoid circular dependencies:

```bash
# ❌ Bad - Circular
zfa entity create -n A --field b:\$B
zfa entity create -n B --field a:\$A

# ✅ Good - Use interface
zfa entity create -n A --field bId:String
zfa entity create -n B --field aId:String
```

## Additional Resources

- [Zorphy GitHub](https://github.com/arrrrny/zorphy)
- [Zuraffa Documentation](https://zuraffa.com/docs)
- [CLI Reference](./CLI_GUIDE.md)

## Summary

Zorphy entity generation provides:

- ✅ **Type-safe entities** with null safety
- ✅ **JSON serialization** built-in
- ✅ **Sealed classes** for polymorphism
- ✅ **Multiple inheritance** support
- ✅ **Generic types** flexibility
- ✅ **Auto-imports** for nested entities
- ✅ **Enum integration**
- ✅ **CompareTo**, `copyWith`, `patch` methods
- ✅ **Self-referencing** types

All integrated seamlessly with Zuraffa's Clean Architecture generation!
