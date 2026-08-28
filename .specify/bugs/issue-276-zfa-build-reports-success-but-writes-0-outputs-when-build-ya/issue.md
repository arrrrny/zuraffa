# Bug Issue: zfa build reports success but writes 0 outputs when build.yaml is missing (no zfa command creates it)

- **Slug**: issue-276-zfa-build-reports-success-but-writes-0-outputs-when-build-ya
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 276
- **URL**: https://github.com/arrrrny/zuraffa/issues/276
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: enhancement, task, config, v6, zfa_cli

## Body

## Context

Blocking roadblock found while smoke-testing zuraffa v6 (goal: build a ZikZak-class app at `apps/zikzak_demo` using ONLY zfa commands). zfa CLI v6.0.0 (development branch, freshly rebuilt via `scripts/rebuild.sh`).

## What I ran

```bash
# 1. Fresh app scaffolded
flutter create zikzak_demo --empty
# (pubspec.yaml wired with zuraffa_flutter path dep, build_runner, zorphy_annotation, zorphy overrides)

# 2. Entity created fine
zfa entity create -n GrocerySubVariety --field id:String --field name:String --field 'localizedName:Map<String,String>?'

# 3. Build — expected .zorphy.dart + .g.dart
zfa build
```

## Expected

`zfa build` runs build_runner with the **zorphy builder registered** and generates `grocery_sub_variety.zorphy.dart` + `grocery_sub_variety.g.dart` (exactly what the reference app `~/Developer/zik_zak` has via its `build.yaml`).

## Actual

`zfa build` completed with **0 outputs generated**, and reported success:

```
W These options have been removed and were ignored: --delete-conflicting-outputs
Built with build_runner/aot in 705s; wrote 0 outputs.
✅ Build completed successfully
```

No `.zorphy.dart` / `.g.dart` files exist afterward. The project is missing `build.yaml`, and **zfa provides no command that creates it** (grep over `lib/src/**` for `build.yaml` writes returns nothing; `zfa entity create`, `zfa make`, `zfa build` do not scaffold it).

## Root cause

- A zfa-generated entity requires the `zorphy:zorphy` builder, which must be registered in a `build.yaml`.
- The reference project has one (hand-written historically); a brand-new zfa workflow never emits it.
- `zfa build` does not detect the missing builder registration — it exits 0 with `wrote 0 outputs`, a silent false success.

## Suggested fix

1. `zfa entity create` (or `zfa build`) should ensure `build.yaml` exists with the zorphy builder registered (scaffold it when absent, like `buildByDefault` intends).
2. `zfa build` should **fail loudly** (non-zero exit + clear message) when the project has no builders configured and 0 outputs are produced, instead of printing ✅ success.
3. Ties into #275 (add `zfa setup` / `zfa init` bootstrap flow) — build.yaml scaffolding should be part of that too.

## Impact

Blocks the entire v6 smoke test: without generated parts, `zfa make` output and the app cannot compile.

## Comments

**coderabbitai** (2026-08-09T07:09:35Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#145 - 008 mock json method [closed]
arrrrny/zuraffa#147 - Development [closed]
arrrrny/zuraffa#157 - feat: add zuraffa_setup MCP tool and config_init dependency checks [merged]
arrrrny/zuraffa#213 - feat: integrate AST smart regeneration from zorphy (`#180`) [merged]
arrrrny/zuraffa#241 - feat(v6): micro-frontend baseline — ZuraffaPlugin/ZuraffaEngine + zfa module [merged]
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
**arrrrny** (2026-08-09T07:09:58Z):

Related: this is a symptom of #275 (missing `zfa setup`/bootstrap flow). Root cause is the same: a fresh zfa workflow never scaffolds `build.yaml`, because there is no setup/init command.

The build.yaml scaffolding should be part of #275's scope. The only part of this issue that stands alone is the robustness ask: `zfa build` should exit non-zero (fail loudly) when 0 outputs are produced instead of printing ✅ success.
