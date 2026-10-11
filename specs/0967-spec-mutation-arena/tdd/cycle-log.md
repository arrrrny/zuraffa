# Cycle Log — 0967-spec-mutation-arena

Red → green evidence for the spec-mutation arena feature. Every command
below was executed by this session; outputs are the real captures.

## RED (before any implementation existed)

### CLI repro — the command does not exist

```
$ dart run bin/zfa.dart spec fuzz 0967-spec-mutation-arena
❌ Could not find a command named "spec".

Did you mean one of these?
  sync
```

Exit code: **64** (`dart run bin/zfa.dart spec fuzz x; echo $?` → `64`).
`dart run bin/zfa.dart spec --help` → same refusal, exit 64.
`zfa --help` lists no `spec` top-level command. No mutation operators
exist anywhere; no spec-fuzz report machinery; spec quality unverified —
the issue's exact gap.

### Test-first evidence — the four suites fail for the right reasons

| Suite | Pre-implementation failure (captured) |
| ----- | ------------------------------------- |
| `test/plugins/tdd/services/spec_mutator_test.dart` | `Error: Method not found: 'validateSpecContract'` (and the missing `spec_mutator.dart` import) — loading failure, 0 tests ran |
| `test/plugins/tdd/services/spec_fuzz_auditor_test.dart` | `Error when reading 'lib/src/plugins/tdd/models/spec_mutation.dart': No such file or directory` — 0 tests ran |
| `test/commands/spec_fuzz_command_test.dart` | `Actual: '❌ Could not find a command named "spec".\n'` / `Could not find an option named "--operators"` — every registration + usage test red |
| `test/plugins/tdd/spec_fuzz_demo_test.dart` | same missing-module loading failure — 0 tests ran |

Command: `dart test <file>` (fast tier) — `+0 -1` on every file, all
failing BEFORE the implementation landed.

## GREEN (after the implementation)

| Suite | Result (real run) |
| ----- | ----------------- |
| `dart test test/plugins/tdd/services/spec_mutator_test.dart` | `+25: All tests passed!` |
| `dart test test/plugins/tdd/services/spec_fuzz_auditor_test.dart` | `+11: All tests passed!` |
| `dart test test/commands/spec_fuzz_command_test.dart` | `+12: All tests passed!` |
| `dart test --preset=integration test/plugins/tdd/spec_fuzz_demo_test.dart --plain-name "the weak spec survives the green loop…"` | `00:32 +1: All tests passed!` (REAL `dart test` spawns) |
| `dart test --preset=integration test/plugins/tdd/spec_fuzz_demo_test.dart --plain-name "corpus mode walks a cataloged corpus…"` | `00:20 +1: All tests passed!` (REAL spawns) |
| `bash tools/spec_fuzz_demo.sh` (the CI gate, end to end) | `✓ the weak feature is green … ✓ spec fuzz flagged the weak spec: survived=6 (exit 1, certified=false) … ✓ spec.md restored byte-exactly … ✓ the strengthened spec kills all mutants (exit 0, certified=true) … ✓ deterministic replay: same seed, byte-identical report` |

## The seeded weakness demo (acceptance criterion 1), captured

Weak round (real processes, no injection):

```
spec-fuzz: feature=demo-greeter mutations=6 killed=0 survived=6
not_assessed=0 ... fuzz_was_run=true certified=false
```

- exit code 1 (survived > 0)
- `.zfa/corpus/gap-ledger.json`: 6 entries, every one
  `severity: contract`, `expected_result: pass`,
  `behavior: SM-###` (survived mutations are ledger gaps)
- `specs/demo-greeter/tdd/spec-fuzz.json` + `.md` written
- `spec.md` restored byte-exactly (sha256-verified restoration)

Strengthened round (same implementation, pinned spec):

```
spec-fuzz: feature=demo-greeter mutations=13 killed=13 survived=0
not_assessed=0 ... fuzz_was_run=true certified=true
```

- exit code 0
- re-running the round reproduces `spec-fuzz.json` byte-identically
  (deterministic given the seed)

## Refactor

None required (the operators stayed pure; the auditor mirrors
MutationAuditor's seams). The `dart format .` pass rewrote 8 of the 10
new files cosmetically; both suites re-ran green afterwards.
