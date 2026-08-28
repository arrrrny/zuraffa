# Fix — zfa-setup-bootstrap-gaps

- **Slug**: zfa-setup-bootstrap-gaps
- **Status**: fixed
- **Date**: 2026-08-28
- **PR**: (shared with zfa-setup-no-git-init — see below)

## Root cause

`DependencyWirer` hardcoded the analyzer/meta `dependency_overrides` versions
as literal constants (`analyzerOverrideVersion = '14.1.0'`,
`flutterAnalyzerOverrideVersion = '^13.1.0'`, `flutterMetaOverrideVersion =
'^1.19.0'`). These can silently drift out of sync with the versions
`zuraffa` / `zuraffa_flutter` actually declare in their own `pubspec.yaml`.

## Fix

Added `DependencyWirer.resolvePackageOverrides(packageName, {projectRoot})`,
which reads the resolved package's `dependency_overrides` from
`.dart_tool/package_config.json` → package root → `pubspec.yaml`, returning a
`Map<String,String>`. It returns an empty map when resolution is unavailable
(no `package_config.json` yet, offline, package not resolved), so callers fall
back to the existing constants.

`wire()` now prefers the resolved version when writing each override
(`resolved[spec.name] ?? spec.version`), so bootstrapped apps stay in sync with
the real package versions instead of stale literals.

`standardSet` / `findMissing` are intentionally **unchanged** (still pure and
constant-based) so the existing unit tests stay green and exact-version drift
detection in `findMissing` continues to work. In practice the resolved values
equal the constants today, so the fresh-bootstrap path is unchanged; the
resolver engages on subsequent runs / `zfa init` against an existing project
where the package is already resolvable.

## Verification

- `test/core/dependencies/dependency_wirer_test.dart` (group
  `resolvePackageOverrides`): reads overrides from a synthetic
  `package_config.json`; returns empty when config missing / package absent.
- `dart test test/core/dependencies/dependency_wirer_test.dart` → all pass.
- `dart analyze lib` → no errors.
