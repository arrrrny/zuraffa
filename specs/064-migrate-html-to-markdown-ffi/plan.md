# Implementation Plan: Migrate `html_to_markdown_ffi` to be built on zuraffa

**Branch**: `064-migrate-html-to-markdown-ffi` | **Date**: 2026-09-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/064-migrate-html-to-markdown-ffi/spec.md` (issue [#687](https://github.com/arrrrny/zuraffa/issues/687), epic #214)

## Summary

Restructure the standalone `html_to_markdown_ffi` Dart FFI package (pub.dev 1.1.0) into a
zuraffa-built federated plugin monorepo — the shape `zuraffa_auth` and `zuraffa_permissions`
follow — scaffolded with `zfa package create-plugin html_to_markdown_ffi` (default platforms
`android,ios,macos`). The existing Rust-FFI conversion behavior is preserved verbatim: the
public API surface stays compatible (FR-006), the prebuilt native binaries move into the
federated adapters (FR-003), and the zuraffa data layer wraps the existing FFI bridge through
a datasource (FR-004). The family is delivered in `~/Developer/html_to_markdown_ffi` and
published to pub.dev (FR-008).

## Technical Context

**Language/Version**: Dart 3 (pure Dart packages, `sdk: ^3.11.0`; no Flutter SDK dependency)

**Primary Dependencies**: `zuraffa: ^6.2.2` (hosted), `ffi: ^2.1.0` (FFI bridge), `zorphy_annotation`
+ `build_runner` (generated entities), `http` (native-library download fallback). In-family deps are
sibling `dependency_overrides` in development, hosted constraints on publish.

**Storage**: N/A (stateless conversion library; native binaries are bundled assets per adapter)

**Testing**: `dart test` (package:test) per package; host-executable proof on macOS via the bundled
macOS dylibs; offline structural tests over fake injected channels for the adapters and envelope.

**Target Platform**: CLI/server/desktop Dart on macOS (host proofs), Android/iOS/macOS apps as
consumers of the federated adapters.

**Project Type**: federated plugin monorepo (5 pure-Dart packages + publish scripts)

**Performance Goals**: conversion throughput unchanged from pre-migration (same native library,
same call path plus one delegation hop)

**Constraints**: public API surface must stay import-compatible (`package:html_to_markdown_ffi/html_to_markdown.dart`
and the loose `lib/*.dart` entry points); native binding logic must not be altered (FR-003);
existing test assertions unchanged beyond import paths (FR-005)

**Scale/Scope**: 5 packages, ~10 ported test files, 64-file scaffold + ported FFI machinery

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Architecture contribution via zuraffa-native packages: PASS — the app package contributes a
  runtime module (`registerHtmlToMarkdownFfiDependencies`) and a port/service stack built on
  `zuraffa` types; adapters register via GetIt.
- Generated-not-handwritten architecture: PASS (with recorded boundary) — the new zuraffa stack
  (entities, repository, datasource, use case, module) is produced by `zfa entity create` /
  `zfa make`; the preserved public API classes are pre-existing migration-protected code
  (FR-006/FR-003), not new architecture. Recorded in research.md D4.
- Honest gates: PASS — every family claim is proven by running `dart pub get` / `dart analyze` /
  `dart test` / `dart pub publish --dry-run` per package; host FFI proofs run the real dylib.
- Publish pipeline: PASS — the scaffold's zikzak publish scripts (prepare → publish →
  push_to_master) are used verbatim.

## Project Structure

### Documentation (this feature)

```text
specs/064-migrate-html-to-markdown-ffi/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (public API + family contracts)
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (delivered monorepo: `~/Developer/html_to_markdown_ffi`)

```text
html_to_markdown_ffi/                    # existing repo, restructured (history preserved)
├── CHANGELOG.md                         # existing changelog, kept as root release notes
├── LICENSE, README.md, PUBLISH.md
├── scripts/                             # scaffolded zikzak publish pipeline
│   ├── prepare_for_publish.sh <version>
│   ├── publish.sh
│   ├── push_to_master.sh
│   └── restore_dev_setup.sh
└── packages/
    ├── html_to_markdown_ffi/            # app-facing: zuraffa stack + preserved public API
    │   ├── lib/html_to_markdown.dart    # preserved barrel (FR-006)
    │   ├── lib/convert.dart             # preserved sync convert() → service sync path
    │   ├── lib/exceptions.dart, visitor.dart, visitor_bridge.dart
    │   ├── lib/models/…                 # preserved public types (unchanged behavior)
    │   ├── lib/src/domain/entities/…    # zfa-generated internal entities (zorphy)
    │   ├── lib/src/domain/repositories|datasources|usecases/  # zfa make
    │   ├── lib/src/html_to_markdown_ffi_{port,service,module,exception}.dart
    │   └── test/                        # ported legacy suite (assertions unchanged) + service tests
    ├── html_to_markdown_ffi_platform/   # shared envelope: transport seam, payload decode,
    │   │                                # typed-error mapping, visitor vtable plumbing,
    │   │                                # HtmNativeLibraryResolver seam
    │   └── lib/src/…
    ├── html_to_markdown_ffi_android/    # adapter: bundled .so (3 ABIs) + Android loader + port
    ├── html_to_markdown_ffi_ios/        # adapter: bundled .a (3 slices) + static-link loader + port
    └── html_to_markdown_ffi_macos/      # adapter: bundled dylibs (arm64/x64) + dlopen loader + port
```

**Structure Decision**: The deliverable is the existing `arrrrny/html_to_markdown_ffi` repository
restructured in place into the five-package federated family produced by
`zfa package create-plugin` — not a fresh repo. Git history, CHANGELOG, LICENSE, and the prebuilt
native binaries are preserved; the scaffold provides the family skeleton, publish scripts, and
test harnesses which are then customized to conversion semantics.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Sync + async conversion paths on one port | The preserved public `convert()` is synchronous dart:ffi; the federated port contract is async to fit the envelope and non-FFI transports | Dropping the sync path would break FR-006 (public API) — not allowed |
| Compatibility re-export shims for loose `lib/*.dart` entry points | Third parties import `package:html_to_markdown_ffi/native_library.dart` etc. directly; FR-006 forbids breaking them | Moving files without shims breaks published consumers |
