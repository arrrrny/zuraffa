# Bug Fix PR: zfa build: passes --fatal-infos a value → analyzer fails on flag → false 'no errors'

- **Slug**: issue-415-zfa-build-passes-fatal-infos-a-value-analyzer-fails-on-flag
- **Opened**: 2026-08-22T19:49:00+00:00
- **PR**: 443
- **URL**: https://github.com/arrrrny/zuraffa/pull/443
- **Branch**: fix/issue-415-fatal-infos-flag
- **Issue**: 415

Removed the rejected `--fatal-infos=false` flag from `BuildCommand.verifyAnalyzeOrFail` so the post-build `dart analyze` guard runs and correctly detects errors. Merged via squash; issue #415 auto-closed.
