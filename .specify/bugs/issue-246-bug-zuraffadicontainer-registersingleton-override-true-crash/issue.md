# Bug Issue: bug: ZuraffaDIContainer.registerSingleton(override: true) crashes with null-check on get

- **Slug**: issue-246-bug-zuraffadicontainer-registersingleton-override-true-crash
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 246
- **URL**: https://github.com/arrrrny/zuraffa/issues/246
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, critical, test, v6, zuraffa_core, di

## Body

## Summary

`ZuraffaDIContainer.registerSingleton(..., override: true)` crashes with a null-check error on the next `get<T>()`.

Test: `test/core/module/di_container_override_test.dart` → `override parameter registerSingleton replaces with override: true` on `development` @ `c25894f` (PR #242).

## Error

```
Null check operator used on a null value
package:get_it/get_it_impl.dart 257:26                    _ObjectRegistration.getObject
package:get_it/get_it_impl.dart 768:37                    _GetItImplementation._get
package:get_it/get_it_impl.dart 707:12                    _GetItImplementation.get
package:zuraffa/src/core/module/di_container.dart 197:18  ZuraffaDIContainer.get
test/core/module/di_container_override_test.dart 54:17    main.<fn>.<fn>
```

## Likely root cause

`ZuraffaDIContainer.registerSingleton` (lib/src/core/module/di_container.dart) is implemented via:

```dart
getIt.registerSingletonWithDependencies<T>(factoryFunc, instanceName: instanceName, dependsOn: null);
```

Combined with the new `override` path (unregister existing binding, then re-register), the resulting registration is unresolvable → `_ObjectRegistration.getObject` hits a null. The override path needs to handle `registerSingleton`/`registerInstance` correctly — e.g. `unregister<T>()` followed by a plain re-register, or use `allowReassignment` semantics instead of unregister+register.

## Repro

```bash
flutter test test/core/module/di_container_override_test.dart
```


## Comments

**coderabbitai** (2026-08-04T16:30:25Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#192 - feat(di): Track 1.4 — `@Datasource` & `@Repository` Decorators for Auto-DI [merged]
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
