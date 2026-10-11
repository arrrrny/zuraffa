# Bug Assessment: day-zero app shell launches into a zero-route GoRouter

- **Slug**: zero-route-gorouter-launch
- **Created**: 2026-09-16
- **Source**: https://github.com/arrrrny/zuraffa/issues/1673
- **Verdict**: likely valid, needs reproduction (root cause already traced in zuraffa source)
- **Severity**: high (day-zero app is un-runnable; `flutter run` crashes for every fresh `zfa setup` project)

## Report (verbatim or summarized)

Issue #1673: after the canonical day-zero workflow (`zfa setup todo_app --platforms=macos`, `zfa plugin enable …`, `zfa tdd init`), `flutter test` is green but `flutter run -d macos` crashes at startup with `no route for location: /` (home not found). The app is un-runnable between `zfa setup` and the first `zfa route <Entity>`.

## Symptom

A freshly scaffolded zfa app boots GoRouter against an EMPTY route table (`getAllRoutes() => const []`, the deliberate issue-#626 day-zero index), with no `errorBuilder`/`errorPageBuilder` and no fallback route, so resolving the initial `/` throws at runtime.

## Reproduction

1. `zfa setup todo_app --platforms=macos`
2. `zfa plugin enable …` (any set)
3. `zfa tdd init`
4. `flutter test` → green (bootstrap smoke test passes)
5. `flutter run -d macos` → CRASH at startup: `no route for location: /`

## Suspected Code Paths

Verified in source:

1. `lib/src/cli/writers/tdd/app_module_writer.dart:172` — `BootstrapRoutingIndexWriter.render()` emits the day-zero `lib/src/routing/index.dart` with `List<RouteBase> getAllRoutes() => const [];` (by design, issue #626).
2. `lib/src/plugins/app_shell/builders/app_shell_builder.dart:519` — `buildAppRouter()`; the bare variant at `:595` (`_buildBareAppRouter()`) emits `final GoRouter appRouter = GoRouter(routes: getAllRoutes());` with NO `errorBuilder`/`errorPageBuilder` and no fallback route.
3. `lib/src/commands/setup_command.dart:458` — setup writes the bootstrap index; `:613-615` — setup writes `app_router.dart` via `builder.buildAppRouter()` into the fresh app.
4. The generated shell (`lib/src/app/<app>.dart`) wires `ZuraffaApp(home: Router.withConfig(config: appRouter))`, so the initial `/` resolution fails at runtime.
5. `lib/src/cli/writers/tdd/smoke_test_writer.dart:50` — the day-zero smoke test only constructs the DI container (`<App>Container()`); it never pumps the router, which is why `flutter test` stays green while `flutter run` crashes.
6. Same router emission is used by `zfa app shell` (`lib/src/commands/app_shell_command.dart`), so the fix must cover both entrypoints.

## Root Cause Hypothesis

The issue-#626 day-zero design ships an intentionally empty route table, but nothing in the generated shell handles the empty case. The generated `app_router.dart` unconditionally wires `GoRouter(routes: getAllRoutes())`; GoRouter throws `GoException: no routes for location: /` when the table is empty and no error builder is installed. There is no non-entity `zfa route` path, so nothing the user can run between setup and the first entity route makes the shell launchable — while the setup banner explicitly tells the user to `flutter run` day zero.

## Proposed Remediation

Primary (matches issue remedy #1 + #2, keeps the #626 index contract untouched):

1. In `AppShellBuilder.buildAppRouter()` — BOTH the bare (`_buildBareAppRouter`) and the skin-audit variant — install an `errorBuilder` on the emitted GoRouter that renders a day-zero placeholder (Scaffold: app title + "no routes yet — generate views with `zfa route <Entity>`"). Additionally, emit a runtime empty-table fallback so `getAllRoutes().isEmpty` swaps in a placeholder `GoRoute(path: '/')` — this keeps the URL at `/` and heals automatically after the first `zfa route <Entity>` regenerates the index (the check is at router-construction time in generated code, so index regeneration cannot clobber it).
2. Do NOT put the placeholder in `routing/index.dart`: `_regenerateIndexFile` DELETES the index when no `*_routes.dart` modules exist, so an index-side placeholder would be clobbered/lost.
3. Test coverage so the regression class is visible to `flutter test`:
   - Extend the day-zero smoke test writer (Flutter variant) to ALSO pump the app shell / resolve `/` (currently it only constructs the DI container).
   - Update/extend `test/plugins/app_shell/app_shell_builder_test.dart` (and the skin-audit test) to assert the generated `app_router.dart` installs the `errorBuilder` / fallback route.

## Risks & Considerations

- `buildAppRouter` output is asserted by golden/exact-output tests: `test/plugins/app_shell/app_shell_builder_test.dart`, `test/plugins/app_shell/app_shell_skin_audit_test.dart`, `test/integration/day_zero_smoke_gate_test.dart`, `test/skew/bug_1197_two_end_matrix_test.dart`, and possibly setup golden tests. Changing emission will ripple — update assertions, not just code.
- The skin-audit variant emits a different router body (adds `observers`) — the fix must be applied to both emission branches.
- The smoke test change only affects the Flutter flavor; the pure-Dart flavor has no router and must stay unchanged.
- Verified workaround from the issue (hand-edited `routing/index.dart` returning a placeholder `GoRoute(path: '/')`) confirms the app launches cleanly once `/` resolves.

## Open Questions

- None blocking. Remedy choice (errorBuilder vs. empty-fallback vs. both) can be settled during the fix; the issue author marked any single remedy acceptable, and errorBuilder + runtime fallback together cover both the empty-table case and unknown locations.
