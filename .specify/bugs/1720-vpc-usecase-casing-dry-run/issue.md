# Bug Issue: `zfa make --usecases` emits non-compiling presenter/controller (wrong identifier casing); dry-run always reports placeholder fakes

- **Slug**: 1720-vpc-usecase-casing-dry-run
- **Fetched**: 2026-09-18T00:00:00+00:00
- **Issue**: 1720
- **URL**: https://github.com/arrrrny/zuraffa/issues/1720
- **State**: open
- **Severity**: high
- **Author**: arrrrny
- **Labels**: bug

## Body

### Summary

vpc generation: `zfa make Login --no-entity --with=vpc,state,route,di --usecases=login,logout,sign_in_with_google,sign_in_with_apple,sign_anonymously --without=repository,datasource,cache,usecase` emits a presenter (and controller) whose import paths are correct but whose **type references use lowercased identifiers**, producing `undefined class` errors throughout. Additionally, `--dry-run` always announces `Generating placeholder Fake<X>UseCase ... interface not declared` even when the named usecase file exists on disk and declares the class.

### Repro

Existing usecases `LoginUseCase`, `LogoutUseCase`, `SignInWithGoogleUseCase`, etc. in `lib/src/domain/usecases/auth/`:

```bash
zfa make Login --no-entity --with=vpc,state,route,di \
  --usecases=login,logout,sign_in_with_google,sign_in_with_apple,sign_anonymously \
  --without=repository,datasource,cache,usecase
```

Generated presenter:

```dart
import '../../../domain/usecases/auth/login_usecase.dart';          // ← import path CORRECT
...
    _login = registerUseCase(getIt<loginUseCase>());                // ← class ref WRONG (camelCase)
    _sign_in_with_google = registerUseCase(getIt<sign_in_with_googleUseCase>());  // ← WRONG
```

Imports resolve to real classes but every type reference uses a lowercased identifier — `undefined class` throughout.

### Token forms tried

| `--usecases` token | Generated reference | Compiles? |
|--------------------|---------------------|-----------|
| `login` | `loginUseCase` | ✗ undefined class |
| `LoginUseCase` | `LoginUseCaseUseCase` (suffix doubled) | ✗ |
| `loginUseCase` | `loginUseCaseUseCase` (suffix doubled, still lowercase) | ✗ |

### Additionally

`--dry-run` always announces `Generating placeholder Fake<X>UseCase ... interface not declared` even when the named file exists and declares the class — dry-run fails to detect existing usecases.

### Expected

Presenter/controller type references use the actual usecase class names (`LoginUseCase`, `SignInWithGoogleUseCase`, etc.) — PascalCase, no suffix doubling — matching the imports the same generator emits. `--dry-run` detects existing usecases by name (scan import path or class declaration).
