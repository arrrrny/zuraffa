**Template Version**: `zuraffa-1.0`

# Tasks: 1509-toolchain-path-portable

MVP-first: the smallest behavior-complete increment is T001–T010 (the
resolver exists, is tested red→green, the literal is gone, the MCP server
delegates). T011–T014 are non-behavioural hardening and traceability.

## MVP (behaviors first — every one has a failing test before implementation)

- [x] **T001** [P] [US1] Write the spec-pin test: the tracked-source scan
      asserting `/opt/flutter/bin/dart` is absent from all `bin/**/*.dart`,
      `lib/**/*.dart` files (suite
      `test/utils/dart_toolchain_resolver_test.dart`, test
      `spec-pin: no hardcoded /opt/flutter/bin/dart in tracked toolchain sources`).
      RED evidence: fails against `bin/zuraffa_mcp_server.dart:1638`.
      Traces: FR-002, SC-001.
- [x] **T002** [P] [US1] Write resolver unit tests for
      `candidatePaths` purity: no `/opt/flutter` (or any
      machine-specific) entry under FLUTTER_ROOT/HOME-bearing
      environments (FR-005); FLUTTER_ROOT candidate present iff env set;
      HOME-derived candidates; `ZURAFFA_TOOLCHAIN_HINTS` expansion to
      `<dir>/dart` + `<dir>/bin/dart`; empty-env minimal list.
      RED evidence: library does not exist (compile failure).
      Traces: FR-002, FR-005, acceptance 5.
- [x] **T003** [P] [US1] Write resolver unit tests for the resolve()
      tiers over injected probes: `ZURAFFA_DART_BIN` pin wins when the
      file exists and is skipped when it does not (FR-004/acceptance 4);
      PATH `which dart` hit returned trimmed (FR-001); flutter-adjacent
      sibling dart via symlink-resolved `which flutter` (FR-006);
      candidate-order filesystem fallback (FR-005); null when nothing
      found (FR-006). RED evidence: library does not exist.
      Traces: FR-001, FR-004, FR-006.
- [x] **T004** [US1] Implement `lib/src/utils/dart_toolchain_resolver.dart`:
      pure `candidatePaths`, injectable `DartToolchainResolver.resolve()`,
      platform-correct real `which`/`where` adapter, dartdoc documenting
      the environment contract (`ZURAFFA_DART_BIN`,
      `ZURAFFA_TOOLCHAIN_HINTS`, `FLUTTER_ROOT`) and the documented-env
      recipe (`ZURAFFA_TOOLCHAIN_HINTS=/opt/flutter`). Turns T001–T003
      green. Traces: FR-001..FR-006.
- [x] **T005** [US1] Rewrite `ZuraffaMcpServer._findDartExecutable()` to
      delegate to a `DartToolchainResolver` field, preserving the
      `_dartProbeDone`/`_cachedDartPath` cache contract and the
      `Future<String?>` signature. Removes the banned literal — T001
      flips green. Traces: FR-003, FR-006.
- [x] **T006** [US1] Run `dart test test/utils/dart_toolchain_resolver_test.dart`
      → fully green; record in tdd/test-list.md. Traces: SC-003.

## Post-MVP (non-behavioural)

- [x] **T007** [P] Run `dart format lib test bin` (repo contract) —
      no formatting deltas expected for touched files. Traces: SC-005.
- [x] **T008** Run `dart analyze .` → 0 errors / 0 warnings / no new
      infos vs. the 112-info baseline. Traces: SC-002.
- [x] **T009** Run `dart test --preset=all
      test/plugins/tdd/make_command_test.dart` → no new failures vs. the
      recorded 5-failure environment baseline; clean dart-test kernel
      cache before and after. Traces: SC-004.
- [ ] **T010** Run the SC-001 grep
      (`grep -r '/opt/flutter/bin/dart' --include='*.dart' --include='*.sh' --include='*.yaml' .`)
      → zero matches; record in tdd/verification.md. Traces: SC-001,
      SC-006.
- [ ] **T011** [P] Record red→green evidence and toolchain used in
      `specs/1509-toolchain-path-portable/tdd/verification.md`
      (test-first order, baseline comparison, environment description —
      the issue #1509 environment class reproduces here). Traces: SC-006.
- [ ] **T012** Mirror the test-list at the repo-root `tdd/test-list.md`
      (current-feature convention) with final states. Traces: repo
      convention.
- [ ] **T013** Stage-level commits + push per the report protocol;
      final PR body with verification summary, `Closes #1509`. Traces:
      report protocol.
- [ ] **T014** Disk housekeeping: remove dart-test kernel caches
      (`.dart_tool/test/`, `$TMPDIR/dart_test.kernel.*`) after test
      phases; `df -h` check.

## Parallelization

T001, T002, T003 are independent test-authoring tasks ([P]) and precede
T004 (implementation) — test-first by construction. T005 depends on
T004. T007–T012 depend on T004+T005.
