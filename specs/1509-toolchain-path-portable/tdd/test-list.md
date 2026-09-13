# TDD test list — Spec 1509 toolchain-path-portable

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| T-1509-pin | test/utils/dart_toolchain_resolver_test.dart | spec-pin | no hardcoded /opt/flutter/bin/dart remains in tracked toolchain sources (bin/, lib/) | FR-002, SC-001 | RED |
| T-1509-c1 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths never emits /opt/flutter or machine-specific absolute paths, even with FLUTTER_ROOT and HOME set | FR-002, FR-005 | RED |
| T-1509-c2 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths includes $FLUTTER_ROOT/bin/dart iff FLUTTER_ROOT is set | FR-005 | RED |
| T-1509-c3 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths derives $HOME/flutter/bin/dart and $HOME/development/flutter/bin/dart from the injected home | FR-005, FR-006 | RED |
| T-1509-c4 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths expands ZURAFFA_TOOLCHAIN_HINTS entries into <dir>/dart and <dir>/bin/dart candidates in declared order | FR-002, FR-005 | RED |
| T-1509-c5 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths keeps the generic /usr/local/flutter/bin/dart hint and omits user-derived entries when home is empty | FR-005, FR-006 | RED |
| T-1509-r1 | test/utils/dart_toolchain_resolver_test.dart | unit | ZURAFFA_DART_BIN pin wins over every tier when the file exists | FR-004 | RED |
| T-1509-r2 | test/utils/dart_toolchain_resolver_test.dart | unit | ZURAFFA_DART_BIN pin pointing at a missing file is skipped and resolution falls through to PATH | FR-004 | RED |
| T-1509-r3 | test/utils/dart_toolchain_resolver_test.dart | unit | PATH which-dart hit is returned trimmed and first (PATH-first contract) | FR-001 | RED |
| T-1509-r4 | test/utils/dart_toolchain_resolver_test.dart | unit | dart next to which-flutter (symlink-resolved sibling) is found when PATH dart misses | FR-006 | RED |
| T-1509-r5 | test/utils/dart_toolchain_resolver_test.dart | unit | existing candidates resolve in candidate order when PATH probes miss | FR-005, FR-006 | RED |
| T-1509-r6 | test/utils/dart_toolchain_resolver_test.dart | unit | resolve returns null when every tier misses | FR-006 | RED |
| T-1509-mcp | test/utils/dart_toolchain_resolver_test.dart | acceptance | the documented environment recipe works: ZURAFFA_TOOLCHAIN_HINTS=/opt/flutter yields /opt/flutter/bin/dart without any code literal | acceptance 2, FR-002 | RED |

Red evidence (recorded before implementation, see verification.md):
`dart test test/utils/dart_toolchain_resolver_test.dart` fails to compile
(the resolver library does not exist) and T-1509-pin fails against
`bin/zuraffa_mcp_server.dart:1638` once the scan can run.
