# RED evidence — SPEC 1132 (pre-fix, this session, master a9329746)

## Lane 1 — exit_code_sweep_1132_test.dart (in-process, e2e tier)
```
00:00 +2 -6: SPEC 1132 L1 — bare invocations exit usage (2), not 0 `zfa migrate <unknown>` prints usage and exits 2 [E]
00:00 +2 -6: SPEC 1132 L1 — bare invocations exit usage (2), not 0 bare `zfa plugin` prints usage and exits 2
00:00 +2 -7: SPEC 1132 L1 — bare invocations exit usage (2), not 0 bare `zfa plugin` prints usage and exits 2 [E]
00:00 +2 -7: SPEC 1132 L1 — bare invocations exit usage (2), not 0 `zfa plugin --help` still exits 0 (help is success)
00:00 +3 -7: Some tests failed.
Failing tests:
```

## Lane 2 — verdict_envelope_1132_test.dart
```
00:00 +0 -3: SPEC 1132 L2 — capability pre-flight refusal speaks verdict.v1 missing required args emit the canonical usage envelope
00:00 +0 -4: SPEC 1132 L2 — capability pre-flight refusal speaks verdict.v1 missing required args emit the canonical usage envelope [E]
00:00 +0 -4: SPEC 1132 L2 — capability pre-flight refusal speaks verdict.v1 the old divergent shape breaks loudly, never parses silently
00:00 +1 -4: Some tests failed.
```

## Lane 3 — standalone_receipts_1132_test.dart
```
00:00 +0 -1: SPEC 1132 L3 — zfa skin kit ships a proof.v1 receipt skin kit writes the auditor kit AND a receipt covering it
00:00 +0 -2: SPEC 1132 L3 — zfa skin kit ships a proof.v1 receipt skin kit writes the auditor kit AND a receipt covering it [E]
00:00 +0 -2: SPEC 1132 L3 — zfa skin kit ships a proof.v1 receipt a skipped kit (exists, no --force) ships NO receipt (#769)
00:00 +1 -2: Some tests failed.
```

## Lane 4 — openwiki_cli_docs_1132_test.dart (compile red: parser module absent)
```
  test/commands/openwiki_cli_docs_1132_test.dart:6:8: Error: Error when reading 'lib/src/docs/openwiki_cli_docs.dart': No such file or directory
  test/commands/openwiki_cli_docs_1132_test.dart:42:21: Error: Method not found: 'parseCommandNames'.
  test/commands/openwiki_cli_docs_1132_test.dart:72:21: Error: Method not found: 'parseCommandNames'.
  test/commands/openwiki_cli_docs_1132_test.dart:82:14: Error: Method not found: 'parseCommandNames'.
```
