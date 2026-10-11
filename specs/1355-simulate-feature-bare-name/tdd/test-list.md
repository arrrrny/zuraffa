# TDD Test List — Spec 1355 simulate --feature bare-name resolves under specs/

One behavior per line, traced to the acceptance scenarios / FRs in spec.md.
Red for this feature: pre-fix, the bare-name repro exits 1 RED with
`FixtureMismatch ... manifest.json missing` (the issue #1355 signature);
the help text carries no bare-name wording.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | `zfa simulate --scaffold specs/<f>` then `zfa simulate --feature <f>` (bare name, CWD = workspace root) replays GREEN — exit 0, `SIMULATE golden -> GREEN`, plays counted | FR-1 / AS-1 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B2 | Path form `zfa simulate --feature specs/<f>` stays GREEN (regression guard) | FR-2 / AS-2 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B3 | Bare name with no `specs/<name>` → exit 1 RED naming `<name>/tdd/fixtures/manifest.json` (raw value as passed) | FR-3 / AS-3 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B4 | `zfa simulate --fixtures <dir>` (dir outside specs/) replays verbatim → GREEN | FR-2 / AS-4 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B5 | `zfa simulate --help` documents the bare-name rule (output contains the bare-name wording) | FR-4 | test/simulation/worlds/simulate_worlds_command_test.dart |

## Red protocol

```
dart test test/simulation/worlds/simulate_worlds_command_test.dart   # B1-B5 (CLI tier)
```

Expected RED evidence (pre-fix): B1 exits 1 RED with FixtureMismatch (the
issue signature). B2 GREEN pre-fix (regression guard). B3 GREEN pre-fix on
the verdict (RED expected — raw value already used) but RED is NOT
expected; it pins the honest miss. B4 GREEN pre-fix (guard). B5 RED (no
bare-name wording in help).
