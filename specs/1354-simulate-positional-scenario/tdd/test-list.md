# TDD Test List — Spec 1354 simulate scenario subcommands honor the pinned feature

One behavior per line, traced to the acceptance scenarios / FRs in spec.md.
Every behavior is written as a failing test FIRST (RED), then made to pass
(GREEN). Red for this feature: pre-fix, every bare invocation dies with
`no --feature given --> fix: pass --feature <name-or-dir>` (exit 2) — the
issue #1354 signature — and no pin mention exists in help text.

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | `zfa simulate init test_world` with a live `.specify/feature.json` pin scaffolds the world under the PINNED feature: exit 0, `SIMULATE init -> GREEN`, manifest + certification receipt at `specs/<pinned>/tdd/worlds/test_world.world.json`, byte-identical to the explicit-`--feature` twin scaffolded from the same table | FR-1 / AS-1 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B2 | Explicit `--feature B` beats a pin naming feature A: the manifest lands under B only; A has no worlds directory | FR-2 / AS-2 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B3 | No `--feature` and no `.specify/feature.json`: exit 2 (usage), the error names BOTH missing inputs and the fix (no "positional ignored" wording), and nothing is written under `specs/` | FR-4 / AS-3 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B4 | Pin pointing at a non-existent directory: exit 2 (usage), the error names the missing pinned path (honest refusal — never a specs/ scan) | FR-4 / AS-4 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B5 | Bare `run`, `certify`, and `verify-world` each resolve the pin and match their explicit twins (verdict lines + exit codes) | FR-3 / AS-5 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B6 | Parent-level `zfa simulate --feature <f> init <scenario>` still resolves `<f>` (bug #856 dispatch + parent-flag regression guard) | FR-5 / AS-6 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B7 | A malformed `.specify/feature.json` degrades to "no pin" — same honest usage refusal as B3, never a crash | FR-4 | test/simulation/worlds/simulate_worlds_command_test.dart |
| B8 | The scenario subcommands' `--feature` help documents the pinned-feature default (help output contains the pin wording) | FR-5 | test/simulation/worlds/simulate_worlds_command_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
dart test test/simulation/worlds/simulate_worlds_command_test.dart   # B1-B8 (CLI tier)
```

Expected RED evidence (pre-fix): B1 — `no --feature given` (exit 2) instead
of GREEN + manifest. B2 — RED: the pin path is unimplemented so the run
refuses instead of preferring B. B3/B4 — GREEN on exit code 2 (the refusal
already happens) but RED on the message assertions (pre-fix text claims the
positional was ignored and names no resolution steps). B5 — RED: bare run/
certify/verify-world refuse with exit 2 instead of matching their twins.
B6 — GREEN pre-fix (the parent flag already works; regression guard).
B7 — RED: pre-fix refuses (exit 2) so the equality-with-absent-pin
assertion may hold on the code path but the behavior is pinned to catch a
crash regression when the pin reader lands. B8 — RED: no pin wording in
help output pre-fix.
