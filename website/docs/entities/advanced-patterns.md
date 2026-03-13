# Advanced Entity Patterns

**Zuraffa**'s entity system is designed to handle complex business logic and data structures. By combining **Zorphy** with Dart's modern features, you can model everything from simple records to exhaustive state machines and polymorphic hierarchies.

---

## 🦄 Sealed Classes & Polymorphism

Sealed classes are the gold standard for modeling exclusive states. Zuraffa generates these with the `--sealed` flag, enabling **exhaustive pattern matching** in your controllers and views.

### 1. Define the Sealed Base
```bash
zfa entity create -n PaymentMethod --sealed
```

### 2. Add Concrete Subtypes
```bash
zfa entity create -n CreditCard --field number:String --extends=$$PaymentMethod
zfa entity create -n PayPal --field email:String --extends=$$PaymentMethod
```

### 3. Exhaustive Usage
```dart
String process($$PaymentMethod method) {
  return switch (method) {
    $CreditCard() => 'Card: ${method.number}',
    $PayPal() => 'PayPal: ${method.email}',
  };
  // Compiler error if a subtype is missing!
}
```

---

## 🛡️ Inheritance & Interfaces

Zuraffa supports multi-interface inheritance, allowing you to share fields across multiple entities without duplication.

### Shared Interfaces
```bash
# Create a base interface (non-sealed)
zfa entity create -n Identifiable --non-sealed --field id:String

# Use it in multiple entities
zfa entity create -n User --field name:String --extends=$Identifiable
zfa entity create -n Product --field price:double --extends=$Identifiable
```

---

## 🧩 Generics

Create reusable data wrappers like API envelopes or paginated results.

```bash
zfa entity create -n PaginatedList \
  --field items:List<T> \
  --field total:int \
  --field hasMore:bool
```

**Usage:**
```dart
final products = PaginatedList<Product>(
  items: [product1, product2],
  total: 100,
  hasMore: true,
);
```

---

## 🏗️ Self-Referencing Types (Trees)

Perfect for categories, comments, or organizational charts. Use the entity's own name (without prefixes) in the field definition.

```bash
zfa entity create -n Category \
  --field name:String \
  --field children:List<$Category>? \
  --field parent:$Category?
```

---

## 🧠 State Machines

Model your feature states using sealed entities for 100% type safety.

```bash
zfa entity create -n AuthState --sealed \
  --subtype=$Authenticated \
  --subtype=$Unauthenticated \
  --subtype=$Authenticating

zfa entity create -n Authenticated --field user:$User --extends=$$AuthState
zfa entity create -n Unauthenticated --field reason:String? --extends=$$AuthState
zfa entity create -n Authenticating --extends=$$AuthState
```

---

## 🤖 AI Advantage: Modeling

When using an AI agent, you can define these complex patterns using natural language:

> "Create a sealed **PaymentMethod** entity with **CreditCard** and **Crypto** subtypes. Each should have a **transactionId** field from a shared **Transaction** interface."

The AI will translate this into the correct series of `zfa entity` commands, ensuring your architecture remains clean and consistent.

---

## 📂 Next Steps

*   [**Real-World Examples**](./examples) - See these patterns in action.
*   [**Field Types Reference**](./field-types) - Master the building blocks.
*   [**Feature Commands**](../cli/commands) - Generate logic around these advanced models.
