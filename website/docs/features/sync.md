# SyncUseCase

Zuraffa provides a `SyncUseCase` base class for synchronous operations that don't require asynchronous processing. Unlike other UseCase types that work with async operations, `SyncUseCase` executes business logic immediately and returns a result synchronously.

## Overview

`SyncUseCase<T, Params>` is designed for operations that:
- Complete immediately without I/O operations
- Perform validations, calculations, or transformations
- Execute business rules and checks
- Run on the main thread without async overhead

## Why SyncUseCase?

- **Immediate Execution**: Operations complete synchronously without awaiting futures
- **No Async Overhead**: No async/await boilerplate for simple logic
- **Type Safe**: Result-based error handling with `Result<T, AppFailure>`
- **Simple Testing**: Easier to test than async operations
- **Clear Intent**: Clearly indicates synchronous operation in code

## When to Use SyncUseCase

Use `SyncUseCase` for:

- **Validation Logic**
  - Email validation with regex
  - Phone number format checks
  - Data structure validation
  - Business rule enforcement

- **Data Transformations**
  - Mapping operations
  - Filtering and sorting
  - Aggregations (sum, average, count)
  - Format conversions

- **Calculations**
  - Totals and subtotals
  - Tax calculations
  - Currency conversions
  - Statistical operations

- **Business Rules**
  - Eligibility checks
  - Permission validation
  - Feature flags
  - Configuration lookups

## How It Works

Unlike async UseCase types that use `Future<T>` and async/await, `SyncUseCase`:

1. Extends `SyncUseCase<T, Params>` base class
2. Implements `execute(Params params)` method
3. Returns result synchronously (no async/await)
4. Wrapped in `Result<T, AppFailure>` by the `call()` method
5. Automatic exception handling to `AppFailure`

## Comparison: UseCase Types

| Type | Execution | Use Cases | Async |
|-------|-------------|------------|-------|
| **UseCase** (default) | Async | API calls, database, file I/O | ✅ Yes |
| **StreamUseCase** | Stream | Real-time data, WebSocket, Firebase | ✅ Yes |
| **BackgroundUseCase** | Isolate | CPU-intensive work, image processing | ✅ Yes |
| **CompletableUseCase** | Async void | Delete, logout, analytics events | ✅ Yes |
| **SyncUseCase** | Synchronous | Validation, calculations, transformations | ❌ No |

## Basic Example

### Validation Logic

Generate a sync UseCase for email validation:

```bash
zfa generate ValidateEmail \
  --domain=validation \
  --type=sync \
  --params=String \
  --returns=bool
```

**Generated UseCase:**
```dart
// lib/src/domain/usecases/validation/validate_email_usecase.dart
class ValidateEmailUseCase extends SyncUseCase<bool, String> {
  @override
  bool execute(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
```

**Usage:**
```dart
class EmailInputController extends Controller with StatefulController<EmailInputState> {
  final ValidateEmailUseCase _validateEmail;

  EmailInputController(this._validateEmail) : super();

  void validateEmail(String email) {
    final result = _validateEmail(email);
    
    result.fold(
      (isValid) {
        updateState(viewState.copyWith(
          email: email,
          isValid: true,
          error: null,
        ));
      },
      (failure) {
        updateState(viewState.copyWith(
          email: email,
          isValid: false,
          error: failure.message,
        ));
      },
    );
  }
}
```

## Data Transformations

### Filtering and Mapping

Generate a sync UseCase for filtering data:

```bash
zfa generate FilterActiveProducts \
  --domain=products \
  --type=sync \
  --params=List<Product> \
  --returns=List<Product>
```

**Generated UseCase:**
```dart
class FilterActiveProductsUseCase extends SyncUseCase<List<Product>, List<Product>> {
  @override
  List<Product> execute(List<Product> products) {
    return products
        .where((product) => product.isActive)
        .toList();
  }
}
```

### Calculations

Generate a sync UseCase for calculating totals:

```bash
zfa generate CalculateOrderTotal \
  --domain=orders \
  --type=sync \
  --params=List<OrderItem> \
  --returns=double
```

**Generated UseCase:**
```dart
class CalculateOrderTotalUseCase extends SyncUseCase<double, List<OrderItem>> {
  @override
  double execute(List<OrderItem> items) {
    return items.fold(
      0.0,
      (total, item) => total + (item.price * item.quantity),
    );
  }
}
```

### Business Rules

Generate a sync UseCase for checking permissions:

```bash
zfa generate CheckUserPermission \
  --domain=auth \
  --type=sync \
  --params=PermissionRequest \
  --returns=bool
```

**Generated UseCase:**
```dart
class CheckUserPermissionUseCase extends SyncUseCase<bool, PermissionRequest> {
  final UserRepository _userRepository;
  final ConfigRepository _configRepository;

  CheckUserPermissionUseCase(
    this._userRepository,
    this._configRepository,
  );

  @override
  bool execute(PermissionRequest request) {
    final user = _userRepository.getCurrentUser();
    final config = _configRepository.getPermissions();
    
    if (user == null) {
      return false;
    }
    
    return config.allowedRoles.contains(user!.role) &&
           config.allowedPermissions.contains(request.permission);
  }
}
```

## Using with Repositories and Services

`SyncUseCase` can inject repositories or services, but must call them synchronously:

### With Repository

```bash
zfa generate CalculateDiscount \
  --domain=pricing \
  --repo=Pricing \
  --type=sync \
  --params=DiscountRequest \
  --returns=double
```

**Generated UseCase:**
```dart
class CalculateDiscountUseCase extends SyncUseCase<double, DiscountRequest> {
  final PricingRepository _repository;

  CalculateDiscountUseCase(this._repository);

  @override
  double execute(DiscountRequest request) {
    // Repository method must be synchronous
    final rules = _repository.getDiscountRulesSync();
    
    return rules.fold(
      0.0,
      (discount, rule) {
        if (rule.matches(request)) {
          return discount.max(rule.percentage);
        }
        return discount;
      },
    );
  }
}
```

### With Service

```bash
zfa generate ValidatePassword \
  --domain=auth \
  --service=PasswordValidation \
  --type=sync \
  --params=String \
  --returns=ValidationResult
```

**Generated UseCase:**
```dart
class ValidatePasswordUseCase extends SyncUseCase<ValidationResult, String> {
  final PasswordValidationService _service;

  ValidatePasswordUseCase(this._service);

  @override
  ValidationResult execute(String password) {
    // Service method must be synchronous
    return _service.validatePasswordSync(password);
  }
}
```

## Error Handling

`SyncUseCase` automatically wraps exceptions in `Result<T, AppFailure>`:

```dart
class ValidateUrlUseCase extends SyncUseCase<bool, String> {
  @override
  bool execute(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw ArgumentError('URL must start with http:// or https://');
    }
    
    final uri = Uri.parse(url);
    return uri.hasAuthority;
  }
}
```

**Usage with Error Handling:**
```dart
final result = validateUrl('not-a-url');
result.fold(
  (isValid) => print('URL is valid: $isValid'),
  (failure) {
    switch (failure) {
      case ValidationFailure():
        print('Validation failed: ${failure.message}');
      case UnknownFailure():
        print('Unexpected error: ${failure.message}');
    }
  },
);
```

## Testing SyncUseCase

Testing is straightforward since operations are synchronous:

```dart
void main() {
  test('ValidateEmailUseCase should validate correct email', () {
    final useCase = ValidateEmailUseCase();
    
    final result = useCase('user@example.com');
    
    expect(result.isSuccess, true);
    expect(result.value, true);
  });

  test('ValidateEmailUseCase should reject invalid email', () {
    final useCase = ValidateEmailUseCase();
    
    final result = useCase('not-an-email');
    
    expect(result.isSuccess, false);
    expect(result.failure, isA<ValidationFailure>());
  });

  test('FilterActiveProductsUseCase should filter inactive products', () {
    final products = [
      Product(id: '1', name: 'Product 1', isActive: true),
      Product(id: '2', name: 'Product 2', isActive: false),
      Product(id: '3', name: 'Product 3', isActive: true),
    ];
    
    final useCase = FilterActiveProductsUseCase();
    final result = useCase(products);
    
    expect(result, hasLength(2));
    expect(result.every((p) => p.isActive), true);
  });
}
```

## Best Practices

1. **Keep Operations Pure**: Avoid side effects in sync operations
2. **Handle Dependencies Carefully**: Ensure repository/service methods are synchronous
3. **Validate Input**: Use SyncUseCase for all input validation
4. **Consider Performance**: For complex calculations, consider BackgroundUseCase
5. **Document Intent**: Use clear method names to indicate sync nature
6. **Test Thoroughly**: Sync operations are easy to test - take advantage

## When NOT to Use SyncUseCase

Avoid using `SyncUseCase` for:

- **API Calls** - Use `UseCase` (default)
- **Database Operations** - Use `UseCase` (default)
- **File I/O** - Use `UseCase` (default)
- **Network Requests** - Use `UseCase` (default)
- **Complex Calculations** - Use `BackgroundUseCase` for CPU-intensive work
- **Real-time Data** - Use `StreamUseCase`

## Examples

### E-commerce Validation

```bash
# Product validation rules
zfa generate ValidateProduct \
  --domain=products \
  --type=sync \
  --params=Product \
  --returns=ValidationResult

# Order validation
zfa generate ValidateOrder \
  --domain=orders \
  --type=sync \
  --params=Order \
  --returns=ValidationResult

# Discount calculation
zfa generate CalculateDiscount \
  --domain=pricing \
  --repo=Pricing \
  --type=sync \
  --params=DiscountRequest \
  --returns=double

# Cart total calculation
zfa generate CalculateCartTotal \
  --domain=cart \
  --type=sync \
  --params=List<CartItem> \
  --returns=CartSummary
```

### User Input Validation

```bash
# Email validation
zfa generate ValidateEmail \
  --domain=validation \
  --type=sync \
  --params=String \
  --returns=bool

# Phone validation
zfa generate ValidatePhone \
  --domain=validation \
  --type=sync \
  --params=String \
  --returns=ValidationResult

# Password strength check
zfa generate CheckPasswordStrength \
  --domain=auth \
  --service=PasswordPolicy \
  --type=sync \
  --params=String \
  --returns=PasswordStrength

# Username availability check
zfa generate CheckUsernameAvailable \
  --domain=auth \
  --repo=User \
  --type=sync \
  --params=String \
  --returns=bool
```

### Data Processing

```bash
# Filter active items
zfa generate FilterActiveItems \
  --domain=items \
  --type=sync \
  --params=List<Item> \
  --returns=List<Item>

# Sort by date
zfa generate SortItemsByDate \
  --domain=items \
  --type=sync \
  --params=List<Item> \
  --returns=List<Item>

# Calculate totals
zfa generate CalculateTotals \
  --domain=analytics \
  --type=sync \
  --params=List<Transaction> \
  --returns=Summary

# Format currency
zfa generate FormatCurrency \
  --domain=utils \
  --type=sync \
  --params=double \
  --returns=String
```

## See Also

- [UseCase Types](../cli/commands#custom-usecase-generation) - All UseCase types and patterns
- [Result Type](../architecture/result-type) - Type-safe error handling
- [Controller Pattern](../architecture/vpc-regeneration) - Using UseCases with controllers
- [Testing Guide](../features/testing) - Testing strategies for UseCases