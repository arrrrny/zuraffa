# TDD Test List — Spec 064 (`html_to_markdown_ffi` migration, issue #687)

Red protocol: B1/B3 red via the missing in-repo proof file
(`test/package_sdk/plugin_html_to_markdown_ffi_instance_test.dart` — the instance contract is
what the file pins); B2 red via the missing ported suite + service contract in the app package;
B4 red via the missing host FFI proof; B5/B6 are procedure behaviors whose red is the
un-migrated repo / unpublished family. The generator (`zfa package create-plugin`) is frozen —
failures against it are roadblocks to report, not fix prompts.

## Behaviors

| # | Behavior | Trace | Test file / evidence |
|---|--------|--------|----------------------|
| B1 | Instance family contract: the delivered `~/Developer/html_to_markdown_ffi` family has exactly five packages under `packages/`; every pubspec: migration description, `https://github.com/arrrrny/html_to_markdown_ffi` (+ `/issues`), zuraffa topic, `publish_to` absent; dependency graph app→zuraffa only, core→app, adapters→app+core, nobody→adapter; native artifact placement per contracts/family-shape.md (android 3×.so, ios 3×.a, macos 2×.dylib, sizes matching pre-migration `native/`) | FR-001 / FR-002 / FR-003 / SC-005 | test/package_sdk/plugin_html_to_markdown_ffi_instance_test.dart |
| B2 | Public API preservation + service contract: the app package still exports the pinned surface from `lib/html_to_markdown.dart` and the loose `lib/*.dart` paths (contracts/public-api.md); the ported legacy suite (assertions unchanged) passes; the scaffold service (`HtmlToMarkdownFfiService`) drives conversion through an injected fake port with typed failures (`port_not_wired`, taxonomy) | FR-005 / FR-006 | app package `test/` (ported files + `html_to_markdown_ffi_service_test.dart`) |
| B3 | Generated zuraffa domain: app package has `lib/src/domain/entities/<snake>/<snake>.dart` (+ zorphy-generated siblings) produced by `zfa entity create`, and generated repository/datasource/usecase artifacts (`zfa make`); the service delegates conversion through the generated use case → repository → datasource seam (proven at source + behavior level with fakes) | FR-001 / FR-002 / SC-005 | test/package_sdk/plugin_html_to_markdown_ffi_instance_test.dart |
| B4 | Host FFI proof through the stack (macOS host, guarded): `convert()` through the service on ≥ 20 representative HTML inputs (headings, tables, lists, links, images, edge cases — legacy corpus) returns non-empty well-formed markdown; visitor vtable pin (`VisitResult.skip/custom` respected); native error pins (code 1 → `InvalidInputException`, code 2 → `ConversionErrorException`); loading order pins (env var → bundled → resolver seam) | FR-003 / FR-004 / SC-002 | test/package_sdk/plugin_html_to_markdown_ffi_instance_test.dart (host tier) + ported legacy suite |
| B5 | Family board: per package `dart pub get` + `dart analyze --no-fatal-warnings` + `dart test` + `dart pub publish --dry-run`, all exit 0, in the delivered repo (quickstart §4) | SC-001 / SC-003 / FR-008 | procedure — evidence in tdd/cycle-log.md |
| B6 | Delivery + publish: family committed on master lineage; `prepare_for_publish.sh <ver>` → `publish.sh` → five pub.dev releases (`html_to_markdown_ffi`, `_platform`, `_android`, `_ios`, `_macos`) → `push_to_master.sh -f` tags master; committed manifests carry no local paths | FR-008 / SC-004 | procedure — evidence in tdd/cycle-log.md |

## Notes

- B2's legacy-suite tier executes real FFI on the macOS host via the macos adapter
  (dev-only sibling override); on non-macOS hosts those tests are skipped exactly as the
  pre-migration suite skipped them (status quo parity, research.md D7).
- B5/B6 are honest procedure behaviors: their red is "not yet true of the world", their green
  is command output recorded in the cycle log — no synthetic test double stands in for pub.dev.
