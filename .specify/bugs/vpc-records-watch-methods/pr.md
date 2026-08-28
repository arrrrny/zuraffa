# Bug Fix PR: `vpc_records_test` fails — VPC watch-record generation skipped in pure-Dart test project

- **Slug**: vpc-records-watch-methods
- **Opened**: 2026-08-23
- **PR**: 468
- **URL**: https://github.com/arrrrny/zuraffa/pull/468
- **Branch**: fix/vpc-records-watch-methods
- **Issue**: n/a

Test-only fix: add `flutter:` to the vpc_records test's temp pubspec so the
presenter/controller plugins generate the Record-based watch methods. Merged into
master.
