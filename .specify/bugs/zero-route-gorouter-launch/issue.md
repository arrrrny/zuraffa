# Bug Issue: day-zero app shell launches into a zero-route GoRouter

- **Slug**: zero-route-gorouter-launch
- **Fetched**: 2026-09-16
- **Issue**: 1673
- **URL**: https://github.com/arrrrny/zuraffa/issues/1673
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, zfa_cli

## Body

# bug(626): day-zero app shell launches into a zero-route GoRouter — "no route for location: /" (home not found) on `flutter run`

## Repro (canonical workflow, before the first `zfa route`)

```
zfa setup todo_app --platforms=macos
zfa plugin enable ...           # any set
zfa tdd init
flutter test                    # green day zero (bootstrap smoke test passes)
flutter run -d macos            # CRASHES at startup
```

Observed on a fresh app (v6.3.x): go_router fails to resolve the initial
location — the user-visible symptom is the "home not found" class of error
(`no route for location: /`), because:

1. `lib/src/routing/index.dart` (issue #626 bootstrap index) returns
   `List<RouteBase> getAllRoutes() => const [];` — an EMPTY route table by
   design until `zfa route <Entity>` generates modules.
2. `lib/src/app/<app>.dart` (generated) wires
   `ZuraffaApp(home: Router.withConfig(config: appRouter))`.
3. The generated `app_router.dart` installs NO `errorBuilder` /
   `errorPageBuilder` and there is no fallback route, so the initial `/`
   resolution fails at runtime.

`flutter test` stays green because the day-zero smoke test only constructs
the DI container (`<App>Container`) — it never pumps the router.

## Why this is a gap, not user error

- The day-zero design (issue #626) deliberately ships the empty index, but
  nothing in the generated shell handles the empty case — the app is
  un-runnable between `zfa setup` and the first `zfa route <Entity>`.
- The only route generator is entity-bound (`zfa route <Entity>`; there is
  no spec-driven/no-entity route path), so spec-driven apps have NO zfa
  command that can make the shell launchable.
- The setup banner tells the user to `flutter run` the app day zero
  ("Run the app: flutter run"), which crashes exactly then.

## Suggested remedies (any one)

1. **Fallback route in the shell**: when `getAllRoutes()` is empty, the
   generated `app_router.dart` adds a day-zero home route (a Scaffold
   placeholder: app title + "generate views with `zfa route <Entity>`").
   Cheapest fix, keeps the index contract untouched.
2. **Error builder**: install `errorBuilder` on the generated GoRouter so an
   empty/unknown table renders the placeholder instead of throwing.
3. **Setup emits a placeholder route module** that `zfa route` later
   replaces (same regeneration contract as the rest of the index).

Also worth covering: a day-zero smoke test that pumps `TodoApp`/the router
and resolves `/` (the current smoke test only constructs the container, so
this regression class is invisible to `flutter test`).

## Workaround applied (hand edit, until `zfa route` regenerates the index)

`lib/src/routing/index.dart` — return a single `GoRoute(path: '/', builder:
...)` placeholder home from `getAllRoutes()`. App then launches cleanly
(verified: `flutter run -d macos`, zero exceptions, `flutter test` 11/11
green, `dart analyze` clean).

## Comments

None.
