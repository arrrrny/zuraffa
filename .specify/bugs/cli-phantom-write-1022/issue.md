# Bug Issue: [FLEET-ROT] Fix cli phantom write — smallest honesty fix

- **Slug**: cli-phantom-write-1022
- **Fetched**: 2026-09-04T00:00:00Z
- **Issue**: 1022
- **URL**: https://github.com/arrrrny/zuraffa/issues/1022
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

## Context
zfa cli Foo prints Generated: lib/src/cli/commands/foo_command.dart for a file that does not exist. Verified: cli_plugin.dart has zero writeFile/FileUtils calls.

## Deliverable
1. Add FileUtils.writeFile(path, content, "cli") to generateForEntity.
2. Update test/cli/standard/cli_plugin_generator_test.dart to assert file exists on disk.
3. Add cli_command.dart to compile gate (dart analyze).
4. Add receipt binding command to entity.

## Exit criterion
- zfa cli Foo writes a file that dart analyze accepts.
- zfa cli Foo writes a receipt in .zfa/receipts/.
- Test asserts on-disk existence, not just in-memory string.

## Comments

None.
