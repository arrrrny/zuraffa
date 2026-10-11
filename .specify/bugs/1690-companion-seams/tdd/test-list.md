# Test List: 1690-companion-seams

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the documented `path:` install (relative path deps, real `dart pub get`, relative rootUris, CWD at the project root) completes `zfa graphql generate` through the companion — gate passes, relative rootUri resolves, generation runs | issue #1690 §1 repro; constraint 1 | GREEN |
| A2 | the compiled companion artifact lands in the CONSUMING project's `.dart_tool/zfa_cli_bin/` and the delegation writes nothing into the companion package | issue #1690 §2; constraints 2+4 | GREEN |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U7a | `companionEntry` anchors a RELATIVE rootUri at the package_config directory with CWD at the project root | §1; constraint 1 | GREEN |
| U7b | `companionEntry` resolves a relative rootUri when CWD is unrelated to the project (no `Directory.current` reliance) | §1 | GREEN |
| U7c | an absolute `file://` rootUri keeps resolving (no regression) | §1; constraint 3 | GREEN |
| U7d | a resolvable companion whose bin entry is missing still returns null | §1 guard | GREEN |
| U12a | a `packagesFile` compile carries `--packages=<project config>` in the compiler argv | §2; constraint 2 | GREEN |
| U12b | the artifact lands in `<project>/.dart_tool/zfa_cli_bin/`, never in the companion source root | §2; constraints 2+4 | GREEN |
| U12c | two projects compiling the same candidate get DIFFERENT slots | §2; constraint 2 | GREEN |
| U12d | a rewritten (newer) project package config invalidates the cached artifact | §2 | GREEN |
| U12e | no `packagesFile` keeps the legacy contract byte-for-byte (no `--packages`, source-root cache) | §2 regression guard | GREEN |

Test files:

- `test/plugins/plugin_gate/plugin_gate_test.dart` (U7 group)
- `test/cli/zfa_executable_test.dart` (U12 group)
- `test/graphql/graphql_generate_delegation_e2e_test.dart` (A1 + A2)
