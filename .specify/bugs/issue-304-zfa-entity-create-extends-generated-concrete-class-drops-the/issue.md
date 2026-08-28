# Bug Issue: zfa entity create --extends: generated concrete class drops the implements clause from the source abstract class

- **Slug**: issue-304-zfa-entity-create-extends-generated-concrete-class-drops-the
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 304
- **URL**: https://github.com/arrrrny/zuraffa/issues/304
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, v6, zuraffa_core, zfa_cli

## Body

## Expected

`zfa entity create -n NativeAuthenticationResult --extends AuthenticationResult --field ...` declares `implements AuthenticationResult` on the generated source abstract class (`abstract class $NativeAuthenticationResult implements AuthenticationResult`). The generated concrete class in `native_authentication_result.zorphy.dart` should therefore also `implements AuthenticationResult`, so `isA<AuthenticationResult>()` holds at runtime.

## Actual

The concrete class is generated as a plain class with **no** implements clause:

```dart
// native_authentication_result.zorphy.dart (generated)
class NativeAuthenticationResult {
  NativeAuthenticationResult({ ... });
  factory NativeAuthenticationResult.fromJson(Map<String, dynamic> json) => ...;
  final ErrorCode errorCode;
  final String message;
  ...
}
```

The `implements AuthenticationResult` declared on the source abstract class is silently dropped. `isA<AuthenticationResult>()` on a `NativeAuthenticationResult` instance is false, and the code compiles only because the generated concrete class never mentions the interface.

## Repro

```
zfa entity enum -n ErrorCode --value unknownError
zfa entity create -n AuthenticationResult --field errorCode:ErrorCode --field message:String
zfa entity create -n NativeAuthenticationResult --extends AuthenticationResult --field errorCode:ErrorCode --field message:String
zfa build
grep 'class NativeAuthenticationResult' lib/src/domain/entities/native_authentication_result/native_authentication_result.zorphy.dart
# -> "class NativeAuthenticationResult {"  (no implements)
```

## Impact

Cannot build union/result-type hierarchies where variant entities are separate files (needed for sealed-union-style dispatch with `isA<Base>()` checks). The vendure-flutter-sdk rewrite works around this by keeping union dispatchers as hand-written glue, but the generator should either propagate the implements clause to the concrete class or reject the flag with a clear message.


## Comments

**coderabbitai** (2026-08-13T17:29:05Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#198 - feat(graphql): Track 3.2 — Schema-to-Full-Stack Generation [merged]
arrrrny/zuraffa#286 - fix: zfa make canonical command (printed by setup) produces non-compiling code: missing data repo impl + missing orchestrator usecase [merged]
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
