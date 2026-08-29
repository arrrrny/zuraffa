# Research: Slice Plugin

## R-001: Import Graph Traversal in Dart Projects

**Decision**: Use syntactic-only AST parsing (`FileParser.parseSource()` / `parseFile()`) with `AstHelper.extractImports()` for import resolution. No resolved analysis context needed.

**Rationale**: Resolved analysis (`AnalysisContextCollection`) requires the full project to be analyzable (all dependencies resolved, no errors), takes 10-30x longer, and requires a valid `pubspec.yaml` + `.dart_tool/package_config.json`. Syntactic parsing gives us import URIs in <50ms per file, which is sufficient for graph construction. We only need URI strings, not resolved types.

**Alternatives considered**:
- `AnalysisContextCollection` with `getResolvedUnit()` — too slow, too fragile. Projects with compile errors (common during development) would fail.
- `dart_analyzer_plugin` — designed for IDE integration, not batch processing. Wrong abstraction level.
- Simple regex (`import '...'`) — misses multiline imports, `show`/`hide` clauses, and conditional imports. AST is the right tool.

## R-002: Service Locator Type Extraction (`getIt<T>()`)

**Decision**: Build a custom `RecursiveAstVisitor` that finds `MethodInvocation` nodes where the method name is a generic function call matching the `getIt<T>()` pattern, and extract the type argument `T`.

**Rationale**: In ZikZak's presenter pattern, dependencies are resolved from the global service locator in the constructor body:
```dart
_getBarcodeListing = registerUseCase(getIt<GetBarcodeListingUseCase>());
final _listingProvider = getIt<ListingProvider>();
```
These are not imports — they're runtime resolutions. The import for the type exists, but the DI registration file that wires the binding does NOT appear in imports. We must:
1. Extract all `getIt<T>()` type arguments from the file
2. Match each type `T` to its DI registration file using naming convention: `T` → `snake_case(T)_di.dart` under `lib/src/di/`

**Alternatives considered**:
- Only following imports (missing DI files entirely) — breaks the sandbox because mocks won't know which interfaces to stub
- Full resolved analysis to follow type chains — overkill; naming convention is deterministic and reliable

## R-003: Barrel File Selective Resolution

**Decision**: When an import resolves to a barrel file (`index.dart`), parse the barrel to extract its `export` directives, then intersect with the set of symbols actually used by the importing file (extracted from `show` clauses, or all exports if no `show` clause). For DI barrels specifically (`di/usecases/index.dart`), match against the set of DI types the slice needs.

**Rationale**: ZikZak's `di/usecases/index.dart` re-exports 145 registration functions. Naively following this import pulls in the entire DI layer. But the slice only needs 3-5 registrations. We must:
1. Detect barrel files (files that are >80% export directives by line count, or named `index.dart`)
2. Parse their exports to get the list of re-exported files
3. Include only the exports that match types needed by the slice

**Alternatives considered**:
- Always expand all barrel exports — defeats the purpose of slicing. A single `di/index.dart` import would pull in 271 DI files.
- Never follow barrel files — misses legitimate shared utilities that are re-exported via barrels.
- Replace barrel imports in sliced files — violates the "no import rewriting" principle. The sliced files should remain identical to their originals.

**Resolution**: Don't rewrite imports. Instead, generate a slice-specific barrel (`slice_di.dart`) that registers only needed types. The slice's `main_slice.dart` calls `setupSliceDependencies()` which uses this generated barrel. The original files keep their original imports — they still compile because the slice barrel provides all needed symbols.

## R-004: `package:` Self-Import Resolution

**Decision**: Read `.dart_tool/package_config.json` to map `package:<name>/...` URIs to filesystem paths. The package config contains the `rootUri` for each package, and `packageUri` points to `lib/`.

**Rationale**: Dart projects use `package:my_app/src/...` imports internally. These need to be resolved to `<project_root>/lib/src/...` paths. The `.dart_tool/package_config.json` is the single source of truth for this mapping, always present in valid Dart projects.

**Alternatives considered**:
- Hardcode `package:<name>/` → `lib/` — works for single-package projects but breaks for workspace/monorepo setups.
- Use `pubspec.yaml` name field — requires YAML parsing and doesn't handle path dependencies correctly.

## R-005: File Ownership Classification

**Decision**: Classify files using a reference-count heuristic:
- **owned**: Files where the only path from any entry point in the project to this file passes through the slice's entry points. In practice: files inside the slice's page directory (`presentation/pages/<feature>/`).
- **shared**: Files referenced by multiple features. Detected by scanning all page directories' imports and checking if the file appears in more than one feature's transitive closure.
- **framework**: Files from external packages (SDK, pub dependencies). Never included in the slice — they're just import statements.

**Rationale**: The full reference-count analysis is expensive (requires scanning ALL features). For v1, use a convention-based approximation:
- Files in `presentation/pages/<feature>/` → owned
- Files in `domain/entities/`, `domain/repositories/`, `domain/services/`, `domain/usecases/` → shared (entities and domain interfaces are used across features)
- Files in `presentation/widgets/`, `core/`, `config/`, `constants/` → shared
- Files in `data/` → depends on depth level

**Alternatives considered**:
- Full project scan for reference counting — correct but too slow for v1. Can be added as a v2 optimization.
- Manual annotation (dev marks files as shared) — too much friction for the developer.

## R-006: Merge-Back Strategy

**Decision**: Hash-based 3-way comparison:
1. At cut time, store SHA-256 hash of each included file in `slice.yaml`
2. At merge time, for each file in the slice:
   - Compute hash of file in sandbox → `sandbox_hash`
   - Retrieve hash from manifest → `cut_hash`
   - Compute hash of file in main project → `main_hash`
   - If `sandbox_hash == cut_hash` → not modified, skip
   - If `sandbox_hash != cut_hash` AND `main_hash == cut_hash` → agent modified, main unchanged → safe to copy back
   - If `sandbox_hash != cut_hash` AND `main_hash != cut_hash` → both modified → CONFLICT, warn developer

**Rationale**: This is the standard 3-way merge strategy used by Git. It avoids false positives (unchanged files being flagged) and detects true conflicts (concurrent modification). Using file hashes rather than timestamps is deterministic and avoids timezone/filesystem issues.

**Alternatives considered**:
- Timestamp-based comparison — unreliable across filesystems, timezones, and file copy operations.
- Git-level merge (create a branch, commit, merge) — too heavy for the slice workflow. The slice is a temporary working directory, not a persistent branch.
- Always overwrite — dangerous. A concurrent change in the main project would be silently lost.

## R-007: Plugin Architecture Choice

**Decision**: Extend `ZuraffaPlugin` directly (like `SkeletonPlugin`), not `FileGeneratorPlugin`. Implement `CliAwarePlugin` for CLI commands.

**Rationale**: The slice plugin does not generate architecture code (usecases, repositories, views). It extracts existing code into a sandbox and generates a lightweight harness. The `FileGeneratorPlugin` pattern assumes entity-centric generation with `GeneratorConfig`, which doesn't fit. The `SkeletonPlugin` (bones) is the closest precedent — it also extends `ZuraffaPlugin` directly and manages its own file I/O.

**Alternatives considered**:
- `FileGeneratorPlugin` — forces conformance to `GeneratorConfig` (which expects entity name, methods, etc.). The slice plugin doesn't work with entities in that way.
- Standalone CLI tool outside Zuraffa — loses access to the plugin infrastructure, AST helpers, discovery engine, and the `zfa` CLI namespace.

## R-008: Sandbox Directory Structure

**Decision**: Use a flat mirror of the original project structure under `.zuraffa/slices/<name>/`:

```
.zuraffa/slices/<name>/
├── slice.yaml                    # Manifest
├── SLICE.md                      # Agent instructions
├── main_slice.dart               # Runnable entry point
├── lib/src/                      # Mirror of original structure
│   ├── presentation/pages/...    # Copied files (preserving paths)
│   ├── domain/entities/...
│   ├── domain/usecases/...
│   └── di/slice_di.dart          # Generated: minimal DI registrations
└── pubspec.yaml                  # Symlink or copy of original pubspec
```

**Rationale**: Mirroring the original structure means all `package:` imports resolve correctly without rewriting. The developer (or agent) can navigate the slice using familiar paths. The `pubspec.yaml` ensures `flutter run -t .zuraffa/slices/<name>/main_slice.dart` can resolve all external dependencies.

**Alternatives considered**:
- Flat directory (all files in one folder) — breaks import paths. Would require rewriting every import statement.
- Symlinks to original files — editing a symlinked file modifies the original, defeating the isolation purpose.
- Overlay filesystem — too complex for v1. Requires OS-level support (FUSE on Linux, not available on macOS/Windows).
