# Data Model: Migrate `html_to_markdown_ffi` to zuraffa (spec 064)

## Layers

1. **Preserved public API types** (frozen compatibility surface — pre-existing code protected by
   FR-003/FR-006; behavior unchanged, imports unchanged):

   | Type | Kind | Notes |
   |------|------|-------|
   | `ConversionOptions` | mutable config | 40+ fields with defaults; `toJson`/`fromJson` round-trip; snake_case wire keys |
   | `PreprocessingOptions` | immutable config | `enabled/preset/removeNavigation/removeForms` |
   | `ConversionResult` | output | `content`, `document`, `metadata`, `tables`, `images`, `warnings`; `fromJson` |
   | `HtmlMetadata` | output part | title, description, lang, author, keywords, links, images |
   | `ProcessingWarning` | output part | `code`/`message` (verify exact fields at implementation) |
   | `HeadingStyle`, `ListIndentType`, `HighlightStyle`, `WhitespaceMode`, `NewlineStyle`, `CodeBlockStyle`, `LinkStyle`, `OutputFormat` | enums | `toJson`/`fromJson` per enum |
   | `Visitor` | callback interface | HTML walk events for custom markdown emission |
   | `ConversionErrorException`, `NativeLibraryException`, … | exceptions | `lib/exceptions.dart` family |
   | `convert(String html, {ConversionOptions?, Visitor?}) → ConversionResult` | top-level function | **synchronous** dart:ffi call |
   | `NativeLibrary` | FFI loader | resolution chain env→bundled→cache→cargo→open→process; `downloadIfNeeded()` |

2. **zfa-generated internal stack** (the new architecture — FR-002/SC-005; produced by
   `zfa entity create` + `zfa make`, zorphy-generated `.zorphy.dart`/`.g.dart`):

   | Artifact | Produced by | Role |
   |----------|-------------|------|
   | `HtmConversion` entity (request/response pair: html, options-json, result-json envelope) | `zfa entity create` | internal subject of the use case/repository/datasource generation; mapped to/from the public types at the service boundary |
   | `HtmConversionRepository` (contract) | `zfa make repository` | data-layer port over the native bridge |
   | `HtmConversionDatasource` + FFI datasource impl | `zfa make datasource` | **the wrapper around the existing FFI bridge** (FR-004) |
   | `ConvertHtmlUseCase` | `zfa make usecase` | business-logic entry the service delegates to |

3. **Family port/service stack** (scaffold-customized, per the create-plugin contract):

   | Artifact | Package | Role |
   |----------|---------|------|
   | `HtmlToMarkdownFfiPort` | app | platform-neutral conversion port: `convert` (async, envelope), `convertSync` (in-process fast path), `isSupported` |
   | `HtmlToMarkdownFfiService` | app | facade; typed `HtmlToMarkdownFfiException` failures; unwired-port placeholder |
   | `registerHtmlToMarkdownFfiDependencies(GetIt, {port})` | app | runtime module (auto-DI contribution) |
   | `PlatformHtmlToMarkdownFfiEnvelope` (+ sync helpers) | platform | transport seam `ChannelInvoke`, payload validation, typed-error mapping, timeout |
   | Visitor vtable bridge plumbing | platform | shared dart:ffi `HTMHtmHtmlVisitorVTable` machinery used by adapters |
   | `HtmNativeLibraryResolver` | platform | seam the preserved `NativeLibrary` consults for adapter-bundled binaries |
   | `MacosHtmlToMarkdownFfiPort`/`Channel`/`register…` | macos adapter | real FFI over bundled dylibs (arm64/x64) |
   | `AndroidHtmlToMarkdownFfiPort`/`Channel`/`register…` | android adapter | loader over bundled `.so` (3 ABIs; jniLibs/loader path + process) |
   | `IosHtmlToMarkdownFfiPort`/`Channel`/`register…` | ios adapter | loader over statically linked `.a` (process symbols) |

## Family dependency graph (contract — pinned by tests)

```text
html_to_markdown_ffi  →  zuraffa (hosted only)
html_to_markdown_ffi_platform  →  html_to_markdown_ffi
html_to_markdown_ffi_android  →  html_to_markdown_ffi + …_platform
html_to_markdown_ffi_ios      →  html_to_markdown_ffi + …_platform
html_to_markdown_ffi_macos    →  html_to_markdown_ffi + …_platform
nobody → adapter
```

## Native artifact placement

| Adapter | Files (from pre-migration `native/`) |
|---------|--------------------------------------|
| `_android` | `native/android/armeabi-v7a/libhtml_to_markdown_ffi.so`, `arm64-v8a/…so`, `x86_64/…so` |
| `_ios` | `native/ios/ios-arm64.a`, `ios-sim-arm64.a`, `ios-sim-x64.a` |
| `_macos` | `native/macos-arm64/libhtml_to_markdown_ffi.dylib`, `native/macos-x64/…dylib` |

## State transitions

None — the converter is stateless per call. The only lifecycle state is the `NativeLibrary`
singleton (`_instance`) and the service's unwired→wired registration, unchanged in semantics from
the scaffold.
