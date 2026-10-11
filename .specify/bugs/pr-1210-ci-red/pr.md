# Bug Fix PR: issue_891 regression test flips to post-#1206 zero-overrides contract

- **Slug**: pr-1210-ci-red
- **Opened**: 2026-09-06
- **PR**: 1218
- **URL**: https://github.com/arrrrny/zuraffa/pull/1218
- **Branch**: fix/pr-1210-ci-red
- **Issue**: 1211

Rewrites `test/regression/issue_891_example_meta_resolution_test.dart` to the
post-#1206 contract (zero `dependency_overrides` in `example/pubspec.yaml`,
delegation guard on `tools/flutter_smoke_gate.sh`), turning master's red
`dart_core` lane green. `Closes #1211` included.
