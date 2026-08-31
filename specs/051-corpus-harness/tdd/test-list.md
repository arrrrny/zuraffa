# Test List: `zfa tdd corpus` — batch driving, provenance audit, gap ledger

---
feature: 051-corpus-harness
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 12
planned_at: ffb2fc96
updated_at: ffb2fc96
suite_baseline: green
---

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature
works end to end through its real entry point (`zfa tdd corpus run`,
`zfa tdd corpus audit`, `zfa tdd corpus status`).

| id  | behavior                                                                            | traces  | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------- | ------- | ------- | ------- | ---- |
| A1  | `corpus run` drives each ready feature run-then-verify in manifest order, persists progress after each, and prints a per-feature + final summary | AC-1    | example | PENDING |      |
| A2  | `corpus run` interrupted after feature k resumes at k+1 without re-driving features 1..k | AC-2    | example | PENDING |      |
| A3  | `corpus run` stops non-zero on a feature failure, appends a gap ledger entry, and does not start later features | AC-3    | example | PENDING |      |
| A4  | A feature with a passing verify gate is marked corpus-done with the gate recorded    | AC-4    | example | PENDING |      |
| A5  | A feature with verify gate NOT_ASSESSED stops the run, appends a ledger entry, and is not counted done | AC-5    | example | PENDING |      |
| A6  | An explicit recorded waiver for a verify outcome is visible in corpus progress and final report, never silent | AC-6    | example | PENDING |      |
| A7  | `corpus audit` attributes every lib/ file to a recorded zfa invocation or carve-out entry, exits 0 on 100% | AC-7    | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::attributes lib/ files` |
| A8  | `corpus audit` exits non-zero naming every unattributed lib/ file                    | AC-8    | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::exits non-zero when unattributed` |
| A9  | Removing a carve-out entry makes the corresponding file unattributed and the audit fails | AC-9    | example | PENDING |      |
| A10 | `corpus status` reports per-state counts, resume point, and ledger totals read-only, changes nothing | AC-10   | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::reports per-state counts` |
| A11 | `corpus status` summary line exit 0 means all manifest features done+gated, non-zero means incomplete | AC-11   | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::exit non-zero when pending` |
| A12 | Concurrent corpus runs on the same app are refused via the corpus-level in-flight marker | AC-12   | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::refuses concurrent run` |

## Inner loop: unit behaviors

Grouped by the component from `plan.md` that owns them. Each line names one
observable result.

### `lib/src/plugins/tdd/services/corpus_progress_store.dart`

| id  | behavior                                                                        | traces     | kind    | state   | test |
| --- | ------------------------------------------------------------------------------- | ---------- | ------- | ------- | ---- |
| U1  | Saves and loads corpus progress atomically (temp+rename pattern)                | FR-001     | example | DONE    | `test/plugins/tdd/services/corpus_progress_store_test.dart::saves and loads` |
| U2  | Detects corrupt progress JSON and reports the recovery path                     | FR-010     | example | DONE    | `test/plugins/tdd/services/corpus_progress_store_test.dart::detects corrupt` |
| U3  | Refuses a second concurrent run when in-flight marker pid is alive             | FR-010     | example | DONE    | `test/plugins/tdd/services/corpus_progress_store_test.dart::refuses concurrent` |
| U4  | Allows resume when in-flight marker pid is dead                                | FR-010     | example | DONE    | `test/plugins/tdd/services/corpus_progress_store_test.dart::allows resume` |
| U5  | Computes resume point as first feature not in done/not-ready/dropped state     | FR-001     | example | DONE    | `test/plugins/tdd/services/corpus_progress_store_test.dart::computes resume point` |
| U6  | Tracks dropped features (removed from manifest after being driven)             | FR-001     | example | DONE    | `test/plugins/tdd/services/corpus_progress_store_test.dart::tracks dropped` |

### `lib/src/plugins/tdd/services/gap_ledger.dart`

| id  | behavior                                                                        | traces     | kind    | state   | test |
| --- | ------------------------------------------------------------------------------- | ---------- | ------- | ------- | ---- |
| U7  | Appends a ledger entry with all five required fields (feature, behavior, step, outcome, command) | FR-007     | example | DONE    | `test/plugins/tdd/services/gap_ledger_test.dart::appends entry with all five` |
| U8  | Append-only: past entries are never edited or removed                           | FR-007     | example | DONE    | `test/plugins/tdd/services/gap_ledger_test.dart::append-only` |
| U9  | Resolution entry appends alongside the original entry with same feature name    | FR-007     | example | DONE    | `test/plugins/tdd/services/gap_ledger_test.dart::resolution entry appends` |
| U10 | Ledger totals compute correctly: total, unresolved, filed, resolved, blocking  | FR-008     | example | DONE    | `test/plugins/tdd/services/gap_ledger_test.dart::ledger totals compute` |
| U11 | Atomic write via temp+rename prevents corruption on crash                       | FR-007     | example | DONE    | `test/plugins/tdd/services/gap_ledger_test.dart::atomic write prevents` |

### `lib/src/plugins/tdd/services/corpus_runner.dart`

| id  | behavior                                                                        | traces     | kind    | state   | test |
| --- | ------------------------------------------------------------------------------- | ---------- | ------- | ------- | ---- |
| U12 | Drives a ready feature through zfa tdd run then zfa tdd verify via sub-process  | FR-001     | example | DONE    | `test/plugins/tdd/services/corpus_runner_test.dart::drives ready feature` |
| U13 | Feature run exit non-zero stops the corpus, marks feature stopped, appends ledger | FR-002    | example | DONE    | `test/plugins/tdd/services/corpus_runner_test.dart::run failure stops` |
| U14 | Verify gate PASS marks feature done and records gate outcome                    | FR-004     | example | DONE    | `test/plugins/tdd/services/corpus_runner_test.dart::gate PASS` |
| U15 | Verify gate NOT_ASSESSED stops the run with ledger entry and reason             | FR-004     | example | DONE    | `test/plugins/tdd/services/corpus_runner_test.dart::NOT_ASSESSED stops` |
| U16 | Verify gate FAIL_SURVIVED/FAIL_TIMEOUT/PREFLIGHT_RED stops with ledger entry    | FR-004     | example | DONE    | `test/plugins/tdd/services/corpus_runner_test.dart::FAIL_SURVIVED stops` |
| U17 | Waived feature skips the gate failure and marks done with waiver record         | FR-004     | example | PENDING |      |
| U18 | Not-ready features are skipped and reported, never driven                       | FR-003     | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::skips not-ready features` |
| U19 | Corpus-level stop halts the whole run — later features are not started          | FR-002     | example | DONE    | `test/plugins/tdd/services/corpus_runner_test.dart::corpus stop halts` |
| U20 | Persists corpus progress after every feature                                   | FR-001     | example | DONE    | `test/plugins/tdd/services/corpus_runner_test.dart::persists progress` |
| U21 | Resumes from first incomplete feature on re-run, skipping done/not-ready/dropped | FR-001    | example | DONE    | `test/plugins/tdd/services/corpus_runner_test.dart::resumes from incomplete` |

### `lib/src/plugins/tdd/services/provenance_auditor.dart`

| id  | behavior                                                                        | traces     | kind    | state   | test |
| --- | ------------------------------------------------------------------------------- | ---------- | ------- | ------- | ---- |
| U22 | Attributes a lib/ file found in cycle-log green entries to its zfa invocation   | FR-005     | example | DONE    | `test/plugins/tdd/services/provenance_auditor_test.dart::attributes cycle-log` |
| U23 | Attributes a lib/ file found in carve-out manifest as a declared exemption      | FR-005     | example | DONE    | `test/plugins/tdd/services/provenance_auditor_test.dart::attributes carve-out` |
| U24 | Marks a lib/ file with no provenance source as UNATTRIBUTED                     | FR-005     | example | DONE    | `test/plugins/tdd/services/provenance_auditor_test.dart::marks unattributed` |
| U25 | Emits machine-readable provenance.json with per-file attribution map            | FR-006     | example | DONE    | `test/plugins/tdd/services/provenance_auditor_test.dart::writes provenance.json` |
| U26 | Summary line reports attributed/carve-out/unattributed/total counts             | FR-006     | example | DONE    | `test/plugins/tdd/services/provenance_auditor_test.dart::summary counts` |

### `lib/src/plugins/tdd/commands/corpus_command.dart`

| id  | behavior                                                                        | traces     | kind    | state   | test |
| --- | ------------------------------------------------------------------------------- | ---------- | ------- | ------- | ---- |
| U27 | `corpus run` prints per-feature progress lines matching the contract format     | FR-001     | example | PENDING |      |
| U28 | `corpus run` final summary line matches the machine-readable contract           | FR-009     | contract| DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::summary line matches contract` |
| U29 | `corpus run` exit codes: 0=complete, 1=stopped, 2=runner-error, 3=corrupt, 4=concurrent | FR-009 | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::exit codes` |
| U30 | `corpus audit` per-file report lines match the contract format                  | FR-006     | example | PENDING |      |
| U31 | `corpus audit` summary line matches the machine-readable contract               | FR-006     | contract| PENDING |      |
| U32 | `corpus status` per-feature status lines match the contract format              | FR-009     | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::status lines format` |
| U33 | `corpus status` summary line matches the machine-readable contract              | FR-009     | contract| DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::summary line format` |
| U34 | `corpus status` exit 0 when all manifest features done+gated, non-zero otherwise | FR-009    | example | DONE    | `test/plugins/tdd/commands/corpus_command_test.dart::exit 0 when all done` |

## Invariants and edge cases still to place

- The gap ledger is append-only across resumes (U8 covers this, but the cross-resume invariant is also tested at A2/A3).
- Corpus progress atomicity: a crash mid-write leaves previous state intact (covered by U11 for ledger; analogous for progress store — covered by U1).
- Manifest edited mid-run: added features driven on next run, removed features marked dropped (covered by U6 and U21).

## Out of scope

- Test-list format concerns (#617) and acceptance deferral (#625) — the runner consumes fixed behavior of `run`/`verify`.
- Corpus import itself (#627) — the harness consumes its output.
- Dependency-ordered driving beyond manifest order — lexicographic from #627.
- Deciding the mutation gate policy — the runner surfaces it via ledger + waivers.

## Verification commands

Copied from `.specify/memory/tdd-profile.md`:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
