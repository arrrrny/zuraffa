# Red Evidence — 033 @Route decorator (all behaviors)

**Feature**: `specs/033-route-decorator-nav/`
**Behaviors**: A1–A4, U1–U36 (see `tdd/test-list.md`)
**Commit**: `b3926c93` (tests authored on top, before any lib implementation)

## First-run output (before implementation)

All six new test files were authored before any library change and run
against the unmodified master code:

```
$ dart test test/dda/ast_scanner_literal_test.dart test/dda/ast_scanner_ctor_test.dart \
    test/dda/ast_scanner_fast_path_test.dart test/dda/route_validator_test.dart \
    test/dda/route_build_stage_test.dart test/dda/route_perf_test.dart
```

### Assertion-level red (scanner literal parsing — U1–U5)

```
00:08 +2 -5: Some tests failed.

Failing tests:
  test/dda/ast_scanner_literal_test.dart: string literal named arg scans to typed String without quotes
  test/dda/ast_scanner_literal_test.dart: bool literal named arg scans to typed bool
  test/dda/ast_scanner_literal_test.dart: int and double literal named args scan to typed numbers
  test/dda/ast_scanner_literal_test.dart: null literal named arg scans to null
  test/dda/ast_scanner_literal_test.dart: list literal named arg scans to raw element sources
```

Sample failure (U2, bool literal — the exact defect that breaks
`RouteDDAPlugin.onApply` today):

```
00:05 +0 -1: bool literal named arg scans to typed bool [E]
  Expected: <true>
   Actual: 'true'
```

(U1 string literal: `Expected: '/home'  Actual: '/home'` — value arrives with
quotes; U4 list literal: `Expected: Instance of 'List'  Actual:
'[AuthGuard, LogGuard]'` — arrives as a raw String.)

### Compile-error red (new APIs — repo-accepted red form)

```
  test/dda/ast_scanner_ctor_test.dart: The getter 'constructorName' isn't defined for the type 'DecoratorAST'.
  test/dda/ast_scanner_fast_path_test.dart: No named parameter with the name 'resolve'.
  test/dda/route_validator_test.dart: 'RouteValidator' isn't a type.
  test/dda/route_validator_test.dart: 'RouteEntryInfo' isn't a type.
  test/dda/route_validator_test.dart: Undefined name 'RouteValidationErrorCode'.
  test/dda/route_validator_test.dart: Method not found: 'NonViewTargetInfo'.
  test/dda/route_build_stage_test.dart: Method not found: 'RouteBuildStage'.
  test/dda/route_perf_test.dart: Method not found: 'RouteBuildStage'.
```

**Status**: RED ✓ — every behavior's test existed and failed before its
implementation. Compile-error red is accepted per the constitution's
Test-First gate (same convention as spec 037's `tdd/red/01-sdl-printer.md`).

## Scanner probe (pre-existing defect, recorded before writing tests)

```
$ dart run scanner_probe.dart   # temp project: @ZfaRoute(path: '/home', deepLinkAware: true)
FOUND decorator=ZfaRoute target=HomeView
  namedArgs={path: '/home', deepLinkAware: true}   ← raw source STRINGS
TOTAL: 1
```

`_parseAnnotation` stored `arg.argumentExpression.toSource()` for every named
argument, so `DecoratorAST.get<bool>('deepLinkAware')` threw
`DecoratorParseError` on real scanner output and `RouteDDAPlugin.onApply`
could never work end-to-end.
