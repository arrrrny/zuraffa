# Bug Issue: bug: zfa make crashes with JIT FFI error instead of friendly validation messages

- **Slug**: issue-249-bug-zfa-make-crashes-with-jit-ffi-error-instead-of-friendly
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 249
- **URL**: https://github.com/arrrrny/zuraffa/issues/249
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, test, v6, zfa_cli

## Body

## Summary

`zfa make` crashes with a JIT/FFI compilation error instead of printing friendly validation messages when the JSON config file is missing or invalid.

Test: `test/cli/cli_edge_cases_test.dart` (4 failures) on `development` @ `c25894f`:

- `make handles missing JSON config file` — expected `contains 'json file not found'`
- `make handles invalid JSON structure from file`
- `make shows usage when name and JSON input are missing`
- `removed generate command fails fast with migration guidance`

## Error

The CLI process crashes before reaching argument validation:

```
crash when compiling:
type 'invalidtype' is not a subtype of type 'functiontype' in type cast

#0      _FfiUseSiteTransformer._verifyAndReplaceNativeCallable (package:vm/modular/transformations/ffi/use_sites.dart:1317:31)
#1      _FfiUseSiteTransformer._verifyAndReplaceNativeCallableIsolateLocal (package:vm/modular/transformations/ffi/use_sites.dart:1434:12)
#2      _FfiUseSiteTransformer._visitStaticInvocation (package:vm/modular/transformations/ffi/use_sites.dart:702:16)
...
```

The same FFI `InvalidType`/`FunctionType` JIT crash also appears in `test/integration/polymorphic_mock_integration_test.dart` (codegen exit 252).

## Hypothesis

Likely related to the lib compile errors (see #244): a broken import forces a broken compile path, and the FFI crash surfaces during JIT compilation of the CLI. Also worth ruling out a toolchain issue with Flutter 3.44.8's `dart run`/FFI transformer.

## Repro

```bash
flutter test test/cli/cli_edge_cases_test.dart
# or directly:
dart run bin/zuraffa.dart make --json nonexistent.json
```


## Comments

**coderabbitai** (2026-08-04T16:29:01Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->

<details>
<summary>⚠️ Possible Duplicate Issue(s)</summary>

- https://github.com/arrrrny/zuraffa/issues/243
</details>
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#145 - 008 mock json method [closed]
arrrrny/zuraffa#147 - Development [closed]
arrrrny/zuraffa#148 - feat: VM Service API Plugin — Auto-Generated Runtime RPC Bridge (v5.4.0) [merged]
arrrrny/zuraffa#198 - feat(graphql): Track 3.2 — Schema-to-Full-Stack Generation [merged]
arrrrny/zuraffa#213 - feat: integrate AST smart regeneration from zorphy (`#180`) [merged]
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
