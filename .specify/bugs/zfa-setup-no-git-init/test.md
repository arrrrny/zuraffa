# Test — zfa-setup-no-git-init

- **Slug**: zfa-setup-no-git-init
- **Result**: verified
- **Date**: 2026-08-28

## Tests added

`test/commands/setup_command_test.dart`:

- `SetupCommand exposes --no-git flag`
- `SetupCommand git init / initializeGit creates .git in a fresh directory`
- `SetupCommand git init / initializeGit skips when --no-git is set`
- `SetupCommand git init / initializeGit is idempotent when .git already exists`
- `SetupCommand git init / dry-run prints git init intent without touching the filesystem`
- `SetupCommand run (dry-run) / prints git init intent during dry-run bootstrap`

## Command

```
dart test test/commands/setup_command_test.dart
```

Result: All tests passed.
