# Bug Issue: zfa make generates non-compiling code on v6: presentation imports point to zuraffa (v5) instead of zuraffa_flutter

- **Slug**: issue-281-zfa-make-generates-non-compiling-code-on-v6-presentation-imp
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 281
- **URL**: https://github.com/arrrrny/zuraffa/issues/281
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6, zfa_cli

## Body

## Context

Smoke-testing zuraffa v6 (goal: build a ZikZak-class app at `apps/zikzak_demo` with ONLY zfa commands). `zfa setup --flutter` now works (PR #280), entity creation works, `zfa build` generates parts. But **every `zfa make` output fails to compile** on the v6 stack — the generators still emit v5 imports.

## Repro

```bash
zfa setup zikzak_test --flutter --platforms=ios,macos
cd zikzak_test
zfa entity create -n GrocerySubVariety --field id:String --field name:String --field 'localizedName:Map<String,String>?'
zfa make GrocerySubVariety --preset=crud --methods=get,getList --with=vpc,state,di,test,mock
flutter analyze
```

## Expected

Generated VPC/state/controller files compile against the v6 framework.

## Actual

`zfa make` reports ✅ but `flutter analyze` has 20+ errors. Root causes:

**1. Wrong package import (v5 → v6 split).** Generated presentation files do:

```dart
import 'package:zuraffa/zuraffa.dart';
```

then use `CleanView`, `CleanViewState`, `ControlledWidgetBuilder`, `Controller` — all of which moved to **`zuraffa_flutter`** in v6 (`zuraffa_flutter/lib/src/presentation/controller.dart:141` has `abstract class Controller`; `CleanView`/`CleanViewState`/`ControlledWidgetBuilder` live under `zuraffa_flutter/lib/src/presentation/`). The reference app worked because it pinned `zuraffa: ^5.7.1` where these were in the main package. Generated files must import `package:zuraffa_flutter/zuraffa_flutter.dart` (which re-exports zuraffa + Flutter layer).

**2. Generated controller/domain-state don't import the entity.** `grocery_sub_variety_controller.dart` uses `ListQueryParams<GrocerySubVariety>` but never imports `grocery_sub_variety.dart` → `'GrocerySubVariety' isn't a type`. The reference's own generated controllers DO import the entity (e.g. `login_controller.dart` imports `../../../domain/entities/user/user.dart`). Missing entity import in the v6 generator template.

**3. v6-state path references undefined symbols.** With `--v6-state`, `grocery_sub_variety_domain_state.dart` binds `_entityUseCase` / `GetGrocerySubVarietyParams` which are never defined/imported, and the controller calls `_presenter.getGrocerySubVariety(...)` but the generated `DualLayerPresenter` exposes no use-case methods. Also the generated view does `controller.view.isLoading` but `DualLayerPresenter.view` is typed base `ViewState` → getters don't resolve.

**4. Minor:** setup doesn't wire `json_annotation` as a direct dep → json_serializable warns; generated code importing `package:zuraffa/zuraffa.dart` triggers `depend_on_referenced_packages` info when only `zuraffa_flutter` is a direct dep.

## Suggested fix

1. Update all generator templates (view, controller, presenter, state, detail-view, tests) to import `package:zuraffa_flutter/zuraffa_flutter.dart` when `isFlutter` (matching what setup wires).
2. Add the entity import to generated controller/domain-state templates.
3. Complete the v6-state path: generate/import the use-case + params the DomainState binds, expose use-case methods on the presenter, or type `DualLayerPresenter` generically so `controller.view` resolves concrete signals.
4. Have setup wire `json_annotation`.

## Impact

Blocks the entire v6 smoke test: `zfa make` is the core architecture generator and its output cannot compile on v6.

## Comments

**coderabbitai** (2026-08-09T13:16:20Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#194 - feat(state): Track 2.2 — Dual-Layer State Boundary (DomainState vs ViewState) [merged]
arrrrny/zuraffa#216 - [v6] Track 5.3 — Migration Tooling: v5 to v6 Upgrade Path [merged]
arrrrny/zuraffa#258 - fix: resolve all 42 test failures after zuraffa/zuraffa_flutter split (`#256`) [merged]
arrrrny/zuraffa#273 - [v6 EPIC `#162`] .state.dart Enhancements: State Fragments & Dual-Layer Architecture [merged]
arrrrny/zuraffa#277 - feat(zfa): add setup command + make init wire dependencies (`#275`) [open]
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
