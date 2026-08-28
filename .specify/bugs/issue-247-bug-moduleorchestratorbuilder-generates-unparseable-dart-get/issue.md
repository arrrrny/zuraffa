# Bug Issue: bug: ModuleOrchestratorBuilder generates unparseable Dart (getter bodies without return)

- **Slug**: issue-247-bug-moduleorchestratorbuilder-generates-unparseable-dart-get
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 247
- **URL**: https://github.com/arrrrny/zuraffa/issues/247
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, test, v6

## Body

## Summary

`ModuleOrchestratorBuilder` emits **unparseable Dart** — `dart format` fails on the generated file.

Test: `test/plugins/module/module_plugin_test.dart` (2 failures) on `development` @ `c25894f` (PR #242):

- `ModuleOrchestratorBuilder generates orchestrator file with correct class name`
- `ModuleOrchestratorBuilder generates file with pascal-case name handling`

## Error

```
Could not format because the source could not be parsed:

line 1, column 156 of .: Expected to find ';'.
1 │ import 'package:flutter/widgets.dart';import 'package:zuraffa/zuraffa.dart';class TodoFeaturePlugin extends ZuraffaPlugin {@override String get pluginId { 'todo' }
  │                                                                                                                                                            ^^^^^^
line 6, column 44 of .: Expected to find ';'.
6 │ @override Map<String, ZuraffaRouteBuilder> get routes { // TODO: expose this feature's routes.
```

## Problems in the generated template

- Getter bodies use `{ 'todo' }` instead of `=> 'todo'` (missing `return` / arrow syntax).
- Statements and declarations are joined on one line with no newlines (imports + class on the same line).
- The `routes` getter has a body-less `{` containing only a comment — no return value.

## Expected behavior

Generated orchestrator file parses and formats cleanly, e.g.:

```dart
import 'package:flutter/widgets.dart';
import 'package:zuraffa/zuraffa.dart';

class TodoFeaturePlugin extends ZuraffaPlugin {
  @override
  String get pluginId => 'todo';

  @override
  Map<String, ZuraffaRouteBuilder> get routes => const {};
}
```

## Repro

```bash
flutter test test/plugins/module/module_plugin_test.dart
```


## Comments

**coderabbitai** (2026-08-04T16:28:55Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#148 - feat: VM Service API Plugin — Auto-Generated Runtime RPC Bridge (v5.4.0) [merged]
arrrrny/zuraffa#191 - feat(compiler): Track 1.3 — Decorator-Driven Architecture (DDA) Foundation [merged]
arrrrny/zuraffa#198 - feat(graphql): Track 3.2 — Schema-to-Full-Stack Generation [merged]
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
