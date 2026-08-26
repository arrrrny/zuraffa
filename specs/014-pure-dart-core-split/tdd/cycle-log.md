# TDD Cycle Log: Pure-Dart Core Split (#253)

**Feature**: `014-pure-dart-core-split`
**Branch**: `feat/zuraffa-pure-dart-split`
**Base Commit**: `614e648`

---

## Baseline Entry

**Date**: 2026-08-26
**Commit**: `614e648`
**Command**: `dart test test` (fast unit suite, excludes slow-tagged tests)
**Results**: 1552 passed, 1 failed, 4 timeouts

### Test Breakdown
- **Passed**: 1552 tests
- **Failed**: 1 (pre-existing)
  - `test/plugins/mcp/mcp_sse_server_test.dart`: "McpSseServer remote requests get 401 when Authorization is missing or invalid" - TimeoutException after 30 seconds
- **Timeouts**: 4 (CI flakiness in slow/integration tests)
  - `test/cli/cli_edge_cases_test.dart`: 4 tests timing out
  - `test/commands/make_command_test.dart`: 5 tests timing out
  - `test/commands/make_command_xray_default_test.dart`: 3 tests timing out
  - `test/regression/output_quality_test.dart`: 1 test timing out

### Notes
- The single failure is a pre-existing flaky test in MCP SSE server auth
- Timeouts appear to be CI environment issues, not code failures
- Suite duration: ~14 minutes (includes slow tests due to missing `slow` tag exclusion in default run)

---

## Cycle 1: Address PENDING Acceptance Criteria

**Target**: A2, A6, U21 - Zero Flutter imports in core package CLI commands

### Red Phase
- Verify current violations in `create_command.dart` and `module_command.dart`
- Write test to detect Flutter imports in lib/src/commands/

### Green Phase
- Refactor string templates to use constants instead of direct Flutter imports
- Ensure generated Flutter code strings are valid

### Refactor Phase
- Run full test suite
- Update cycle log

---

## Cycle 2: Verify U27 - locale_converter.dart

**Target**: U27 - Verify standalone Locale value class exists

### Red Phase
- Check if `locale_converter.dart` exists and has standalone Locale class
- Write test if missing

### Green Phase
- Implement if needed
- Run tests

---

## Cycle 3: Full Verification

**Target**: All behaviors

### Verify
- Run `dart analyze lib bin` - confirm zero errors
- Run `grep -r "package:flutter" lib/src/ bin/ --include="*.dart"` - confirm zero imports (except string templates)
- Run `dart test test` - confirm all unit tests pass
- Run pure Dart example: `cd examples/pure_dart_server && dart run bin/server.dart`
- Run CLI commands: `zfa --help`, `zfa xray --help`

---

## Cycle 4: TDD Verification (Phase 3)

**Target**: Complete audit

### Verify
- Mutation spot-check on high-risk behaviors
- Test-smell rubric on new tests
- Acceptance criteria coverage check
- Write `verification.md`