# TDD test list — Spec 1509 toolchain-path-portable

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| T-1509-pin | test/utils/dart_toolchain_pin_test.dart | spec-pin | no hardcoded /opt/flutter dart path remains in tracked toolchain sources (bin/, lib/, scripts, yaml) | FR-002, SC-001 | GREEN |
| T-1509-c1 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths emits no constant machine-specific paths when the env declares none | FR-002, FR-005 | GREEN |
| T-1509-c2 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths includes $FLUTTER_ROOT/bin/dart iff FLUTTER_ROOT is set | FR-005 | GREEN |
| T-1509-c3 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths derives $HOME/flutter/bin/dart and $HOME/development/flutter/bin/dart from the injected home | FR-005, FR-006 | GREEN |
| T-1509-c4 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths expands ZURAFFA_TOOLCHAIN_HINTS entries into <dir>/dart and <dir>/bin/dart candidates in declared order | FR-002, FR-005 | GREEN |
| T-1509-c5 | test/utils/dart_toolchain_resolver_test.dart | unit | candidatePaths keeps the generic /usr/local/flutter/bin/dart hint and omits user-derived entries when home is empty | FR-005, FR-006 | GREEN |
| T-1509-r1 | test/utils/dart_toolchain_resolver_test.dart | unit | ZURAFFA_DART_BIN pin wins over every tier when the file exists | FR-004 | GREEN |
| T-1509-r2 | test/utils/dart_toolchain_resolver_test.dart | unit | ZURAFFA_DART_BIN pin pointing at a missing file is skipped and resolution falls through to PATH | FR-004 | GREEN |
| T-1509-r3 | test/utils/dart_toolchain_resolver_test.dart | unit | PATH which-dart hit is returned trimmed and first (PATH-first contract) | FR-001 | GREEN |
| T-1509-r4 | test/utils/dart_toolchain_resolver_test.dart | unit | dart next to which-flutter (symlink-resolved sibling) is found when PATH dart misses | FR-006 | GREEN |
| T-1509-r5 | test/utils/dart_toolchain_resolver_test.dart | unit | existing candidates resolve in candidate order when PATH probes miss | FR-005, FR-006 | GREEN |
| T-1509-r6 | test/utils/dart_toolchain_resolver_test.dart | unit | resolve returns null when every tier misses | FR-006 | GREEN |
| T-1509-mcp | test/utils/dart_toolchain_resolver_test.dart | unit | a flutter install without a sibling dart keeps the search going (tier-2 exists-check guard) | FR-006 | GREEN |
| T-1509-acc2 | test/utils/dart_toolchain_resolver_test.dart | acceptance | the documented environment recipe works: ZURAFFA_TOOLCHAIN_HINTS=/opt/flutter yields the old last-resort candidate without any code literal | acceptance 2, FR-002 | GREEN |

Red evidence: recorded before implementation — see
specs/1509-toolchain-path-portable/tdd/verification.md
(pin test failed against bin/zuraffa_mcp_server.dart:1638; resolver
suite failed to compile because the library did not exist yet).
