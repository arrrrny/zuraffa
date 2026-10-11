# Traceability: zero-route-gorouter-launch

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:f72ecf03bf32eed012bcf00075ddefd6a509146588f5d16d3e905c04a5671d85
statements: 8
automated: 8
manual: 0
fr-manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 13 | 1. **Given** a fresh project scaffolded by `zfa setup` (day-zero `routing/index.dart` with `getAllRoutes() => const []`), **When** `AppShellBuilder.buildAppRouter()` emits `lib/src/routing/app_router.dart` (bare variant, no skin audit), **Then** the emitted GoRouter installs an `errorBuilder` that renders a placeholder (Scaffold with the app title and a "no routes yet — generate views with `zfa route <Entity>`" hint) and a runtime empty-table fallback so `getAllRoutes().isEmpty` swaps in a placeholder `GoRoute(path: '/')` at router-construction time. | A1 | automated |
| AC-2 | 14 | 2. **Given** the same day-zero project, **When** the emitted router is constructed and the initial location `/` is resolved, **Then** the resolution renders the placeholder instead of throwing `no route for location: /`. | A2 | automated |
| AC-3 | 15 | 3. **Given** the skin-audit variant of the router (issue #1102, `SkinRouteContractObserver` installed), **When** `buildAppRouter(skinAudit: true)` emits the router, **Then** it carries the same `errorBuilder` / empty-table fallback alongside the observer. | A3 | automated |
| AC-4 | 16 | 4. **Given** a project where `zfa route <Entity>` has since regenerated `routing/index.dart` with real routes, **When** the app router is constructed, **Then** the runtime empty-check leaves the real route table untouched (fallback only fires on an empty table). | A4 | automated |
| AC-5 | 20 | 1. **Given** the day-zero placeholder lives in the generated `app_router.dart` (not in `routing/index.dart`), **When** `zfa route`'s index regenerator rewrites or deletes `routing/index.dart`, **Then** the placeholder behavior is unaffected because the fallback is runtime-side in the generated router. | A5 | automated |
| AC-6 | 21 | 2. **Given** the pure-Dart project flavor, **When** the day-zero smoke test is rendered, **Then** it stays router-free (no Flutter imports) — only the Flutter flavor gains router coverage. | A6 | automated |
| AC-7 | 25 | 1. **Given** a fresh Flutter project, **When** `SmokeTestWriter` renders `test/bootstrap_smoke_test.dart` (Flutter flavor), **Then** the smoke test still constructs the DI container AND also pumps the app shell and asserts the initial `/` resolves to the placeholder screen. | A7 | automated |
| AC-8 | 26 | 2. **Given** the updated emission, **When** the existing app-shell/setup golden tests run, **Then** they assert the new `errorBuilder` / fallback output and pass. | A8 | automated |

