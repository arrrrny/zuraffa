# Bug Assessment: `zfa make --usecases` wrong identifier casing + dry-run always reports placeholder fakes

- **Slug**: 1720-vpc-usecase-casing-dry-run
- **Assessed**: 2026-09-18
- **Issue**: ./issue.md
- **Severity**: High
- **Status**: Open

---

## Summary

Two generator defects make `zfa make <Name> --no-entity --with=vpc,... --usecases=<tokens>` output non-compiling Dart and make `--dry-run` misreport existing usecases as missing. Both stem from the same upstream mistake: `--usecases` tokens are concatenated with a `UseCase` suffix and carried into generated code **as-is**, without normalizing to the PascalCase class name the same generator uses for its (correct) import paths.

---

## Root Cause

### Defect 1 — usecase class references never normalized to PascalCase

`lib/src/core/builder/patterns/common_patterns.dart:190` (`CommonPatterns.parseUseCaseInfo`):

```dart
final className = u.endsWith('UseCase') ? u : '${u}UseCase';
```

The token `u` is only suffix-guarded, never cased. Downstream, the presenter plugin emits the class ref verbatim (`presenter_plugin.dart:329` — `refer('getIt').call([], {}, [refer(info.className)])`, plus field types at `:258`), so token casing flows straight into Dart identifiers:

| token | className emitted |
|-------|-------------------|
| `login` | `loginUseCase` (undefined — real class is `LoginUseCase`) |
| `sign_in_with_google` | `sign_in_with_googleUseCase` (undefined) |
| `LoginUseCase` | `LoginUseCase` (accidentally correct) |

The same un-normalized ternary is duplicated in two more generators:

- `lib/src/plugins/di/di_plugin.dart:1109-1111` (`_generateOrchestratorUseCaseDI`) — emits `getIt<loginUseCase>()` into `di/usecases/*_usecase_di.dart`.
- `lib/src/plugins/usecase/generators/custom_usecase_generator_orchestrator.dart:42-44` — orchestrator usecase field/param types.

Import paths are unaffected (that is why imports are correct while refs are wrong): they are derived separately via `StringUtils.camelToSnake(token-minus-suffix)` + `findUseCaseDomain` directory scan (`presenter_plugin.dart:947-959`), which is casing-independent.

### Defect 2 — test-builder fake interface name unconditionally re-suffixed, so existing usecases are never detected

`lib/src/plugins/test/builders/test_builder_orchestrator.dart:65-74`:

```dart
fakeSpecs.add(await _requireFakeClassForDependency(
  className: 'Fake${usecase}UseCase',   // ← unconditional suffix
  interfaceName: '${usecase}UseCase',   // ← unconditional suffix
  filePath: usecaseFile?.path, ...
));
```

The file lookup (`discovery.findFileSync('${usecaseSnake}_usecase.dart')`, lines 62-64) succeeds because the snake name is correct — but the class-declaration check inside `_generateFakeClassForDependency` (`test_builder_helpers.dart:82-92`) compares declarations against `interfaceName.split('<').first`:

- token `login` → looks for `loginUseCase`, file declares `LoginUseCase` → no match
- token `LoginUseCase` → looks for `LoginUseCaseUseCase`, file declares `LoginUseCase` → no match

`targetClass == null` → `_requireFakeClassForDependency` prints
`⚠️  Generating placeholder Fake<X>UseCase for X: interface not declared in <file>.`
(`test_builder_helpers.dart:144-150`) and falls back to a placeholder fake — **every time**, regardless of dry-run. This is exactly the observed "dry-run always announces placeholder fakes for existing usecases" symptom; the mangled name also doubles the `UseCase` suffix in the emitted fake class/variable identifiers (`FakeLoginUseCaseUseCase`, `fakeLoginUseCaseUseCase`).

---

## Impact

- Any `--usecases` invocation with snake_case or camelCase tokens (the documented, natural form: `--usecases=login,logout,sign_in_with_google`) emits non-compiling presenter/controller/DI code (`undefined class`), failing `zfa build`/`dart analyze` gates.
- `--dry-run` (and real runs with the test plugin) always emit placeholder-fake warnings for usecases that exist, misleading users into thinking their usecases are not detected.

## Remediation Plan

1. Add one canonical normalizer, `StringUtils.normalizeUseCaseClassName(token)`: strip a trailing `UseCase`, Pascal-case the base via `convertToPascalCase` (handles snake_case/camelCase), append exactly one `UseCase`.
2. Use it in `CommonPatterns.parseUseCaseInfo` for `className` only — `fieldName`/`usecaseSnake` keep their existing raw-token derivation (zero field-name or import-path behavior change; strictly a type-reference fix).
3. Use it in `test_builder_orchestrator.dart` for fake class/interface/variable identifiers — kills the doubling and makes the class-declaration check match real declarations, so existing usecases are detected (no more spurious placeholder warnings).
4. Use it in `di_plugin.dart` `_generateOrchestratorUseCaseDI` and `custom_usecase_generator_orchestrator.dart`.

## Constraints

- Fix ONLY the usecase reference casing and dry-run detection.
- Do NOT change presenter/controller structure or the `--usecases` token parsing input contract (all previously accepted token forms remain accepted; only their emitted identifier casing changes).
- Generated code must compile with `dart analyze`.
