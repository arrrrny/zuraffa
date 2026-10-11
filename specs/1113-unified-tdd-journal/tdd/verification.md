# TDD Verification — feature `1113-unified-tdd-journal`

Written from the ACTUAL runs performed on this branch (every command below
was executed; outputs are quoted from the transcripts, not asserted).
Toolchain: Dart 3.13.0 (stable) on linux_x64 (`dart --version`). Flutter is
not installed in this environment — the pure-Dart CLI lanes and the fast
suite run without it; Flutter-dependent tiers are out of scope here.

## Gate

- gate: `passed`
- analyze: `dart analyze lib test` → **0 errors, 0 warnings** (104 info-level
  lints, all pre-existing in untouched files — `lib/tdd/0966-*` subject
  naming, simulation type-literal idioms)
- fast suite (chunked): `tools/run_chunks_range.sh` over the whole chunk
  list, six foreground ranges 1-15 … 76-90 (the environment reaps detached
  processes, so the run was driven in foreground ranges — the spec-1110
  discipline) → **90/90 chunks, 0 failed, 3,556 tests passed** across the
  84 chunks that carry fast-tier suites (6 report the runner's SKIP: no
  fast-tier tests)
- slow tier (targeted, `--preset=all`, this spec's surface):
  `dart test --preset=all test/plugins/tdd/unified_journal_commands_test.dart
  test/plugins/tdd/two_cycle_run_commands_test.dart test/plugins/tdd/theater/
  test/plugins/tdd/services/journal_test.dart` → **65/65 passed** in one
  invocation (03:02, "All tests passed!")
- adjacent slow suites re-proved green: `run_command_test.dart` +
  `run_engine_command_test.dart` → 61/61; `commands/run_skin_command_test.dart`
  → 5/5; `json_flag_test.dart` + `tdd_command_smoke_test.dart` → 23/23;
  `bug_828_cycle_log_evidence_integrity_test.dart` → 7 passing + **4
  pre-existing master-HEAD reds** (the doctor group's `--feature` usage
  error — verified IDENTICAL on a pure-master `git stash` run, untouched by
  this branch); `scenarios/` → pre-existing master-HEAD reds (same
  pure-master verification, identical failure list)
- format: `dart format .` → first pass formatted the spec's new files;
  second run → `Formatted 2377 files (0 changed)` (idempotent; zero
  remaining formatting diffs)

## Red → green evidence (the loop, honestly)

### RED (reproduced on the pre-change tree)

The 12 command-level tests were written FIRST and run against the
pre-change tree:

```
$ dart test --preset=all test/plugins/tdd/unified_journal_commands_test.dart
  → 01:18 +0 -12: Some tests failed.
```

Every test failed for the honest reason the issue names: `zfa tdd prove`
did not exist ("Could not find a subcommand named prove" — the runner's
usage error), `specs/004-login-ui/tdd/journal.json` was never written
(File does not exist), and `zfa tdd status` printed no journal verdict
line. Recorded in `specs/1113-unified-tdd-journal/tdd/cycle-log.md`
(`## Cycle: J-001..J-012 (red)`).

### The bug the red phase forced out (the honest engineering note)

The first green run failed 2/12 with a symptom nobody predicted: the
engine-lane journal entry vanished between the engine lane and the meta
entry. Traced (debug script + writer tracing, since removed) to a
**pre-existing name collision**: the bug-#828 write-ahead transaction
marker (`TddTransaction`) already wrote `tdd/journal.json` — `begin()`
overwrote it before every step and `clear()` deleted it after every
commit, so the unified entries were clobbered per-step. The fix renamed
the transaction marker to `tdd/transaction.json` (a more accurate name
for a write-ahead crash marker; its own test's path helper updated;
`JournalReader` reads a legacy transaction-shaped `journal.json` as an
EMPTY journal — honest pending state, never a corrupt one). After the
rename: all 12 green.

### GREEN

```
$ dart test --preset=all test/plugins/tdd/unified_journal_commands_test.dart
  → 01:18 +12: All tests passed!
$ dart test test/plugins/tdd/services/journal_test.dart
  → 00:00 +17: All tests passed!
$ dart test --preset=all test/plugins/tdd/theater/
  → 00:01 +15: All tests passed!   (12 pre-existing + 3 new integration)
```

Recorded in `tdd/cycle-log.md` (`## Cycle: J-001..J-014 (green)`).

## Success criteria — PROVED vs not

1. **`zfa tdd run 004-login-ui` writes `tdd/journal.json` schema-valid** —
   PROVED. J-001/J-002/J-007: the meta run writes `journal.json`
   (schema 1, feature, entries); every entry passes the 9-required-field
   walk (cycle/phase/gate_state enums, refs triple, ISO-8601 stamps);
   `journal.schema.json` (draft 2020-12, generated from the model) lands
   beside it on first append.
2. **`zfa tdd status 004-login-ui` prints the one-line verdict from the
   journal, exit 0 on green** — PROVED. J-008: the merged machine line
   (`status: feature=... engine=green skin=green`) plus the journal
   verdict line (`004-login-ui | engine ✅ 3/3 | skin ✅ 3/3 (0 platforms)
   | mocks 0/0 certified | 0 violations`), sourced via JournalReader;
   exit 0. The pre-existing two-cycle status contract (absent/red/error
   verdicts, exit codes) re-proved by `two_cycle_run_commands_test.dart`
   21/21.
3. **`zfa tdd prove 004-login-ui` after editing one skin view reports only
   the changed behavior ungated** — PROVED. J-009/J-010: baseline prove on
   a green feature is clean (`ungated=0`, exit 0, prove entry journaled
   with fingerprints); after editing ONLY W1's subject file, prove reports
   `ungated=1` naming W1 (exit 1, gate_state=red) and NOT U1/U2/W2/A1.
   J-011: no-evidence feature → every behavior ungated (not_assessed).
   J-012: unknown feature dir → misfire (exit 2).
4. **Theater, status, prove all use JournalReader — no journal file I/O
   in their code** — PROVED. `status_command.dart` and `prove_command.dart`
   contain zero journal file reads (the stream — entries, refs-followed
   receipts, cycle-log content, green evidence, behaviors, verdict — comes
   from `JournalReader.read()`; the only other reader in status is the
   spec-1110 refusal-receipt SERVICE, itself not a journal read).
   `theater_data.dart` loads the journal stream through JournalReader and
   parses the cycle-log CONTENT string with its rich timeline parser (the
   read happens in the reader, not the theater); the snapshot carries
   `journal` (entries + verdict) and the TUI status bar renders the
   verdict. J-012/J-013/J-014 (theater_journal_integration_test.dart)
   assert the snapshot's journal entries, verdict, and that the
   cycle-log content the theater renders equals the reader's stream.

Additional proofs beyond the criteria: the fail-fast engine red journals
the meta entry red with the stopped_at violation (J-004); the cert-gate
preflight refusal journals preflight_red with zero steps spawned (J-005);
run-engine/run-skin standalone runs append their own cycle entries
(J-006); the conformance-mode skin cycle (skin.v1 receipt) is journaled
with conformance-derived verdict/counts/platforms (U3.6); the legacy #828
transaction marker reads as an empty journal (U3.4).

NOT proved / out of scope here: a real sandbox end-to-end run against a
Flutter project (`~/zik_zak_test` is not present in this environment) —
the command-level coverage drives the real commands in-process over the
canonical `004-login-ui` fixture with the scripted fake zfa binary, the
same convention PR #1092's exit criteria used.

## Post-merge re-proof (master moved mid-PR)

Master advanced past this branch's clone base (PRs #1220, #1213, #1212,
#1205 — 122 files, no overlap with this spec's files). The branch merged
master (`00e0b6f7`) and re-proved the spec's gates after the merge:

- `dart analyze lib test` → 0 errors, 0 warnings (104 pre-existing
  info lints, unchanged)
- combined spec suites (`unified_journal_commands_test` +
  `journal_test` + `theater/` + `two_cycle_run_commands_test`) →
  **65/65 passed** (03:04, "All tests passed!")
- driver suites (`run_command_test` + `commands/run_engine_command_test`
  + `commands/run_skin_command_test`) → **66/66 passed** (05:31, "All
  tests passed!")
- `dart format .` → `Formatted 2411 files (0 changed)` (idempotent;
  zero remaining formatting diffs)
