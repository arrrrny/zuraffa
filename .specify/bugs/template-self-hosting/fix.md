# Bug Fix: template-self-hosting (issue #912)

- **Slug**: template-self-hosting
- **Branch**: `fix/template-self-hosting`
- **Issue**: #912
- **Status**: applied

## Summary

1. **Apostrophe Escaping**: `BehaviorTestWriter` escapes apostrophes in the behavior description before rendering into persistence tests (`lib/src/plugins/tdd/services/behavior_test_writer.dart`).
2. **Package URI Import Rewriting**: `MigratePathsCommand` (`lib/src/plugins/tdd/commands/migrate_paths_command.dart`) rewrites package-URI subpaths when moving tests and subjects from flat layout to namespaced layout.
3. **Tests**: Added `test/plugins/tdd/bug_912_template_self_hosting_test.dart` asserting behaviors A1 and A2.

## Verification

- `dart test test/plugins/tdd/bug_912_template_self_hosting_test.dart` -> 2/2 passed.
- `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/` -> Clean (0 issues).
