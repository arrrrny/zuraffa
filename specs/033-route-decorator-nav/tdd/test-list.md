# TDD Test List — @Route Decorator for Auto-Generated Navigation Configuration

**Spec**: `specs/033-route-decorator-nav/spec.md`
**Plan**: `specs/033-route-decorator-nav/plan.md`
**Tasks**: `specs/033-route-decorator-nav/tasks.md`

Every behavior maps to: spec FR/SC it proves, the driving test, and the
implementation that makes it green. Red evidence per behavior cluster lives
in `tdd/red/`.

## Behaviors

### B01 — Typed route param parsing (String/int/double/bool + fallbacks)

- **Spec**: FR-003, FR-004, US-2 scenarios 1–3, US-7 scenario 2
- **Test**: `test/routing/route_params_test.dart` — `parse helpers`
- **Implementation**: `lib/src/routing/route_params.dart` —
  `ZfaRouteParams.stringParam/intParam/doubleParam/boolParam`

### B02 — Current-params holder for controller init

- **Spec**: FR-003 ("available to the associated controller at
  initialization time")
- **Test**: `test/routing/route_params_test.dart` — `bind + currentAs`
- **Implementation**: `ZfaRouteParams.bind` / `ZfaRouteParams.currentAs<T>`

### B03 — Guard contract + navigation context

- **Spec**: FR-008, US-5 scenarios 1–2
- **Test**: `test/routing/route_guard_test.dart` — `canActivate contract`,
  `default redirectPath`, `ZfaRouteNavigationContext fields`
- **Implementation**: `lib/src/routing/route_guard.dart` —
  `ZuraffaRouteGuard`, `ZfaRouteNavigationContext`

### B04 — Scanner decodes @Route named args

- **Spec**: FR-001, US-1 scenario 1
- **Test**: `test/routing/route_annotation_scanner_test.dart` —
  `scans @Route with all named args`
- **Implementation**: `lib/src/routing/route_annotation_scanner.dart` +
  `route_annotation.dart`

### B05 — Scanner handles @Route.redirect / @Route.middleware forms

- **Spec**: FR-001 (redirect config), FR-005, FR-008, US-3, US-5
- **Test**: `test/routing/route_annotation_scanner_test.dart` —
  `standalone redirect form`, `standalone middleware form`
- **Implementation**: scanner named-constructor handling

### B06 — Non-View detection (strict error / lenient warning)

- **Spec**: FR-006, Edge Cases
- **Test**: `test/routing/route_annotation_scanner_test.dart` —
  `non-View strict error` / `non-View lenient warning`
- **Implementation**: scanner + `RouteScanIssue` severity

### B07 — View detection via name/extends + shell child-param detection

- **Spec**: US-4 (shell views render children)
- **Test**: `test/routing/route_annotation_scanner_test.dart` —
  `extends View counts as View`, `shell constructor child param`
- **Implementation**: scanner class-shape inspection

### B08 — Duplicate path validation

- **Spec**: FR-006, Edge Cases, SC-003
- **Test**: `test/routing/route_validator_test.dart` — `duplicate paths`
- **Implementation**: `lib/src/routing/route_validator.dart`

### B09 — Missing parent / parent cycle validation

- **Spec**: FR-006, FR-007, Edge Cases, SC-003
- **Test**: `test/routing/route_validator_test.dart` — `missing parent`,
  `parent cycle`
- **Implementation**: route_validator

### B10 — Unsupported param type + unknown path param validation

- **Spec**: FR-006, Edge Cases, SC-003/SC-004
- **Test**: `test/routing/route_validator_test.dart` —
  `unsupported param type`, `param not in path`
- **Implementation**: route_validator

### B11 — Redirect target validation

- **Spec**: FR-005, FR-006, Edge Cases, SC-003
- **Test**: `test/routing/route_validator_test.dart` — `undefined redirect target`
- **Implementation**: route_validator

### B12 — Controller type-mismatch validation (SC-004)

- **Spec**: SC-004, FR-006
- **Test**: `test/routing/route_validator_test.dart` — `controller type mismatch`
- **Implementation**: route_validator sibling-controller scan

### B13 — Generated GoRoute/RouteParams source shape

- **Spec**: FR-002, FR-003, US-1 scenarios 1/2/4, US-7
- **Test**: `test/routing/route_config_generator_test.dart` —
  `flat route rendering`, `typed params class rendering`, `parses back`
- **Implementation**: `lib/src/routing/route_config_generator.dart`

### B14 — ShellRoute nesting + relative child paths

- **Spec**: FR-007, US-4 scenarios 1–2
- **Test**: `test/routing/route_config_generator_test.dart` —
  `shell nesting`, `relative child path`, `child param only when declared`
- **Implementation**: route_config_generator

### B15 — Redirect + guard rendering

- **Spec**: FR-005, FR-008, US-3, US-5
- **Test**: `test/routing/route_config_generator_test.dart` —
  `redirect rule rendering`, `guard wrapping`
- **Implementation**: route_config_generator

### B16 — Deep-link side files

- **Spec**: US-6 scenarios 1–2
- **Test**: `test/routing/route_config_generator_test.dart` —
  `deep link files written`, `no deep links → no files`
- **Implementation**: route_config_generator

### B17 — End-to-end compile + idempotency

- **Spec**: FR-002, US-1 scenario 3
- **Test**: `test/routing/route_annotation_compiler_test.dart` —
  `e2e writes router file`, `idempotent output`
- **Implementation**: `lib/src/routing/route_annotation_compiler.dart`

### B18 — 100 Views < 2s (SC-002)

- **Spec**: SC-002
- **Test**: `test/routing/route_annotation_compiler_test.dart` —
  `100 views compile under 2 seconds`
- **Implementation**: parse-only scanner + deterministic emitter

### B19 — Empty/no-annotation behavior

- **Spec**: Edge Cases ("valid (empty) route configuration rather than
  failing")
- **Test**: `test/routing/route_annotation_compiler_test.dart` —
  `no annotations + stale router → empty config`, `no annotations + no
  router → no file`
- **Implementation**: route_annotation_compiler

### B20 — Compilation errors aggregate with locations

- **Spec**: FR-006, SC-003
- **Test**: `test/routing/route_annotation_compiler_test.dart` —
  `all errors reported with file:line`
- **Implementation**: `RouteCompilationException` aggregating every error

### B21 — `zfa build` pre-step wiring

- **Spec**: FR-002 ("during zfa build"), SC-001
- **Test**: `test/commands/build_route_step_test.dart` —
  `success writes artifacts`, `validation failure returns 1`,
  `zero annotations no-op`
- **Implementation**: `BuildCommand.compileRouteAnnotations` + `run()` hook
