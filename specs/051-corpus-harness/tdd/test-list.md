---
feature: 051-corpus-harness
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 14
planned_at: 64705f26
updated_at: 64705f26
suite_baseline: green
---

# Test List: `zfa tdd corpus` — batch driving, verify gate, provenance audit, gap ledger

Baseline: `dart test test/plugins/tdd/` at `64705f26` (branch 051-corpus-harness,
post-plan HEAD) → 227 passed, 0 failed (fast tier; slow tags excluded).
`dart analyze` → No issues found. The loop starts on a green baseline.

The corpus commands' real entry point is the CLI (`bin/zfa.dart` through
`CliRunner` in-process; the driven `zfa tdd run` / `zfa tdd verify` are
scripted fake-zfa sub-processes, the 049 pattern). Scenario rows run in
the slow tier; command rows that spawn the fake are slow-tier too, the
rest fast.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`, observable through the real CLI
entry point.

| id  | behavior                                                                                                                             | traces  | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------------------------------------------ | ------- | ------- | ------- | ---- |
| A1  | A manifest of N ready features driven by `zfa tdd corpus run` invokes `run`-then-`verify` per feature in manifest order, persists corpus progress after each feature, and ends with the per-feature `corpus:` summary line, exit 0 | US1.AC1 | example | PENDING | |
| A2  | A corpus run interrupted after feature k re-run drives features 1..k zero more times (fake argv log: 0 duplicate invocations) and resumes at k+1 | US1.AC2 | example | PENDING | |
| A3  | A feature whose loop stops halts the whole corpus run non-zero with a gap-ledger entry (feature, behavior, step, outcome, issue-link placeholder) and later features are never started | US1.AC3 | example | PENDING | |
| A4  | A feature whose loop completed and whose verify gate passes is marked done in corpus progress with the gate recorded | US2.AC1 | example | PENDING | |
| A5  | A feature whose verify gate returns `not_assessed` stops the run, ledger-records the reason, and the feature is not counted done | US2.AC2 | example | PENDING | |
| A6  | An explicit recorded waiver for a verify outcome is visible (reason + who + when) in corpus progress and the final report — never silent | US2.AC3 | example | PENDING | |
| A7  | On a corpus-driven app, `zfa tdd corpus audit` maps every `lib/` file to a recorded zfa invocation or carve-out entry; 100% attribution exits 0 | US3.AC1 | example | PENDING | |
| A8  | A file under `lib/` with no recorded provenance and no carve-out entry fails the audit non-zero, named | US3.AC2 | example | PENDING | |
| A9  | Removing a carve-out manifest entry flips its file to unattributed and failing on the next audit — the manifest is the only exemption path | US3.AC3 | example | PENDING | |
| A10 | Any corpus stop appends a ledger entry carrying the five required fields (feature, behavior, step, outcome, failing command) plus the issue-link placeholder, with zero test/ source edits | US4.AC1 | example | PENDING | |
| A11 | A resumed run that passes the previously-gapped feature leaves the old ledger entry byte-identical and records the resolution as a new entry | US4.AC2 | example | PENDING | |
| A12 | The final corpus report lists ledger totals (found / filed / merged / blocking) and names every unresolved gap blocking completion | US4.AC3 | example | PENDING | |
| A13 | `zfa tdd corpus status` on a partially driven corpus reports per-state feature counts, the resume point, and ledger totals, changing nothing | US5.AC1 | example | PENDING | |
| A14 | The `corpus status` summary line is stable for CI: exit 0 exactly when all manifest features are done+gated (or waived), any non-zero means incomplete, without prose scraping | US5.AC2 | example | PENDING | |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/models/corpus_manifest.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U1  | A manifest decodes with its features in file order (order is the driving order) and optional sourceCorpus/importedAt | FR-001      | example | DONE    | `corpus_models_test.dart::CorpusManifest (U1) decodes features in file order with optional provenance` + `::decodes without sourceCorpus/importedAt and defaults reason` |
| U2  | A malformed manifest (invalid JSON, non-object root, non-list features, a row missing name/ready, non-bool ready) is rejected with an error naming the file and the recovery path | FR-011      | example | DONE    | `corpus_models_test.dart::CorpusManifest malformed (U2)` (4 tests) |

### `lib/src/plugins/tdd/services/corpus_manifest_store.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U3  | An absent manifest file yields the distinct no-manifest outcome naming the expected path (vs. corrupt) | FR-001      | example | DONE    | `corpus_manifest_store_test.dart::U3 — manifest reading` (3 tests) |
| U4  | The carve-out manifest decodes `{carveouts: [{path, reason}]}`; a malformed shape is a corrupt-state-class error naming the file | US3.AC3     | example | DONE    | `corpus_manifest_store_test.dart::U4 — carve-out reading` (3 tests) |
| U5  | Waivers decode `{feature, gate, reason, actor, at}` rows; an absent waivers file means no waivers | US2.AC3     | example | DONE    | `corpus_manifest_store_test.dart::U5 — waivers reading` (3 tests) |

### `lib/src/plugins/tdd/models/corpus_progress.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U6  | Corpus progress round-trips through JSON with per-feature state, gate, stoppedAt, waiver, the in-flight marker, and the dropped list intact | FR-001      | example | DONE    | `corpus_progress_store_test.dart::CorpusProgress model (U6) round-trips state, gate, stoppedAt, waiver, in-flight, dropped` + `::empty progress round-trips to empty` |

### `lib/src/plugins/tdd/services/corpus_progress_store.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U7  | A save that fails mid-write (injected writer error) leaves the previous progress file byte-identical (temp + rename) | FR-001, FR-010 | example | DONE    | `corpus_progress_store_test.dart::CorpusProgressStore (U7) a save that fails mid-write leaves the previous file byte-identical` |
| U8  | A corrupt progress JSON stops with an error naming the file and the recovery path (delete to restart) | FR-011      | example | DONE    | `corpus_progress_store_test.dart::CorpusProgressStore (U8)` (3 tests) |
| U9  | The in-flight marker refuses a live foreign pid; own pid, dead pid, or no marker never refuses | FR-010      | example | DONE    | `corpus_progress_store_test.dart::CorpusProgressStore (U9)` (2 tests) |
| U10 | Progress features absent from the current manifest land in `dropped` and are retained (append-only audit trail) | US1 edge    | example | PENDING | |

### `lib/src/plugins/tdd/models/corpus_ledger.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U11 | Ledger totals compute from entries: found = all, filed = issue link set, merged = status merged, blocking = open gaps whose feature is not done/waived | FR-008      | example | PENDING | |

### `lib/src/plugins/tdd/services/gap_ledger_store.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U12 | Appending a gap produces a monotonic `gap-###` id and a complete entry: feature, behavior, step, outcome, failing command, issue-link placeholder, timestamp | FR-007      | example | PENDING | |
| U13 | Appends never modify prior entries (byte-identical prefix) and the file stays decodable after every append | US4.AC2     | example | PENDING | |
| U14 | A resolution entry appends with `resolves: <gap id>` and the resolved entry is untouched | US4.AC2     | example | PENDING | |

### `lib/src/plugins/tdd/services/corpus_step_runner.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U15 | A `tdd run` invocation spawns the agreed argv via the `--zfa-bin` entrypoint and parses `run: feature=… result=… [stopped_at=behavior:step]`; success is exit 0 AND result=complete | FR-001, FR-002 | example | PENDING | |
| U16 | A `tdd verify` invocation parses `mutation: gate=…`; success is exit 0 AND gate=pass; a non-pass gate surfaces its label even with a non-zero exit | FR-004      | example | PENDING | |
| U17 | A step that exits 0 without its documented summary line is a runner-error misfire, never a silent success | FR-011      | example | PENDING | |
| U18 | A spawn failure (missing binary, ProcessException) yields a runner-error result, never a crash | FR-011      | example | PENDING | |

### `lib/src/plugins/tdd/commands/corpus_run_command.dart` (inner boundaries)

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U19 | Not-ready manifest features are skipped and reported (`not_ready=` in the summary), never spawned | FR-003      | example | PENDING | |
| U20 | A manifest edited mid-stream: features added are driven on the next run; features removed keep progress entries marked dropped | US1 edge    | example | PENDING | |
| U21 | No manifest at the project root → `result=no-manifest`, exit 2, message naming the expected path | FR-001, FR-011 | example | PENDING | |
| U22 | A second concurrent corpus run is refused: `result=concurrent-run`, exit 4, no state writes | FR-010      | example | PENDING | |
| U23 | A feature whose `run` exits non-zero for ANY outcome (stopped / runner-error / corrupt-state / concurrent-run) stops the corpus with a ledger entry naming that outcome — the outcome is never absorbed into done | FR-002      | example | PENDING | |
| U24 | Dropped features are reported in the final summary (`dropped=<n>`) and never re-driven | US1 edge    | example | PENDING | |

### `lib/src/plugins/tdd/services/provenance_scanner.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U25 | `specs/*/tdd/artifacts.json` subject_path entries attribute matching `lib/` files, in both absolute and project-relative form | FR-005      | example | PENDING | |
| U26 | Cycle-log refactor entries' `changed:` file lists attribute matching `lib/` files | FR-005      | example | PENDING | |
| U27 | `.zfa/provenance/*.json` records (single object or array) attribute their files to the recorded command | FR-005      | example | PENDING | |
| U28 | Carve-out manifest entries attribute their exact-path files | US3.AC1     | example | PENDING | |
| U29 | Attribution is deterministic: a file matched by multiple sources takes the loop attribution (registry before refactor before provenance before carve-out) | FR-006      | example | PENDING | |
| U30 | Recorded paths normalize to POSIX project-relative form for comparison (absolute, `./`-prefixed, and backslash variants all match) | FR-005      | example | PENDING | |

### `lib/src/plugins/tdd/commands/corpus_audit_command.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U31 | The audit writes `.zfa/corpus/audit-report.json` with the per-file attribution map, carve-out list, and counts, plus the `audit: files=… result=…` summary line | FR-006      | example | PENDING | |
| U32 | An app with no `lib/` directory audits trivially green with `files=0` (vacuous truth, still a stable contract line) | FR-006      | example | PENDING | |

### `lib/src/plugins/tdd/commands/corpus_status_command.dart`

| id  | behavior                                                                                        | traces      | kind    | state   | test |
| --- | ----------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U33 | `corpus status` changes nothing: manifest, progress, ledger, and waivers files are byte-identical before and after | US5.AC1     | example | PENDING | |
| U34 | Status exit semantics: 0 exactly when every manifest feature is done or waived; incomplete → 1; no-manifest → 2; corrupt state → 3 | FR-009, SC-005 | example | PENDING | |

## Invariants and edge cases still to place

None — all derived behaviors have home components above.

## Out of scope

- Corpus import / manifest writing (#627) — the harness only reads the
  manifest; import semantics stay with 050-corpus-import.
- Setup provenance emission (#626/#627) — 051 consumes the record format;
  emitting records belongs to those features.
- Test-list format concerns (#617/#625) and loop internals — the runner
  consumes `run`/`verify` as merged; driving `plan` per feature is NOT part
  of `corpus run` (FR-001 pins run-then-verify; a missing test list is an
  honest feature stop, remediation `zfa tdd plan <feature>`).
- Mutation gate policy decisions — surfaced via ledger + waivers, decided
  by the maintainer (spec Out of Scope).
- Dependency ordering beyond manifest order (lexicographic from #627).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md`:

- Single test: `dart test {file} --plain-name "<name>"`
- Whole file: `dart test {file}`
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Full suite (repo): `dart test` — slow; use the scoped subset for feature
  work; cloud agents use `tools/run_tests_chunked.sh`
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
- Static analysis (full repo): `dart analyze`
