Fixes #1673.

## Summary

A fresh `zfa setup` app wired `GoRouter(routes: getAllRoutes())` against the deliberately empty day-zero index (issue #626) with no `errorBuilder` and no fallback, so `flutter run` crashed at startup with `no route for location: /` — and nothing the user could run before the first `zfa route <Entity>` made the shell launchable, while the setup banner told them to run exactly that.

The generated `app_router.dart` (both `zfa setup` and `zfa app shell`, bare and skin-audit variants) now:

- swaps in a placeholder `GoRoute(path: '/')` at router-construction time when `getAllRoutes()` is **empty** (runtime check — a real route table is passed through untouched);
- installs an `errorBuilder` rendering the same `ZfaDayZeroPlaceholder` Scaffold (app title + "no routes yet — generate views with `zfa route <Entity>`") for unknown locations.

Both checks live runtime-side in the generated file, so `zfa route`'s index regeneration heals the fallback automatically and can never clobber it (the index regenerator still owns `routing/index.dart` exclusively).

The Flutter day-zero smoke test now also pumps the name-derived shell and asserts the initial `/` resolves without throwing — the regression class was invisible before because the smoke test only constructed the DI container. The pure-Dart flavor is untouched.

## Changes

| File | Change |
|------|--------|
| `lib/src/plugins/app_shell/builders/app_shell_builder.dart` | `buildAppRouter({skinAudit, title})`: both emission branches emit `errorBuilder`, the `getAllRoutes().isEmpty` fallback, and the `ZfaDayZeroPlaceholder` widget |
| `lib/src/commands/setup_command.dart` | passes the app title to `buildAppRouter` |
| `lib/src/commands/app_shell_command.dart` | passes the shell title to `buildAppRouter` |
| `lib/src/cli/writers/tdd/smoke_test_writer.dart` | Flutter smoke-test flavor pumps the shell and asserts `/` resolves (`takeException` null); pure-Dart flavor unchanged |
| `test/tdd/zero-route-gorouter-launch/`, `lib/tdd/zero-route-gorouter-launch/` | 8 acceptance behaviors (TDD evidence below) |

## TDD evidence

Driven through the bug extension's TDD loop (`.specify/bugs/zero-route-gorouter-launch/`):

- 5 behaviors engine-certified red-first (`zfa tdd verify-red` → hand step → `make --born-green`), evidence in `tdd/cycle-log.md`
- 3 behaviors (widget lane) hand-proven — the lane refuses to scaffold without `zuraffa_ui` (#938) and this repo is pure Dart
- Verification: `tdd/verification.md` — **PASS_WITH_GAPS**; deliberate-mutant sampling 2/2 killed (one weak `contains('errorBuilder')` assertion was caught surviving a mutant and strengthened to the named-arg form)

## Local verification

- `dart analyze` on all touched paths: clean; `dart format lib test`: clean
- `test/plugins/app_shell` 89 ✓ · `test/commands` 384 ✓ · `test/cli` 264 ✓ · skew matrix + tdd writers 71 ✓ · feature dir 72 ✓
- Live launch with the placeholder claiming `/` was verified on the issue (zero exceptions, day-zero suite green)

Assessment: `.specify/bugs/zero-route-gorouter-launch/assessment.md`

Closes #1673.
