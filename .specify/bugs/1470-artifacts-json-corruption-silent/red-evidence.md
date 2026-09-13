# RED evidence — Bug #1470 (pre-fix, this session)

Branch `fix/1470-artifacts-json-corruption-silent`, parent of the fix
commit. Dart 3.13.3 (stable) on linux_x64.

## 1. Behavioral probe (pre-fix code)

`tool/bug1470_red_probe.dart` (throwaway, since removed; output preserved
here verbatim): seeds a valid two-record registry (B-001, B-002), corrupts
the file on disk, then exercises the pre-fix read/register paths:

```
RED-1 loadAll() on a CORRUPT registry returned 0 records with no exception (identical to a missing file).
RED-2 register(B-003) returned ownership test=Ownership.created subject=Ownership.created (no corruption diagnosed).
RED-3 registry file after register() now holds [B-003] — B-001/B-002 ownership records silently destroyed: true.
```

This is the issue's exact symptom chain: corrupt file read as empty →
re-registration with `Ownership.created` → registry rewrite destroying
surviving ownership records (duplicate-file/data-loss exposure).

## 2. Committed test (pre-fix)

The committed suite
`test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart`
references `ArtifactRegistryCorruptException`, which pre-fix does not
exist — the honest compile-level RED:

```
00:00 +0 -1: loading test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart [E]
  Failed to load "test/plugins/tdd/services/bug_1470_artifacts_json_corruption_test.dart":
  ...: Error: 'ArtifactRegistryCorruptException' isn't a type.
  ...: Error: Method not found: 'containsIgnoringCase'.
00:00 +0 -1: Some tests failed.
```

(The `containsIgnoringCase` error was a test-side matcher mistake, fixed
before GREEN; it is not part of the behavioral claim.)

Together: probe output proves the silent behavior; the compile failure
proves the fix's public surface did not exist. GREEN evidence in
`test.md` shows the same suite passing 5/5 after the fix.
