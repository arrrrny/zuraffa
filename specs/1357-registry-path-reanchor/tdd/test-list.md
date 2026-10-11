# TDD Test List — Spec 1357 registry path re-anchor

Red pre-fix: loadAll returns stored paths verbatim — absolute sandbox
paths come back absolute (B1/B5 red); verbatim-pass behaviors are guards
(B2/B3/B4 green pre-fix by design).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | A registry with sandbox-absolute `/home/z/...` paths loads with repo-relative `test/...`/`lib/...` paths and a re-anchored `runnable_test_name` prefix | FR-1 / AS-1 | test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart |
| B2 | An absolute path that exists on disk is kept verbatim | FR-2 / AS-2 | test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart |
| B3 | An absolute path with no resolvable suffix passes through verbatim | FR-2 / AS-3 | test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart |
| B4 | Relative paths pass through untouched | FR-2 / AS-4 | test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart |
| B5 | `MutationScope.derive` over the healed registry yields existing test paths | FR-3 / AS-5 | test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart |

## Red protocol

```
dart test test/plugins/tdd/bug_1357_registry_path_reanchor_test.dart
```
Expected RED (pre-fix): B1, B5. Guards green pre-fix: B2, B3, B4.
