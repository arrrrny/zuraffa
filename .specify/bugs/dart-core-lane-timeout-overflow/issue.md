# Bug Issue: dart_core CI job cancelled at the 30-minute ceiling

- **Slug**: dart-core-lane-timeout-overflow
- **Reported**: 2026-09-15T11:02:00Z
- **Issue**: 1632
- **URL**: https://github.com/arrrrny/zuraffa/issues/1632
- **Severity**: high

Filed the dart_core fast-lane overflow bug: the pure-Dart CI lane cancels at the 30-minute job ceiling on every recent run because ~116 never-tagged heavyweight (spawn/analyzer-compile) suites plus a serial-execution residual overflow it; fix is tier-honest `slow`/`e2e` tagging + scoped `--concurrency=4` + a structural budget pin, targeting a sub-8-minute test step. (`severity:high` label does not exist in this repo — issue filed with `bug` only.)
