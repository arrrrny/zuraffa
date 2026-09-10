# TDD Test List — Spec 1383

Red pre-fix: B1-B4 red — the doc did not exist.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | The generated fleet doc exists | FR-1 / AS-1 | test/docs/openwiki_cli_docs_test.dart |
| B2 | >=50 command sections | FR-1 | test/docs/openwiki_cli_docs_test.dart |
| B3 | Key fleet verbs documented | FR-2 | test/docs/openwiki_cli_docs_test.dart |
| B4 | Exit taxonomy + envelope contract documented | FR-3 | test/docs/openwiki_cli_docs_test.dart |

## Red protocol

```
dart test test/docs/openwiki_cli_docs_test.dart
```
