# Contract: Preserved Public API (`html_to_markdown_ffi` app package)

FR-006: the surface consumed by external dependents MUST remain unchanged. This contract pins
what the migrated app package must still export and from where. **Verification**: a structural
test reads the exported symbols and import paths; the ported legacy suite asserts behavior.

## Import paths (must keep resolving)

| Path | Status |
|------|--------|
| `package:html_to_markdown_ffi/html_to_markdown.dart` | main barrel — preserved |
| `package:html_to_markdown_ffi/convert.dart` | preserved (top-level `convert`) |
| `package:html_to_markdown_ffi/exceptions.dart` | preserved |
| `package:html_to_markdown_ffi/models/conversion_options.dart` | preserved |
| `package:html_to_markdown_ffi/models/conversion_result.dart` | preserved |
| `package:html_to_markdown_ffi/models/enums.dart` | preserved |
| `package:html_to_markdown_ffi/visitor.dart` | preserved |
| `package:html_to_markdown_ffi/visitor_bridge.dart` | preserved |
| `package:html_to_markdown_ffi/native_library.dart` | preserved |
| `package:html_to_markdown_ffi/html_to_markdown_bindings.dart` | preserved |

## Exported symbols (from `html_to_markdown.dart`)

`convert`, `HtmlToMarkdownException`, `InvalidInputException`, `ConversionErrorException`,
`checkLastError`, `ConversionOptions`, `PreprocessingOptions`, `ConversionResult`,
`HtmlMetadata`, `LinkMetadata`, `ImageMetadata`, `ProcessingWarning`, `HeadingStyle`,
`ListIndentType`, `HighlightStyle`, `WhitespaceMode`, `NewlineStyle`, `CodeBlockStyle`,
`LinkStyle`, `OutputFormat`, `Visitor`, `NodeContext`, `VisitResult`, `NodeType` (exact set =
pre-migration barrel exports).

## Behavioral pins (unchanged semantics)

- `convert(html)` is **synchronous** and returns `ConversionResult` with non-empty `content`
  for valid HTML (e.g. `<h1>Title</h1>` → `# Title`).
- `convert(html, options:)` honors `ConversionOptions` (headings, bullets, escapes, wrap, …).
- `convert(html, visitor:)` routes element/text/link/image events through the `Visitor`
  vtable bridge (`VisitResult.skip/preserveHtml/custom/error` respected).
- Invalid input surfaces `InvalidInputException` (native error code 1); conversion failures
  surface `ConversionErrorException` (code 2); other codes surface `HtmlToMarkdownException`.
- Malformed HTML degrades gracefully (best-effort result), never crashes.
- `NativeLibrary.downloadIfNeeded()` returns `true` when a bundled binary or existing
  resolution path is present; loading order: env `HTML_TO_MARKDOWN_FFI_LIB_PATH` → bundled
  `native/<rid>` → resolver seam (adapter-bundled) → `~/.html_to_markdown_ffi/` cache →
  Cargo workspace → `DynamicLibrary.open(name)` → `process()` → `executable()`.
