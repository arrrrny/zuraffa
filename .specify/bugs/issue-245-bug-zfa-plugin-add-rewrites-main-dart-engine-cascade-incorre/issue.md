# Bug Issue: bug: zfa plugin add rewrites main.dart engine cascade incorrectly (registration outside cascade)

- **Slug**: issue-245-bug-zfa-plugin-add-rewrites-main-dart-engine-cascade-incorre
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 245
- **URL**: https://github.com/arrrrny/zuraffa/issues/245
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, test, v6, zfa_cli

## Body

## Summary

`zfa plugin add <package>` generates an invalid `main.dart` — the new plugin registration is emitted **outside** the engine cascade instead of as a `..register(X())` link.

Test: `test/src/commands/plugin_command_add_test.dart` (3 failures) on `development` @ `c25894f` (PR #242).

## Failing tests

- `PluginCommand.execute add adds plugin to existing cascade chain` — expects `contains '..register(AnalyticsPlugin())'` but the generated output is:

```dart
import 'package:flutter/material.dart';
import 'package:zuraffa/zuraffa.dart';
import 'package:zuraffa_analytics/zuraffa_analytics.dart';

void main() async {
  final engine = ZuraffaEngine()
    ..register(CorePlugin())
    ..register(AuthPlugin());
        final analyticsPlugin = AnalyticsPlugin();
      engine
        ..register(analyticsPlugin)

await engine.bootstrap();
```

The `final analyticsPlugin = AnalyticsPlugin();` statement lands in the middle of the cascade expression, the `engine..register(analyticsPlugin)` chain is left dangling (unterminated), and the expected `..register(AnalyticsPlugin())` inline form is missing.

- `PluginCommand.execute add adds zuraffa_feature_example plugin to main.dart` — same root cause.
- Duplicate-import detection test: adding an already-imported package correctly prints "already imported", but the cascade rewrite path itself is broken.

## Expected behavior

`zfa plugin add zuraffa_analytics` on a main.dart with an existing `ZuraffaEngine()..register(...)` cascade should produce `..register(AnalyticsPlugin())` appended to the cascade, with the import added at the top, and valid Dart output.

## Repro

```bash
flutter test test/src/commands/plugin_command_add_test.dart
```


## Comments

**coderabbitai** (2026-08-04T16:29:02Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#148 - feat: VM Service API Plugin — Auto-Generated Runtime RPC Bridge (v5.4.0) [merged]
arrrrny/zuraffa#213 - feat: integrate AST smart regeneration from zorphy (`#180`) [merged]
arrrrny/zuraffa#217 - [v6] Track 6.1 — `@Route` Decorator for Auto-Generated Navigation Configuration [merged]
arrrrny/zuraffa#241 - feat(v6): micro-frontend baseline — ZuraffaPlugin/ZuraffaEngine + zfa module [merged]
arrrrny/zuraffa#242 - feat: plugin system & usecase abstraction layer [merged]
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
