# Test — zfa-setup-bootstrap-gaps

- **Slug**: zfa-setup-bootstrap-gaps
- **Result**: verified
- **Date**: 2026-08-28

## Tests added

`test/core/dependencies/dependency_wirer_test.dart` (group
`resolvePackageOverrides`):

- `reads dependency_overrides from the resolved package`
- `returns empty when package_config.json is missing`
- `returns empty when the package is not in the config`

## Command

```
dart test test/core/dependencies/dependency_wirer_test.dart
```

Result: All tests passed.
