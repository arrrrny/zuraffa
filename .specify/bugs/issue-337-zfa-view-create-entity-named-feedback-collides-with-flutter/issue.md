# Bug Issue: zfa view create: entity named 'Feedback' collides with Flutter's Feedback widget — ambiguous_import

- **Slug**: issue-337-zfa-view-create-entity-named-feedback-collides-with-flutter
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 337
- **URL**: https://github.com/arrrrny/zuraffa/issues/337
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6, zfa_cli

## Body

## Context

Smoke-testing zuraffa v6 at apps/zikzak_demo. Entity `Feedback` (generated via `zfa entity create`) generates a view that fails analyze:

```
error • The name 'Feedback' is defined in the libraries 'package:flutter/src/widgets/feedback.dart (via package:flutter/material.dart)' and 'package:zikzak_demo/src/domain/entities/feedback/feedback.dart'. • lib/src/presentation/pages/feedback/feedback_view.dart:13:9 • ambiguous_import
```

## What I ran

```bash
zfa view create Feedback --di --force
flutter analyze
```

## Expected

Generated view compiles — e.g. import the entity with a prefix (`import ... as entities;`) or hide the colliding name from material.dart (`import 'package:flutter/material.dart' hide Feedback;`) when the entity name collides with a public Flutter symbol.

## Actual

Both symbols are imported unqualified → ambiguous_import → compile error.

## Repro

apps/zikzak_demo: `flutter analyze lib/src/presentation/pages/feedback/`

Known Flutter-colliding names to consider: Feedback, Table, Divider, Chip, Tooltip, Drawer, Material, Widget... The generator should detect collisions against a denylist (or analyzer) and qualify.

Separate defect class from #333/#334/#335 (found while re-verifying #335).

## Comments

**coderabbitai** (2026-08-14T20:33:45Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#228 - fix: disambiguate StateMigrator ambiguous export (`#224`) [merged]
arrrrny/zuraffa#287 - fix(zfa make): always generate data repo impl + wire per-method DI for entity presets (`#284`) [merged]
arrrrny/zuraffa#291 - fix(zfa make): v6 presentation imports use zuraffa_flutter + wire json_annotation (`#281`) [merged]
arrrrny/zuraffa#331 - fix(zfa route create): align route/view contract — probe detail_view on disk + accept entity named-param (`#328`) [open]
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
