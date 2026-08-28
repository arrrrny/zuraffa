# Bug Issue: [mcp] Warnings: unused encoded vars in test_capability.dart + unused imports in mcp_v2_test.dart

- **Slug**: issue-237-warnings-unused-encoded-vars-in-test-capability-dart-unused
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 237
- **URL**: https://github.com/arrrrny/zuraffa/issues/237
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, task

## Body

## Summary

Three MCP-related warnings from `dart analyze`:

```
warning - lib/src/mcp/capabilities/test_capability.dart:145:11 - The value of the local variable 'paramsEncoded' isn't used - unused_local_variable
warning - lib/src/mcp/capabilities/test_capability.dart:146:11 - The value of the local variable 'mocksEncoded' isn't used - unused_local_variable
warning - test/mcp_v2_test.dart:1:8 - Unused import: 'dart:convert' - unused_import
warning - test/mcp_v2_test.dart:9:8 - Unused import: 'package:zuraffa/src/mcp/file_watcher.dart' - unused_import
```

## Details

1. **`test_capability.dart:145-146`** — `paramsEncoded` and `mocksEncoded` are computed (likely JSON-encoded test params/mocks) but never used. This looks like a real gap: the encoded values were probably meant to be sent to the test runner / included in the capability response. Verify whether the MCP `test` capability is silently dropping encoded params/mocks — could be an actual functional bug, not just dead code.

2. **`test/mcp_v2_test.dart:1,9`** — unused imports (`dart:convert`, `src/mcp/file_watcher.dart`); remove them.

## Fix

- For `paramsEncoded`/`mocksEncoded`: wire them into the capability output if they belong there, or remove if genuinely dead. Check the surrounding `test_capability.dart` flow (lines ~140-160).
- For the test: remove both unused imports.

## Acceptance

- [ ] All 4 MCP warnings gone from `dart analyze`
- [ ] MCP `test` capability behavior verified (encoded params/mocks handled correctly or intentionally removed)

## Comments

**coderabbitai** (2026-08-04T03:47:26Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

arrrrny/zuraffa#155 - refactor: api_bridge_builder — code_builder emission + generic params fixes [merged]
arrrrny/zuraffa#157 - feat: add zuraffa_setup MCP tool and config_init dependency checks [merged]
arrrrny/zuraffa#209 - [v6] Track 4.3 — X-Ray Control Deck: `@XRayMock` Decorator & Synthetic Payload Injector [merged]
arrrrny/zuraffa#211 - feat(xray): add MCP bridge for AI agent tree inspection [merged]
arrrrny/zuraffa#215 - [v6] Track 5.2 — MCP Server 2.0: Expanded Agentic Control Plane [merged]
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
