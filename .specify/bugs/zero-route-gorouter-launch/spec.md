# Bug Spec: day-zero app shell launches into a zero-route GoRouter

- **Slug**: zero-route-gorouter-launch
- **Synthesized from**: ./assessment.md (issue #1673)
- **Date**: 2026-09-16

**Template Version**: `zuraffa-1.0`

## User Story 1 - Day-zero shell renders a placeholder instead of crashing (Priority: P1)

As a developer running the canonical day-zero workflow (`zfa setup`, `zfa plugin enable …`, `zfa tdd init`), I want `flutter run` to launch the app into a helpful placeholder screen instead of crashing with `no route for location: /`, so the app is runnable before the first `zfa route <Entity>`.

1. **Given** a fresh project scaffolded by `zfa setup` (day-zero `routing/index.dart` with `getAllRoutes() => const []`), **When** `AppShellBuilder.buildAppRouter()` emits `lib/src/routing/app_router.dart` (bare variant, no skin audit), **Then** the emitted GoRouter installs an `errorBuilder` that renders a placeholder (Scaffold with the app title and a "no routes yet — generate views with `zfa route <Entity>`" hint) and a runtime empty-table fallback so `getAllRoutes().isEmpty` swaps in a placeholder `GoRoute(path: '/')` at router-construction time.
   **Type**: widget
2. **Given** the same day-zero project, **When** the emitted router is constructed and the initial location `/` is resolved, **Then** the resolution renders the placeholder instead of throwing `no route for location: /`.
   **Type**: widget
3. **Given** the skin-audit variant of the router (issue #1102, `SkinRouteContractObserver` installed), **When** `buildAppRouter(skinAudit: true)` emits the router, **Then** it carries the same `errorBuilder` / empty-table fallback alongside the observer.
   **Type**: acceptance
4. **Given** a project where `zfa route <Entity>` has since regenerated `routing/index.dart` with real routes, **When** the app router is constructed, **Then** the runtime empty-check leaves the real route table untouched (fallback only fires on an empty table).
   **Type**: acceptance

### User Story 2 - The placeholder survives index regeneration (Priority: P1)

1. **Given** the day-zero placeholder lives in the generated `app_router.dart` (not in `routing/index.dart`), **When** `zfa route`'s index regenerator rewrites or deletes `routing/index.dart`, **Then** the placeholder behavior is unaffected because the fallback is runtime-side in the generated router.
   **Type**: acceptance
2. **Given** the pure-Dart project flavor, **When** the day-zero smoke test is rendered, **Then** it stays router-free (no Flutter imports) — only the Flutter flavor gains router coverage.
   **Type**: acceptance

### User Story 3 - Day-zero smoke test makes the regression visible (Priority: P2)

1. **Given** a fresh Flutter project, **When** `SmokeTestWriter` renders `test/bootstrap_smoke_test.dart` (Flutter flavor), **Then** the smoke test still constructs the DI container AND also pumps the app shell and asserts the initial `/` resolves to the placeholder screen.
   **Type**: widget
2. **Given** the updated emission, **When** the existing app-shell/setup golden tests run, **Then** they assert the new `errorBuilder` / fallback output and pass.
   **Type**: acceptance

## Edge Cases

- The empty-table fallback must not claim `/` once any real route module exists (regeneration safety).
- The skin-audit observer table must remain exactly the `RouteContractTable.fromRouteNames(...)` construction from issue #1102 — the fix adds error handling, it does not alter the observer wiring.
- Unknown deep locations (not just empty table) render the placeholder `errorBuilder` rather than throwing.

## Non-Goals

- No new non-entity `zfa route` command (out of scope for this fix).
- No change to the issue-#626 empty-index contract itself.
- No change to the pure-Dart smoke test flavor.
