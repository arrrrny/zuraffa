# Bug Issue: bug: SmartMergeWriter crashes with PathNotFoundException when target file doesn't exist

- **Slug**: issue-248-bug-smartmergewriter-crashes-with-pathnotfoundexception-when
- **Fetched**: 2026-08-22T19:42:20.566186+00:00
- **Issue**: 248
- **URL**: https://github.com/arrrrny/zuraffa/issues/248
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, test

## Body

## Summary

`SmartMergeWriter.writeMerged` crashes with `PathNotFoundException` when the target file does not exist yet.

Test: `test/smart_merge_test.dart` → `SmartMergeWriter creates file when no existing content` on `development` @ `c25894f`.

## Error

```
PathNotFoundException: Cannot open file, path = '.../smart_merge_test_DDhi3g/test.dart' (OS Error: No such file or directory, errno = 2)
dart:io                                                             _File.readAsString
package:zuraffa/src/core/context/file_system.dart 40:32             DefaultFileSystem.read
package:zuraffa/src/core/transaction/smart_merge_writer.dart 22:48  SmartMergeWriter.writeMerged
test/smart_merge_test.dart 24:30                                    main.<fn>.<fn>
```

## Root cause

`SmartMergeWriter.writeMerged` (`lib/src/core/transaction/smart_merge_writer.dart:22`) calls `DefaultFileSystem.read(...)` **before** checking whether the target file exists. When the file is new, the read throws instead of treating it as "nothing to merge — write fresh".

## Expected behavior

If the target file does not exist, `writeMerged` should write the new content directly (no merge needed) without reading.

## Repro

```bash
flutter test test/smart_merge_test.dart
```


## Comments

**coderabbitai** (2026-08-04T16:29:00Z):

<!-- This is an auto-generated issue plan by CodeRabbit -->
<details>
<summary>🔗 Related PRs</summary>

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
