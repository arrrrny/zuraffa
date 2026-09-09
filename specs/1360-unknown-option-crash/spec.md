**Template Version**: `zuraffa-1.0`

# Spec: 1360-unknown-option-crash

GitHub issue: arrrrny/zuraffa#1360 (labels: verify-misfire, missing-integration)
Epic: #1136 Phase B exit criterion 1

## Summary

`zfa simulate run --world=v3` crashed with `❌ Error: Null check operator
used on a null value` (exit 1) instead of a clean usage error. Root cause:
args 2.7.0's `CommandRunner.parse` error path resolves the exception's
command chain via `commands[...]!` / `subcommands[...]!` — but `run` is
registered parser-only (`argParser.addCommand`, the bug #856 grammar that
keeps the legacy flag surface reachable), so `Command.subcommands` cannot
resolve it and the `!` fires. The same crash shape is reachable for any
undeclared option on any parser-only subcommand.

The epic's second half — "no payment-failure feature exists in specs/" and
"no v3 versioned-world concept" — is an epic-contract matter, not a code
gap: worlds are keyed by scenario + feature with a world-hash in the run
receipt (the determinism criterion's implemented signature); there is no
`--world=<vX>` versioned-world surface to declare. This spec fixes the
crash; the epic contract note is recorded in the PR and issue.

## Locked decisions

1. Fix in our runner: `_CrashSafeCommandRunner.parse` override — on the
   TypeError from the library's `!`-crash, re-derive the original
   ArgParserException and walk the command chain DEFENSIVELY (runner
   `commands`, then Command `subcommands`, stopping at the deepest
   resolvable command), then throw the standard `usageException`.
2. Any TypeError that survives a clean re-parse is rethrown untouched
   (the override must never swallow unrelated crashes).
3. No flag is declared for `--world`; no scenario/world versioning is
   invented. Exit codes: 2 (usage) for unknown options, unchanged
   elsewhere.
4. SPEC 917 fix-line protocol holds on the usage error path.

## Functional requirements

- **FR-1 (clean refusal)**: an undeclared subcommand-level option
  (`zfa simulate run --world=v3`) exits 2 with
  `Could not find an option named "--world"` + the command usage — never
  the null-check crash.
- **FR-2 (parent-level unchanged)**: an undeclared parent-level option
  keeps its (already clean) usage refusal.
- **FR-3 (no regression)**: valid invocations (help, scenario runs,
  legacy flag surface) behave exactly as before.

## Acceptance scenarios (measurable)

1. `zfa simulate run --world=v3` → exit 2, clean message, usage, the
   `--> fix:` line, and NO "Null check operator" text.
2. `zfa simulate --world=v3` → exit 2 clean (guard).
3. `zfa simulate --help` → exit 0 (guard).

## Success criteria

- **SC-001**: The epic verify agent invoking `--world=v3` receives the
  honest usage refusal instead of a crash.
- **SC-002**: The cli suites stay green.

## Assumptions

- Versioned worlds (`--world=vX`) and a payment-failure fixture are
  epic-contract decisions (recorded, not built here); the implemented
  world signature is scenario+feature keyed with world-hash receipts.
