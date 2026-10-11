# Bug Issue: bug_828 doctor tests invoke `tdd doctor --feature`, but the command takes the feature positionally — 4 tests fail with a usage error (pre-existing at 8407bf2b)

- **Slug**: tdd-doctor-feature-positional
- **Fetched**: 2026-09-13
- **Issue**: 1585
- **URL**: https://github.com/arrrrny/zuraffa/issues/1585
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Summary

4 of the 13 tests in `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` fail with a CLI usage error, because the suite's `doctor()` helper invokes `zfa tdd doctor --feature <name>`, while `tdd doctor` takes the feature **positionally** and declares only `--json` / `--project`.

## Command

```bash
dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart
```

## Expected

`13/13` green.

## Actual

```
01:23 +9 -4: Some tests failed.

Failing tests:
  test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart: versioned evidence schema with per-behavior hash chain bug 828 RED: doctor detects a tampered hash chain and prescribes a fix
  test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart: zfa tdd doctor (drift reporting with fix lines) bug 828 RED: a pending journal is reported as an interrupted transaction with a fix line
  test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart: zfa tdd doctor (drift reporting with fix lines) bug 828 RED: doctor exits 0 on consistent stores
  test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart: zfa tdd doctor (drift reporting with fix lines) bug 828 RED: doctor reports a green claim without evidence as drift and prescribes the resume fix
```

The captured CLI output is the `tdd doctor` usage text:

```
  --json       Emit a versioned verdict.v1 JSON envelope as the final stdout line (VISION §5, issue #969).
  --project    Project root containing specs/, test/, and lib/. When omitted, the current working directory is used.

Run "zfa help" to see global options.
  --> fix: re-run with --help to list the valid flags and subcommands, then re-invoke
```

so the assertion at `bug_828_cycle_log_evidence_integrity_test.dart:429` (`expect(exitCode, 1, reason: out)`) fails on the usage-error exit instead of the doctor verdict.

## Root cause

`test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart:42-52`:

```dart
Future<String> doctor() async {
  final runner = CliRunner(exitOnCompletion: false);
  return runner.runCapturing([
    'tdd', 'doctor', '--feature', feature, '--project', fx.root.path,
  ]);
}
```

but `lib/src/plugins/tdd/commands/doctor_command.dart` registers only `--json` (line 76) and `--project` (line 83) and reads the feature from the positionals:

```dart
final rest = argResults?.rest ?? const <String>[];
if (rest.isEmpty) {
  usageException('Feature name is required: zfa tdd doctor <feature>');
}
...
featureRef: rest.first,
```

`invocation` is `zfa tdd doctor <feature> [--project <path>]`. `--feature` is therefore rejected by the arg parser, the command prints usage, and the test never reaches the drift logic.

## Suggested fix

Pass the feature positionally in the helper:

```dart
'tdd', 'doctor', feature, '--project', fx.root.path,
```

## Repro / scope

Reproduces identically at `8407bf2b` (the base of PR #1566) **with and without** that PR's changes — it is pre-existing here, not a regression from #1566. Sibling of #1573 (`tdd doctor` / flag-vs-positional drift in the same command family).

## Comments

None.
