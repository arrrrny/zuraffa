# Test List: 1444-setup-zuraffa-app

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A2 | no app shell is generated (pure Dart projects have no Flutter widgets) | AC-2 | PENDING |
| A5 | the existing `MaterialApp.router` behavior is preserved (backward compatible) | AC-5 | PENDING |
| A7 | no errors are reported (the imports resolve correctly) | AC-7 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |
| A1 | `lib/main.dart` contains `runApp(ZuraffaApp(...))` with a title, theme, `debugShowCheckedModeBanner: false`, and a `GlobalKey<NavigatorState>` | none | AC-1 | PENDING |
| A3 | the app compiles and launches without errors | none | AC-3 | PENDING |
| A4 | `my_app.dart` is regenerated with `ZuraffaApp` as the root widget | none | AC-4 | PENDING |
| A6 | it passes `title` (the app name), `debugShowCheckedModeBanner: false`, a `GlobalKey<NavigatorState>` instance, and a theme parameter | none | AC-6 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `zfa setup` for Flutter projects MUST generate `lib/main.dart` using `ZuraffaApp` as the root widget instead of `MaterialApp.router` | FR-001 | PENDING |
| U2 | The generated `main.dart` MUST import `package:zuraffa_ui/zuraffa_ui.dart` (or the appropriate barrel) to resolve the `ZuraffaApp` symbol | FR-002 | PENDING |
| U3 | The generated `ZuraffaApp` MUST receive `title` (from the app name), `debugShowCheckedModeBanner: false`, a `GlobalKey<NavigatorState>`, and a theme | FR-003 | PENDING |
| U4 | The generated `my_app.dart` MUST be removed or replaced — `ZuraffaApp` serves as the shell, so the intermediate `MyApp` widget wrapping `MaterialApp.router` is no longer needed when using `ZuraffaApp` | FR-004 | PENDING |
| U5 | `zfa app shell --zuraffa-app` MUST continue to work for existing projects (backward compatibility) | FR-005 | PENDING |
| U6 | `zfa app shell` without `--zuraffa-app` MUST preserve the current `MaterialApp.router` behavior for backward compatibility | FR-006 | PENDING |
| U7 | `zfa setup` for pure Dart projects MUST NOT generate any Flutter app shell | FR-007 | PENDING |
| U8 | The generated `main.dart` MUST compile cleanly with `dart analyze` (no unused imports, no missing symbols) | FR-008 | PENDING |
| U9 | The `zuraffa_ui` dependency MUST be present in `pubspec.yaml` before the app shell is generated; if missing, `zfa setup` or `zfa app shell` MUST refuse with a clear error message | FR-009 | PENDING |
| U10 | The `GoRouter` tree (generated routing) MUST remain functional beneath `ZuraffaApp` via `Router.withConfig` (the existing `--zuraffa-app` integration pattern) | FR-010 | PENDING |

## Contract loop: contract behaviors

One per declared entity method, controller method and usecase in `spec.md` Layer Contracts (issue #1007). A contract test proves the implementation satisfies the DECLARED contract — a failing contract test is BLOCKED (never RED) and blocks the cycle from proceeding to GREEN.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | AppShellBuilder.buildMain(appName, coreImport, zuraffaApp) -> String (controller method contract) | AppShellBuilder.buildMain | PENDING |
| contract:A2 | AppShellBuilder.buildMyApp(zuraffaApp) -> String (controller method contract) | AppShellBuilder.buildMyApp | PENDING |

## Layer contracts

### Presentation

- `AppShellBuilder`: `buildMain(appName, coreImport, zuraffaApp) -> String`
- `AppShellBuilder`: `buildMyApp(zuraffaApp) -> String`

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> widget lane [declared: type marker, spec line 26]
route: A2 -> acceptance lane [declared: type marker, spec line 28]
route: A3 -> widget lane [declared: type marker, spec line 30]
route: A4 -> widget lane [declared: type marker, spec line 45]
route: A5 -> acceptance lane [declared: type marker, spec line 47]
route: A6 -> widget lane [declared: type marker, spec line 62]
route: A7 -> acceptance lane [declared: type marker, spec line 64]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U8 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U9 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U10 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: contract:A1 -> contract lane [declared: AppShellBuilder]
route: contract:A2 -> contract lane [declared: AppShellBuilder]

