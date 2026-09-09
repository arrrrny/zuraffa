# TDD Cycle Log — Spec 1354 simulate scenario subcommands honor the pinned feature

Append-only loop evidence: one entry per red→green transition, recorded by
the LLM-guided loop (the zuraffa repo itself is not zuraffa-wired — no
`.zfa.json` — so `zfa tdd run` cannot drive it; the fallback loop records
here honestly).

## Baseline (2026-09-09)

- feature: 1354-simulate-positional-scenario
- branch: 1354-simulate-positional-scenario
- list: tdd/test-list.md (B1–B8, all PENDING)
- red protocol: `dart test test/simulation/worlds/simulate_worlds_command_test.dart`

## RED (2026-09-09) — B1–B8, pre-fix

- command: `dart test test/simulation/worlds/simulate_worlds_command_test.dart --plain-name "issue #1354"`
- result: `+2 -6` — RED on B1 (bare init exits 2, `no --feature given`), B3
  (message names no pin step), B4 (missing pinned path unnamed), B5 (bare
  run/certify/verify-world exit 2), B7 (malformed pin not named), B8 (no
  pin wording in help).
- GREEN pre-fix (guards, as declared in the red protocol): B2, B6 — the
  explicit and parent-level flags already work; the pin is simply ignored.

## GREEN (2026-09-09) — B1–B8 done

- fix: `_resolveFeature` pin fallback (explicit flag > `.specify/feature.json`
  `feature_directory` > honest usage error; dangling pin named, malformed pin
  named, never a specs/ scan) + `--feature` help text on all four subcommands
  documenting the pinned default.
- command: `dart test test/simulation/worlds/simulate_worlds_command_test.dart`
- result: `+25 All tests passed!` (B1–B8 + the 17 pre-existing spec-968 tests).
- B1: bare init + pin → GREEN, manifest byte-identical to the explicit twin.
- B2/B6: explicit and parent-level flags keep precedence over the pin.
- B3: no flag + no pin → exit 2 naming both inputs and the fix (no
  "positional ignored" wording).
- B4: dangling pin → exit 2 naming the missing directory.
- B5: bare run/certify/verify-world → GREEN twins (receipts agree).
- B7: malformed pin → exit 2 naming the malformed file (no crash).
- B8: `simulate init --help` documents the pinned-feature default.

## Regression pin (2026-09-09)

- `dart test test/simulation/simulate_command_test.dart
  test/commands/simulate_skin_command_test.dart test/simulation/worlds/`
  → `+123 All tests passed!`
- `dart analyze` on the touched files → No issues found.
- `dart format` → zero remaining diffs.
