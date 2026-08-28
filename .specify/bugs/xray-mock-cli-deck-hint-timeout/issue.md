# Bug Issue: `zfa xray mock`→`deck` CLI integration test hard-times-out on Linux

- **Slug**: xray-mock-cli-deck-hint-timeout
- **Reported**: 2026-08-28
- **Issue**: 531
- **URL**: https://github.com/arrrrny/zuraffa/issues/531
- **Severity**: medium

Filed the Linux hard-timeout of `test/commands/xray_mock_cli_test.dart` ("next-step deck hint
includes the required --source") as a CI-reliability/test-hang bug. Root cause: no child-process
timeout in `runZfaSource` (`test/helpers/run_zfa_source.dart:41-51`) combined with heavy per-
invocation `PluginLoader.buildRegistry()` startup (`lib/src/cli/cli_runner.dart:49-92`) under
parallel `dart test -j 4`, pushing a spawned `dart` VM past the 2-minute group timeout on
CPU-constrained Linux runners. Label `bug` applied; no `severity:*` labels exist in the repo,
so severity was not set as a label.
