---
feature: 033-route-decorator-nav
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: b3926c93
updated_at: b3926c93
suite_baseline: green
---

# Test List: @Route Decorator for Auto-Generated Navigation Configuration

## Outer loop: acceptance behaviors

One per success criterion in `spec.md`. Each stays red until the feature works
end to end through its real entry point (annotate a View in a temp project →
run the route build stage / `zfa build` → inspect the generated
`lib/src/routing/zfa_router.g.dart`).

| id  | behavior                                                                                              | traces  | kind    | state   | test                                                                |
| --- | ----------------------------------------------------------------------------------------------------- | ------- | ------- | ------- | ------------------------------------------------------------------- |
| A1  | A single `@Route(path: '/products')` on a View, run through the build stage, yields a complete GoRouter config file with zero manual route code (US1 scenarios 1+4: one annotation → one route; many Views → one file) | SC-001, FR-002 | example | DONE | `test/dda/route_build_stage_test.dart::stage e2e`                   |
| A2  | The route stage compiles a project with 100 annotated Views into one config in under 2 seconds       | SC-002  | example | DONE | `test/dda/route_perf_test.dart::100 views under 2s`                 |
| A3  | Duplicate paths, missing parents, non-View targets, unsupported param types, and dangling redirect targets all fail the build with actionable errors before any file is written | SC-003, FR-006 | example | DONE | `test/dda/route_validator_test.dart` + `route_build_stage_test.dart::validation fails stage` |
| A4  | Generated `RouteParams` classes are typed (`final int id`) and parse `GoRouterState` values at construction — a wrong param type is a build error, not a runtime crash | SC-004, FR-003 | example | DONE | `test/dda/route_build_stage_test.dart::typed path and query params` |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them.

### `lib/src/dda/compiler/ast_scanner.dart` (+ `models/decorator_ast.dart`)

| id  | behavior                                                                                          | traces        | kind    | state   | test                                                        |
| --- | ------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | ----------------------------------------------------------- |
| U1  | A string literal named arg (`path: '/products'`) scans to the typed String `/products` (quotes stripped) | FR-001, FR-002 | example | DONE | `test/dda/ast_scanner_literal_test.dart::string literal`    |
| U2  | A bool literal named arg (`deepLinkAware: true`) scans to the typed bool `true`                   | FR-001        | example | DONE | `test/dda/ast_scanner_literal_test.dart::bool literal`      |
| U3  | Int and double literal named args scan to `int` / `double` values                                  | FR-001        | example | DONE | `test/dda/ast_scanner_literal_test.dart::numeric literals`  |
| U4  | A list literal named arg (`middleware: [AuthGuard]`) scans to `['AuthGuard']` (raw element sources) | FR-008        | example | DONE | `test/dda/ast_scanner_literal_test.dart::list literal`      |
| U5  | A map literal named arg (`queryParameters: {'q': 'String'}`) scans to a parseable raw source string | FR-004        | example | DONE | `test/dda/ast_scanner_literal_test.dart::map literal`       |
| U6  | `@Route.redirect(from: '/old', to: '/new')` reports name `Route` + constructorName `redirect`      | FR-005        | example | DONE | `test/dda/ast_scanner_literal_test.dart::named constructor` |
| U7  | `@ZfaRoute(...)` reports decorator name `ZfaRoute` (both spellings accepted downstream)            | FR-001        | example | DONE | `test/dda/ast_scanner_literal_test.dart::zfa route spelling`|
| U8  | The syntactic fast path (`resolve: false`) scans a temp project with no pubspec.yaml                | SC-002        | example | DONE | `test/dda/ast_scanner_fast_path_test.dart::no pubspec`      |
| U9  | `.g.dart` / `.freezed.dart` files stay excluded on both scan paths                                 | FR-002        | example | DONE | `test/dda/ast_scanner_fast_path_test.dart::excludes generated` |

### `lib/src/dda/plugins/route/route_build_stage.dart` (stage e2e — temp projects)

| id  | behavior                                                                                          | traces        | kind    | state   | test                                                            |
| --- | ------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | --------------------------------------------------------------- |
| U10 | Stage run over one annotated View writes `lib/src/routing/zfa_router.g.dart` with route, name, view class, and view import | SC-001, FR-002 | example | DONE | `test/dda/route_build_stage_test.dart::writes router file`     |
| U11 | Two runs over unchanged sources produce byte-identical output (idempotency)                        | US1 scenario 3 | example | DONE | `test/dda/route_build_stage_test.dart::idempotent`             |
| U12 | `@Route` and `@ZfaRoute` spellings produce identical routes                                        | FR-001        | example | DONE | `test/dda/route_build_stage_test.dart::both spellings`         |
| U13 | `@ZfaRoute.redirect(from:, to:)` emits the redirect callback and no GoRoute for the annotation class | FR-005        | example | DONE | `test/dda/route_build_stage_test.dart::redirect e2e`           |
| U14 | `isShell: true` + `parent: 'dashboard'` nests child routes in a ShellRoute whose builder renders the shell View around `child` | FR-007 | example | DONE | `test/dda/route_build_stage_test.dart::shell nesting`          |
| U15 | `parent: '/dashboard'` (path form) nests identically to the name form                              | FR-007        | example | DONE | `test/dda/route_build_stage_test.dart::parent by path`         |
| U16 | `middleware: [AuthGuard]` emits the async guard redirect block invoking `canActivate` / `onRejected` before activation | FR-008 | example | DONE | `test/dda/route_build_stage_test.dart::guard e2e`              |
| U17 | `pathParameters: {'id': 'int'}` yields `final int id` + `int.parse(...)` in the RouteParams factory | FR-003, SC-004 | example | DONE | `test/dda/route_build_stage_test.dart::typed path param`       |
| U18 | Query params declared via `queryParameters` yield typed fields with safe defaults when absent       | FR-004        | example | DONE | `test/dda/route_build_stage_test.dart::typed query params`     |
| U19 | Mixed path + query params on one route land in one params class with both typed fields             | FR-003, FR-004 | example | DONE | `test/dda/route_build_stage_test.dart::mixed params`           |
| U20 | `deepLinkAware: true` routes carry the deep-link marker comment; others carry none                 | FR-001 (deepLinkAware) | example | DONE | `test/dda/route_build_stage_test.dart::deep link marker`       |
| U21 | No annotations + no previous file → success, nothing written                                       | Edge case     | example | DONE | `test/dda/route_build_stage_test.dart::empty project skip`      |
| U22 | No annotations + stale router file → regenerated as a valid empty config with no stale routes      | Edge case     | example | DONE | `test/dda/route_build_stage_test.dart::stale file emptied`     |
| U23 | Routes removed between runs disappear from the regenerated file                                    | Edge case     | example | DONE | `test/dda/route_build_stage_test.dart::removed routes pruned`   |
| U24 | Validation errors abort the stage before any file is written                                       | SC-003        | example | DONE | `test/dda/route_build_stage_test.dart::validation fails stage`  |

### `lib/src/dda/plugins/route/route_validator.dart`

| id  | behavior                                                                                          | traces        | kind    | state   | test                                                            |
| --- | ------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | --------------------------------------------------------------- |
| U25 | Two routes with the same path produce an error naming BOTH classes and the path                    | FR-006, SC-003 | example | DONE | `test/dda/route_validator_test.dart::duplicate path`            |
| U26 | Two routes with the same explicit name produce an error                                           | FR-006        | example | DONE | `test/dda/route_validator_test.dart::duplicate name`            |
| U27 | A `parent` referencing an unknown route name/path errors naming parent and child class            | FR-006, SC-003 | example | DONE | `test/dda/route_validator_test.dart::missing parent`           |
| U28 | A `parent` referencing a non-shell route errors                                                   | FR-006        | example | DONE | `test/dda/route_validator_test.dart::parent not shell`         |
| U29 | `@Route` on a class not named `*View`/`*Shell`/`*Page`/`*Screen` errors with the class + location  | FR-006, SC-003 | example | DONE | `test/dda/route_validator_test.dart::non view target`          |
| U30 | A param type outside `{String, int, double, bool}` errors naming the type and the allowed set     | FR-006, SC-003 | example | DONE | `test/dda/route_validator_test.dart::unsupported param type`   |
| U31 | A redirect whose `to` target matches no route path errors as an undefined redirect target         | FR-006, SC-003 | example | DONE | `test/dda/route_validator_test.dart::dangling redirect target` |
| U32 | Routes present without `go_router` in pubspec deps error with an install hint                     | FR-006 (precondition) | example | DONE | `test/dda/route_validator_test.dart::go_router missing` |
| U33 | A clean project validates with zero errors                                                        | FR-006        | example | DONE | `test/dda/route_validator_test.dart::clean project`            |

### `lib/src/commands/build_command.dart` (CLI wiring)

| id  | behavior                                                                                          | traces        | kind    | state   | test                                                            |
| --- | ------------------------------------------------------------------------------------------------- | ------------- | ------- | ------- | --------------------------------------------------------------- |
| U34 | `zfa build --dda-routes-only` on an annotated temp project produces the same router file as the direct stage run | FR-002 | example | DONE | `test/dda/route_build_stage_test.dart::build command wiring`    |
| U35 | `zfa build` with `--no-dda-routes` skips the route stage entirely                                   | FR-002 (opt-out) | example | DONE | `test/dda/route_build_stage_test.dart::no dda routes flag`  |
| U36 | DDA validation errors surface through the build command and fail it                                 | SC-003        | example | DONE | `test/dda/route_build_stage_test.dart::build command fails on dda errors` |

## Invariants and edge cases still to place

All placed (see U21–U24, U25–U33). No unplaced behaviors remain.

## Out of scope

- Runtime GoRouter navigation behavior — the target package's concern, not the generator's.
- Platform deep-link manifest files (`apple-app-site-association`, `assetlinks.json`) — owned by the imperative deep-link routes plugin (`lib/src/plugins/route/builders/deep_link_routes_builder.dart`); the DDA path emits marker comments only.
- Merging DDA routes into the `getAllRoutes()` aggregator / `app_router.dart` from the app_shell plugin — separate system, can coexist.
- DI-resolved guard construction — v1 instantiates guards directly (plan §Spec-reading decisions 7).
- Activating the dormant Auth/Cache/Retry/TrackEvent DDA generators — separate specs.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time, so this
file is readable on its own:

- Single test: `dart test test/<path>.dart -P "<name>"`
- Full suite (feature scope): `dart test test/dda/`
- Static analysis (feature scope): `dart analyze lib/src/dda/ lib/src/commands/build_command.dart test/dda/`
- Static analysis (full repo): `dart analyze`
