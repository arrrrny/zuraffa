# Bug Issue: [xray] Missing xray_mock_parser_stub.dart breaks X-Ray plugin (analyzer error)

- **Slug**: issue-232-missing-xray-mock-parser-stub-dart-breaks-x-ray-plugin-analy
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 232
- **URL**: https://github.com/arrrrny/zuraffa/issues/232
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, task, v6

## Body

## Summary

The X-Ray plugin is broken at compile time: `lib/src/presentation/xray/xray_mock_parser.dart` imports `xray_mock_parser_stub.dart`, which does not exist → 1 analyzer error:

```
error - lib/src/presentation/xray/xray_mock_parser.dart:7:8 - Target of URI doesn't exist: 'xray_mock_parser_stub.dart' - uri_does_not_exist
```

## Root cause

`xray_mock_parser.dart` line 7 imports a stub file that was never created (or was deleted). Only `xray_mock_parser.dart` exists in `lib/src/presentation/xray/` — the `xray_mock_parser_stub.dart` it conditionally imports is missing. This breaks the X-Ray mock parser compilation.

## Fix

Create `lib/src/presentation/xray/xray_mock_parser_stub.dart` matching what line 7 of `xray_mock_parser.dart` expects (likely the stub variant of the parser, e.g. for platforms/contexts where the full implementation isn't available).

## Acceptance

- [ ] `lib/src/presentation/xray/xray_mock_parser_stub.dart` exists
- [ ] The `uri_does_not_exist` error is gone from `dart analyze`
- [ ] X-Ray mock parser compiles

## Comments

**coderabbitai** (2026-08-04T03:45:20Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#152 - feat(xray): DTD/VM-Service element mapping + debug overlay plugin [merged]
arrrrny/zuraffa#207 - feat(xray): Track 4.1 — XRayScope & XRayNode deterministic widget ID infrastructure (`#182`) [merged]
arrrrny/zuraffa#208 - feat: X-Ray visual overlay with bounding boxes [merged]
arrrrny/zuraffa#209 - [v6] Track 4.3 — X-Ray Control Deck: `@XRayMock` Decorator & Synthetic Payload Injector [merged]
arrrrny/zuraffa#226 - fix: remove export of nonexistent graphql/naming_utils.dart (`#222`) [open]
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
