# Bug Fix PR: `make --with=view` produces no view file in the xray default test

- **Slug**: make-xray-default-view-generation
- **Opened**: 2026-08-23
- **PR**: 467
- **URL**: https://github.com/arrrrny/zuraffa/pull/467
- **Branch**: fix/make-xray-default-view-generation
- **Issue**: n/a (related: #360)

Test-only fix: add `flutter:` to the xray-default test's temp pubspec so the view
plugin generates views in the Flutter-flavored temp project. Merged into master.
