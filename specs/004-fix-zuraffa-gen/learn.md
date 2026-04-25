# What I Learned: Fix Zuraffa Code Generation Import and Type Emission

**Feature**: Fix broken `package:app/` imports, inconsistent `useZorphy` generics, and method name gaps in the Zuraffa CLI code generator
**Generated**: 2026-04-17
**Scope**: Full feature
**Implementation status**: 58/58 tasks completed

---

## Key Decisions

### 1. Relative Paths Instead of Package-Style Imports

**What we did**: Replaced `PackageUtils.getBaseImport()` (which produced `package:{name}/...` strings) with a simple depth-based relative path computation: `'../' * depth` in `CommonPatterns.entityImports()`.

**Why**: `PackageUtils.getPackageName()` walked up directories looking for `pubspec.yaml` and fell back to the literal string `'app'` when not found. In AI agent contexts, monorepos, and non-standard project layouts, the package name is often undeterminable — causing every generated import to read `package:app/...`, which doesn't compile. Relative paths don't need to know the package name at all.

**Alternatives considered**:
| Approach | Why it wasn't chosen |
|----------|---------------------|
| Fix `getPackageName()` to always find the right name | Fragile — still breaks in monorepos, temp dirs, and AI agent sandboxed environments |
| Keep package imports but default to a better fallback name | Still wrong for any project whose name doesn't match the fallback |

**When you'd choose differently**: Package-style imports are fine for external dependencies (like `package:zuraffa/zuraffa.dart`) or when you control the entire project layout and can guarantee the package name is always resolvable. For a code generator that targets arbitrary project structures, relative paths are the only robust choice.

### 2. Depth-Based Path Construction Over `path.relative()`

**What we did**: Used `'../' * depth` concatenated with the known target path structure (`domain/entities/{entity}/{entity}.dart`) instead of calling `path.relative(source, from: target)`.

**Why**: The output directory structure is deterministic — every generated file lives at a predictable depth from the project root (e.g., use cases at depth 3: `{output}/domain/usecases/{domain}/`). Multiplying `'../'` by the known depth is simpler, faster, and doesn't require knowing the absolute paths of both source and target at import-construction time. The generators already know their own depth because they define where files are written.

**Alternatives considered**:
| Approach | Why it wasn't chosen |
|----------|---------------------|
| `path.relative()` with absolute paths | Requires plumbing absolute file paths through generators that currently only know relative output dirs |
| Hardcoded `'../../...'` strings per generator | Already works for some generators (DI, remote, local) but centralizing in `CommonPatterns` reduces duplication |

**When you'd choose differently**: If the output structure becomes dynamic (user-configurable nested subdirectories), depth multiplication won't work and you'd need actual path computation. For a convention-over-configuration tool with a fixed directory structure, depth is sufficient and clearer.

### 3. Fixing the Depth Parameter (2 → 3 for Use Case Generators)

**What we did**: Changed `depth: 2` to `depth: 3` in all 6 use case generator files.

**Why**: Use case files are output at `{outputDir}/domain/usecases/{domain}/` — that's 3 levels deep from `outputDir`. With `depth: 2`, the import `'../../domain/entities/...'` resolved to `{outputDir}/domain/domain/entities/...` (double `domain/`). With `depth: 3`, `'../../../domain/entities/...'` resolves correctly. This was the single bug that caused the last failing regression test.

**When you'd choose differently**: If you ever restructure the output layout (e.g., flatten use cases to `{outputDir}/usecases/`), you must recalculate depth for every affected generator. A wrong depth produces wrong imports that silently compile but point to non-existent files.

### 4. Inline `useZorphy` Conditional Over Extracted Helper

**What we did**: Added `config.useZorphy ? '{Entity}Patch' : 'Partial<{Entity}>'` inline at each of the 5 generators that were missing the check.

**Why**: The 6 generators that already handled `useZorphy` correctly all used the same inline ternary pattern. Extracting a shared helper would add indirection for a single boolean conditional — overkill for a one-liner that's immediately readable. Consistency with the existing codebase pattern matters more than DRY here.

**Alternatives considered**:
| Approach | Why it wasn't chosen |
|----------|---------------------|
| Extract a shared `resolveDataType(entityName, useZorphy)` helper | Adds indirection for a single boolean check; inline ternary is clearer at each call site |
| Always use `{Entity}Patch` | Breaking change for users who don't use Zorphy — their code wouldn't compile |

**When you'd choose differently**: If the type resolution logic grows beyond a simple ternary (e.g., supporting 3+ patch strategies, custom type mappings), extracting a helper becomes worthwhile. With exactly two options, inline is the right call.

### 5. Adding the Missing `toggle` Case to DI Plugin

**What we did**: Added a `toggle` case to `_getUseCaseInfo()` in `di_plugin.dart` matching the existing entries for `get`, `getList`, `create`, `update`, `delete`, `watch`, `watchList`.

**Why**: The `entity_usecase_generator.dart` switch block already supported `toggle` (generating `Toggle{Entity}UseCase` calling `repo.toggle()`), but the DI plugin's `_getUseCaseInfo()` switch didn't have it — meaning any `--methods=toggle` generation would throw `ArgumentError` at DI registration time. This was discovered during the method name audit (Phase 5).

**When you'd choose differently**: This is a straightforward bug fix with no tradeoff. The lesson: when adding a new method to one switch block in a code generator, always grep for all other switch blocks that map the same input domain.

---

## Concepts to Know

### Depth-Based Relative Path Computation

**What it is**: Computing relative import paths by multiplying `'../'` by the number of directory levels between the generated file and the project root, then appending the known target path. E.g., a file 3 levels deep needing `domain/entities/foo/foo.dart` gets `'../../../domain/entities/foo/foo.dart'`.

**Where we used it**: `lib/src/core/builder/patterns/common_patterns.dart:36` — `final prefix = '../' * depth;`. Each caller passes its depth: use case generators pass `depth: 3`, provider generators pass `depth: 2`, presenter/state generators pass `depth: 3`.

**Why it matters**: Wrong depth = wrong imports = code doesn't compile. This is the kind of bug that's invisible until you generate code in a real project and see `import '../../../../domain/domain/entities/...'` — the doubled `domain/` is the telltale sign.

### Single Source of Truth for Naming Conventions

**What it is**: Ensuring that method name → class name → DI registration mappings are defined consistently across all switch blocks, so a method like `getList` maps to `Get{Entity}ListUseCase` everywhere — in the use case generator, the DI plugin, and the repository interface.

**Where we used it**: `lib/src/plugins/usecase/generators/entity_usecase_generator.dart:109-348` (primary mapping), `lib/src/plugins/di/di_plugin.dart:1066-1098` (`_getUseCaseInfo` — must mirror the primary). The `toggle` method was in the former but missing from the latter.

**Why it matters**: Code generators are essentially compilers — they must be correct in all phases. A method supported in code generation but broken at DI registration is worse than not supporting it at all (silent runtime failure vs. clear unsupported error).

### Feature Flag Consistency Across Generators

**What it is**: When a configuration flag (like `useZorphy`) affects the output of one generator, every generator that produces code in the same domain must check that same flag and produce consistent output.

**Where we used it**: `useZorphy` affects what `UpdateParams`'s `DataType` is: `{Entity}Patch` vs `Partial<{Entity}>`. Five generators (`interface_generator`, `presenter_plugin`, `service_interface_builder`, `provider_builder`, `mock_provider_builder`) were hardcoding one option instead of checking the flag.

**Why it matters**: A type mismatch between layers (e.g., use case expects `Partial<Product>` but repository interface declares `ProductPatch`) causes compilation failure. The user sees "type error" and has to manually trace which generator was wrong.

### Deprecation Over Deletion

**What it is**: Marking unused API surface with `@Deprecated` instead of deleting it, so any external consumers get a migration path.

**Where we used it**: `lib/src/utils/package_utils.dart:39-42` — `getBaseImport()` is decorated with `@Deprecated` rather than removed, since it's a public method that could be called by consumer code.

**Why it matters**: In library/CLI packages, you don't know who's calling your methods. `@Deprecated` is a compile-time signal that says "this works but stop using it." Deletion is a runtime error that breaks builds. Always deprecate first, delete in the next major version.

---

## Architecture Overview

The import generation pipeline flows through a single chokepoint: `CommonPatterns.entityImports()`. Every generator that needs to import an entity calls this method with a `depth` parameter matching its output directory depth. The method discovers the entity's actual location (domain-scoped, standard, or legacy flat) and constructs the relative import path. This centralization means a single fix propagates to all generators — but it also means a single bug (like wrong depth values) breaks all generators equally.

```
Generator (knows its depth)
    │
    ▼
CommonPatterns.entityImports(types, config, depth: N)
    │  └── prefix = '../' * depth
    │  └── Discovers entity at domain/entities/{snake}/{snake}.dart
    │  └── Returns: '${prefix}domain/entities/{snake}/{snake}.dart'
    ▼
Generated file with correct relative import
```

The `useZorphy` flag follows a different pattern — it's checked inline at each generator rather than centralized, because the type resolution (`Patch` vs `Partial`) is embedded in different code_builder expression trees that don't share a common construction site.

---

## Glossary

| Term | Meaning |
|------|---------|
| `depth` parameter | Number of directory levels from the generated file back to the `outputDir` root; used to compute `'../' * depth` prefix for relative imports |
| `useZorphy` flag | Config flag that determines whether update params use `{Entity}Patch` (Zorphy typed patches) or `Partial<{Entity}>` (generic partial update wrapper) |
| `CommonPatterns.entityImports()` | Central method that resolves entity types to relative import paths; the single chokepoint for all entity import generation |
| `PackageUtils.getBaseImport()` | Now-deprecated method that produced `package:{name}/...` import strings by reading `pubspec.yaml` |
| `_getUseCaseInfo()` | DI plugin method that maps method names (like `'getList'`) to class names and method prefixes for DI registration |
