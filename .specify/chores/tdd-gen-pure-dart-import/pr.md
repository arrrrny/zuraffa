# Chore PR: Fix TDD gen Flutter detection for pure Dart projects

- **Slug**: tdd-gen-pure-dart-import
- **Opened**: 2026-09-10
- **PR**: 1461
- **URL**: https://github.com/arrrrny/zuraffa/pull/1461
- **Branch**: chore/tdd-gen-pure-dart-import
- **Issue**: 1458

Fixes _isFlutterProject() to use YAML parsing instead of substring matching, preventing false positives from "flutter" in pubspec comments.
