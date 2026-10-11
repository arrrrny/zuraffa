# Issue #1270 — zfa entity create: primitive types (bool/int/double) rejected — must scaffold an enum dir first

- **Severity:** medium
- **Reporter:** ahmettok (filed during apps/login_demo spec 001-login-ui build)
- **State:** open

## Bug Report

**Repro:**

```bash
zfa entity create -n Login --field isLoading:Boolean --field hasError:Boolean
```

**Expected:** Login entity created with `isLoading` and `hasError` as boolean fields.

**Actual:**

```
Cannot create entity "Login": field type(s) could not be resolved.
  • Unknown type "Boolean" for field "isLoading" — no matching entity directory
    or enum file found under lib/src/domain/entities.
  • Unknown type "Boolean" for field "hasError" — no matching entity directory
    or enum file found under lib/src/domain/entities.
```

**Root cause:** zfa only resolves field types from existing entity directories or enum files under `lib/src/domain/entities/`. There is no built-in primitive type support — `Boolean`, `int`, `double` are all rejected.

**Suggested fix:** Add support for primitive types directly: `bool`, `int`, `double`, `String`, `num`. Either:

1. Inline primitive types in the entity (`bool get isLoading;` instead of forcing a typedef to a directory), or
2. Auto-scaffold primitive enum stubs (`boolean.dart` → `enum Boolean { true, false }` or similar) when referenced.

**Workaround used:** Created entity with String fields, then implemented `isLoading` / `hasError` as computed getters on LoginState:

```dart
bool get isLoading => isGetting || isUpdating || isToggling;
bool get hasError => error != null;
```
