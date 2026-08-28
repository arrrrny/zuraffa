# Bug Issue: bug: regression/quality tests fail — missing example/.zfa.json + unformatted generated files + sealed mock codegen crash

- **Slug**: issue-250-bug-regression-quality-tests-fail-missing-example-zfa-json-u
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 250
- **URL**: https://github.com/arrrrny/zuraffa/issues/250
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, test, v6

## Body

## Summary

Three regression/quality tests fail on `development` @ `c25894f`:

### 7a. Missing `example/.zfa.json`

`test/regression/v5_pipeline_contract_test.dart` (2 failures):

- `v5 pipeline contract example .zfa.json uses v5 config shape` → `Bad state: Missing file: example/.zfa.json`
- `legacy residue guard ... no legacy generator residues remain in active/public surfaces` → `PathNotFoundException: example/.zfa.json`

`example/.zfa.json` does not exist in the repo. Either commit the expected v5 config shape file or update the test to skip when absent.

### 7b. Unformatted generated output

`test/regression/output_quality_test.dart` → `generated output is properly formatted` — `dart format` finds **7 generated files unformatted**:

```
Formatted .../lib/src/di/datasources/product_remote_datasource_di.dart
Formatted .../lib/src/di/repositories/product_repository_di.dart
Formatted .../lib/src/di/datasources/index.dart
Formatted .../lib/src/di/repositories/index.dart
Formatted .../lib/src/di/index.dart
Formatted .../lib/src/routing/product_routes.dart
Formatted .../lib/src/routing/index.dart
Formatted 24 files (7 changed) in 0.04 seconds.
```

Generator templates need trailing-newline/format fixes so generated code is already formatted.

### 7c. Sealed-hierarchy mock codegen crash

`test/integration/polymorphic_mock_integration_test.dart` → `zfa mock data generates compilable subtype mocks for sealed hierarchies` — codegen exits **252** with the same FFI `InvalidType`/`FunctionType` JIT crash as the CLI edge-case group (see #247).

## Repro

```bash
flutter test test/regression/v5_pipeline_contract_test.dart test/regression/output_quality_test.dart test/integration/polymorphic_mock_integration_test.dart
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

arrrrny/zuraffa#140 - Development [closed]
arrrrny/zuraffa#198 - feat(graphql): Track 3.2 — Schema-to-Full-Stack Generation [merged]
arrrrny/zuraffa#209 - [v6] Track 4.3 — X-Ray Control Deck: `@XRayMock` Decorator & Synthetic Payload Injector [merged]
arrrrny/zuraffa#213 - feat: integrate AST smart regeneration from zorphy (`#180`) [merged]
arrrrny/zuraffa#240 - fix(graphql): add missing NamingUtils (documentVarName) to unblock GraphQL plugin [merged]
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
