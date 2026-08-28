# Bug Issue: zfa route shell: positional-vs-named constructor mismatch (main_shell.dart doesn't compile) + branch routes are SizedBox.shrink placeholders

- **Slug**: issue-377-zfa-route-shell-positional-vs-named-constructor-mismatch-mai
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 377
- **URL**: https://github.com/arrrrny/zuraffa/issues/377
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, enhancement, task, v6, zuraffa_core, zfa_cli

## Body

## Context

Smoke-testing zuraffa v6 (goal: any agent builds a ZikZak-class app with ONLY zfa commands, intuitively). Used the new `zfa route shell --bottom-nav` (#366) to generate the app's bottom-navigation skeleton. `zfa build` succeeds but `flutter analyze` shows **3 errors in the generated shell**, and the shell's branch routes are placeholders that don't wire to the generated screens.

## What I ran

```bash
zfa route shell --name Main --branch "Home:/grocery" --branch "Deals:/deal" --branch "Profile:/profile" --bottom-nav
zfa build
flutter analyze
```

## Expected

Generated `MainShell` compiles; branch routes delegate to the app's generated screens.

## Actual

```
error • All final variables must be initialized, but 'navigationShell' isn't.  (final_not_initialized_constructor)
  • lib/src/routing/main_shell.dart:6:9
error • 1 positional argument expected by 'MainShell.new', but 0 found.  (not_enough_positional_arguments)
  • lib/src/routing/main_shell.dart:40:21
error • The named parameter 'navigationShell' isn't defined.  (undefined_named_parameter)
  • lib/src/routing/main_shell.dart:40:21
```

Generated shell declares a **positional** constructor + final field, but the shell route calls it with a **named** argument:

```dart
// main_shell.dart (generated)
class MainShell extends StatelessWidget {
  const MainShell(StatefulNavigationShell navigationShell, {super.key});  // positional
  final StatefulNavigationShell navigationShell;
  ...
}

List<RouteBase> mainShellRoute() {
  return [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),   // named call → mismatch
      ...
```

Also, the three branch routes are `SizedBox.shrink()` placeholders — they don't reference the generated screens for `/grocery`, `/deal`, `/profile` (which in this app are `/grocery_product`, `/deal_list`, etc.), so the shell shows empty tabs even when it compiles.

## Root cause

1. The shell template emits `const MainShell(StatefulNavigationShell navigationShell, {super.key})` (positional first param) but the `StatefulShellRoute.indexedStack` builder emits `MainShell(navigationShell: navigationShell)` (named). One of them is wrong — the constructor should be `const MainShell({required this.navigationShell, super.key})` to match the named call.
2. The `--branch <Label>:<path>` routes are emitted as `SizedBox.shrink()` stubs — there is no mechanism to point a branch at an existing generated route (entity route, custom route, or a specific view), so a generated shell is never functional out of the box.

## Suggested fix

1. Emit the constructor as named: `const MainShell({required this.navigationShell, super.key});` (matches the builder's named call) — or emit the builder with a positional arg. Add a compile test for the generated shell (parse/compile `main_shell.dart`).
2. Branch routes should delegate to real screens: support `--branch <Label>:<RoutePath>` where `<RoutePath>` matches an existing generated route (e.g. `/grocery_product`), and emit `builder: (context, state) => <ExistingView>()` (or `GoRouter` redirect to the named route) instead of `SizedBox.shrink()`. Fall back to a `SizedBox.shrink()` only when no matching route/view is found, with a warning.
3. Regression test: generate a shell against a real app (entities + views generated), assert it compiles AND the branches render non-empty content (a boot smoke test navigating each branch).

## Impact

The shell/bottom-nav feature (#366, closing #359) produces non-compiling code and empty tabs — the primary navigation surface of a zfa-only app cannot be built yet. Same pattern as the earlier route/view contract churn (#328→#342): generated shells need a compile+render regression test.


## Comments

**coderabbitai** (2026-08-16T13:18:51Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#255 - fix: address review comments on `#254` [merged]
arrrrny/zuraffa#331 - fix(zfa route create): align route/view contract — probe detail_view on disk + accept entity named-param (`#328`) [merged]
arrrrny/zuraffa#355 - fix(route): emit root / route in routing index so generated apps boot [merged]
arrrrny/zuraffa#366 - feat(route): shell + bottom navigation — StatefulShellRoute branches + nav bar; generated views render mock data by default [merged]
arrrrny/zuraffa#376 - fix(app-shell): align main.dart setupDependencies() with generated DI signature (`#370`) [merged]
</details>

---
<details>
<summary>📝 Issue Planner</summary>

<sub>Check the box below or use the `@coderabbitai plan` command to generate an implementation plan and prompts that you can use with your favorite coding assistant.</sub>

- [ ] <!-- {"checkboxId": "8d4f2b9c-3e1a-4f7c-a9b2-d5e8f1c4a7b9"} --> Create Plan
</details>


---
<details>
<summary> 🧪 Issue enrichment is currently in open beta.</summary>


You can configure auto-planning by selecting labels in the issue_enrichment configuration.

To disable automatic issue enrichment, add the following to your `.coderabbit.yaml`:
```yaml
issue_enrichment:
  auto_enrich:
    enabled: false
```
</details>

💬 Have feedback or questions? Drop into our [discord](https://discord.gg/coderabbit)!
**arrrrny** (2026-08-21T06:23:54Z):

Re-tested 2026-08-21 with the latest zfa (after #404 build fix — `bash scripts/rebuild.sh` now succeeds, `zfa --version` v6.0.0). **#377 is still reproducible.** The route-shell generator was not touched by the #404 fix.

Command (in `apps/zikzak_demo`):
```bash
zfa route shell --name Main --branch "Home:/grocery" --branch "Deals:/deal" --branch "Profile:/profile" --bottom-nav --force
```
Exits 0, but emits non-compiling `lib/src/routing/main_shell.dart`. `flutter analyze` reports the same 3 errors:

```
error • All final variables must be initialized, but 'navigationShell' isn't.   main_shell.dart:6:9   final_not_initialized_constructor
error • 1 positional argument expected by 'MainShell.new', but 0 found.         main_shell.dart:40:21 not_enough_positional_arguments
error • The named parameter 'navigationShell' isn't defined.                    main_shell.dart:40:21 undefined_named_parameter
```

Root cause unchanged: line 6 declares `const MainShell(StatefulNavigationShell navigationShell, {super.key})` (positional `navigationShell`), but line 40 calls `MainShell(navigationShell: navigationShell)` (named). Also branch routes are still `SizedBox.shrink()` placeholders (lines 47/56/65), not wired to the real `/grocery`, `/deal`, `/profile` views.

Per the project's hard roadblock rule, the smoke test STOPPED here — no workaround, no hand-edit. Blocking the zikzak_demo clone.

