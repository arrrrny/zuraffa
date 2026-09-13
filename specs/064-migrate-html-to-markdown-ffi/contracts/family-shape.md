# Contract: Federated Family Shape (`zfa package create-plugin` instance)

Pins the delivered monorepo at `~/Developer/html_to_markdown_ffi` (repo `arrrrny/html_to_markdown_ffi`).
**Verification**: in-repo structural test (`test/package_sdk/`) + family board.

## Family layout

Exactly five packages under `packages/`:

| Package | Kind | Depends on |
|---------|------|-----------|
| `html_to_markdown_ffi` | app-facing | `zuraffa: ^6.2.2` (hosted) only |
| `html_to_markdown_ffi_platform` | shared envelope core | app package |
| `html_to_markdown_ffi_android` | adapter | app + platform |
| `html_to_markdown_ffi_ios` | adapter | app + platform |
| `html_to_markdown_ffi_macos` | adapter | app + platform |

No package depends on an adapter. No package sets `publish_to: none`.

## Stamps (every pubspec)

- `description`: the migration description verbatim (family-wide, per generator behavior).
- `repository: https://github.com/arrrrny/html_to_markdown_ffi`, `issue_tracker: …/issues`.
- `topics` include `html-to-markdown` (or name-derived topic) and `zuraffa`.
- `version`: aligned family version at publish (1.2.0); in-family constraints hosted `^<version>`;
  sibling `dependency_overrides` exist only in dev and are stripped by pub on publish.

## Native artifact placement (FR-003)

| Adapter | Bundled artifacts |
|---------|-------------------|
| `_android` | `native/android/{armeabi-v7a,arm64-v8a,x86_64}/libhtml_to_markdown_ffi.so` |
| `_ios` | `native/ios/{ios-arm64,ios-sim-arm64,ios-sim-x64}.a` |
| `_macos` | `native/macos-{arm64,x64}/libhtml_to_markdown_ffi.dylib` |

## Port/service contract (scaffold shape, conversion semantics)

- `HtmlToMarkdownFfiPort` (app): `Future<bool> isSupported()`,
  `Future<HtmlToMarkdownFfiConversion> convert({required String html, ConversionOptions? options, Visitor? visitor})`,
  `HtmlToMarkdownFfiConversion convertSync({…})` (in-process adapters; foreign → typed
  `sync_unsupported`).
- `HtmlToMarkdownFfiService` (app): facade with typed `HtmlToMarkdownFfiException(code, message,
  {recoverable})`; `port_not_wired` placeholder when no adapter registered.
- `registerHtmlToMarkdownFfiDependencies(GetIt, {HtmlToMarkdownFfiPort? port})` on the app module;
  adapters expose `register<Platform>HtmlToMarkdownFfiDependencies(GetIt, {channel?, timeout?})`.
- Platform core: `PlatformHtmlToMarkdownFfiEnvelope` (transport seam + payload decode + typed
  error mapping + timeout), visitor vtable plumbing, `HtmNativeLibraryResolver`.
- Adapter default channels perform the **real FFI call** on their host platform (guarded by
  `Platform.isX`), else typed `channel_not_wired`; adapter tests always run over fake channels
  (offline-green on any host).

## Publish pipeline (zikzak scripts, verbatim)

1. Release notes as `## <version>` at top of root `CHANGELOG.md`.
2. `./scripts/prepare_for_publish.sh <version>` (branch `publish-<version>`, bumps versions +
   in-family constraints, propagates changelog, commits).
3. `git push origin publish-<version>`.
4. `bash scripts/publish.sh` — dry-run + publish, app package first, waits for pub.dev
   propagation between packages.
5. `bash scripts/push_to_master.sh -f` — merge to master, tag, push, delete branch.
