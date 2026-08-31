# Cycle Log: `zfa tdd corpus` — batch driving, verify gate, provenance audit, gap ledger

Append only. Newest last. Every entry's `red` block is the evidence that the
test existed and failed before the implementation.

## Baseline

- suite: `dart test test/plugins/tdd/` -> 227 passed, 0 failed (fast tier)
- analyze: `dart analyze` -> No issues found!
- commit: `64705f26`
- recorded: cycle 0, before any change

## Cycle 1: T001 — the corpus command family registers (scaffolding)

- test: `test/plugins/tdd/tdd_command_smoke_test.dart::zfa tdd --help lists the corpus family (051, T001)` + `::zfa tdd corpus --help lists run, status, audit (051, T001)` (new)
- red: `dart test --preset=all test/plugins/tdd/tdd_command_smoke_test.dart`
  -> `Expected: contains 'corpus'` (2 failed: corpus family + corpus --help;
  the help output listed only the eight 041 subcommands)
- green: created `lib/src/plugins/tdd/commands/corpus{_,_run,_status,_audit}_command.dart`
  (usage-printing skeletons, `--project`/`--zfa-bin` flags declared) and
  registered `CorpusCommand` in `lib/src/commands/tdd_command.dart`.
  Suite `dart test --preset=all test/plugins/tdd/tdd_command_smoke_test.dart`
  -> `00:00 +7: All tests passed!`; `dart analyze lib/src/plugins/tdd/commands/`
  -> No issues found
- refactor: none needed (skeletons only; the first assertion draft demanded
  `status`/`audit` inside `zfa tdd --help`, which lists only first-level
  subcommands — the observable was corrected to the corpus line + the
  dedicated `corpus --help` test, before any implementation landed)
- commit: (this commit)
- notes: T001 is scaffolding (no A/U marker): the command family exists and
  is smoke-tested; the driving/status/audit logic lands with the behavior
  cycles below.

## Cycle 2: U1 + U2 — the manifest model decodes in order, rejects malformed

- test: `test/plugins/tdd/models/corpus_models_test.dart::CorpusManifest (U1) decodes features in file order with optional provenance` + 5 siblings (U1 pair + U2 malformed matrix)
- red: `dart test test/plugins/tdd/models/corpus_models_test.dart`
  -> `UnimplementedError` / `Which: threw UnimplementedError:<UnimplementedError>` (6 failed against the minimal stub — order, optional fields, and every malformed shape unpinned)
- green: implemented `CorpusManifest.fromJson` + `CorpusFeature` +
  `CorpusManifestException` (message names corpus-manifest.json + recovery)
  in `lib/src/plugins/tdd/models/corpus_manifest.dart`.
  Suite -> `00:00 +6: All tests passed!`;
  `dart analyze lib/src/plugins/tdd/models/` -> No issues found
- refactor: dropped an `unnecessary_cast` the analyzer flagged; no other
  change needed
- commit: (this commit)


## Cycle 3: U3 + U4 + U5 — the manifest store reads manifest, carve-out, waivers

- test: `test/plugins/tdd/services/corpus_manifest_store_test.dart` (U3 manifest reading x3, U4 carve-out x3, U5 waivers x3, + the path-constants test)
- red: `dart test test/plugins/tdd/services/corpus_manifest_store_test.dart`
  -> `Which: threw UnimplementedError:<UnimplementedError>` (7 of 10 failed against the store stubs; the path-constants test passed — pure plumbing already pinned)
- green: implemented `readManifest` (absent -> `CorpusManifestMissingException`
  naming the path + #627 remediation; invalid JSON -> corrupt), `readCarveOut`
  (absent -> empty; `{carveouts: [{path, reason}]}` validated), `readWaivers`
  (absent -> empty; row shape validated) + `CarveOutEntry` /
  `CorpusManifestMissingException` models and the full `.zfa/` path constants.
  Suite (models + store) -> `00:00 +16: All tests passed!`;
  `dart analyze lib/src/plugins/tdd/` -> No issues found
- refactor: dropped an `unnecessary_cast`; nothing else needed
- commit: (this commit)
## Cycle 4: U6 + U7 + U8 + U9 + U10 — progress model round trip + atomic store

- test: `test/plugins/tdd/services/corpus_progress_store_test.dart` (U6 round trip x2, U7 atomicity, U8 corruption x3, U9 refusal x2, U10 dropped, + save/load integration x2)
- red: `dart test test/plugins/tdd/services/corpus_progress_store_test.dart`
  -> `UnimplementedError` (10 of 11 failed against the stubs — round trip, atomicity, corruption, refusal, dropped all unpinned; the path test passed)
- green: implemented `CorpusProgress.fromJson` (strict shape validation) +
  mutable state helpers + `CorpusProgressStore` (temp+rename atomic save,
  load corruption gate with recovery, pid in-flight refusal with injectable
  probe, dropped computation retaining entries). Suite (models + stores)
  -> `00:00 +79: All tests passed!`; `dart analyze lib/src/plugins/tdd/`
  -> No issues found
- refactor: removed two `unnecessary_cast`s; made the model's in-flight/
  dropped fields mutable (a runner-held state object saved by the store)
- commit: (this commit)
## Cycle 5: U11 + U12 + U13 + U14 — ledger totals + append-only store

- test: `test/plugins/tdd/models/corpus_models_test.dart::GapLedger totals (U11) computes found / filed / merged / blocking from entries` + `test/plugins/tdd/services/gap_ledger_store_test.dart` (U12 x3, U13, U14)
- red: `dart test test/plugins/tdd/services/gap_ledger_store_test.dart test/plugins/tdd/models/corpus_models_test.dart`
  -> `UnimplementedError` (6 failed against the stubs — totals, monotonic ids, append stability, resolution semantics)
- green: implemented `GapLedgerTotals.fromEntries` (found/filed/merged/
  blocking; a gap resolves via status resolved/merged OR a resolution entry)
  + `GapLedgerStore` (load with corrupt gate, `gap-###`/`res-###` monotonic
  ids, atomic temp+rename persist with fixed field order for byte-stable
  appends). Suite -> `00:00 +12: All tests passed!`;
  `dart analyze lib/src/plugins/tdd/` -> No issues found
- refactor: none needed
- notes: the U11 test's first draft expected 1 blocking gap; the
  data-model definition ("unresolved gaps whose feature is not done/waived")
  makes a filed-but-unmerged gap still blocking — the expectation was
  corrected to 2 (gap-001 open + gap-002 filed-not-merged) BEFORE the
  implementation was accepted, and the reason is recorded here.
- commit: (this commit)
## Cycle 6: U15 + U16 + U17 + U18 — the corpus step runner

- test: `test/plugins/tdd/services/corpus_step_runner_test.dart` (U15 run spawn/parse x3, U16 verify x2, U17 missing line, U18 spawn failure)
- red: `dart test test/plugins/tdd/services/corpus_step_runner_test.dart`
  -> `UnimplementedError` (7 failed against the stubs)
- green: implemented `CorpusStepRunner` (argv contracts `tdd run <f>
  --project <dir>` / `tdd verify --feature <f> --project <dir>`, `.dart`
  entrypoints through `dart`, injectable spawner, last-`<verb>:` line
  parsing, success = exit 0 AND token agreement, missing-line and spawn
  failures as runner-error misfires). Suite -> `00:00 +7: All tests
  passed!`; `dart analyze` -> No issues found
- refactor: moved the default spawner back inside the class after a
  misplaced brace; no behavior change
- commit: (this commit)
## Cycle 7: A1 + A4 + U19..U24 — the corpus driving loop

- test: `test/plugins/ttd/commands/../tdd/commands/corpus_run_command_test.dart` (8 tests: A1 order+persist+summary, A4 gate recorded, U23 stop+ledger, U19 not-ready, U21 no-manifest, U22 concurrent, U20+U24 manifest edit, corrupt-state) + `test/plugins/tdd/helpers/corpus_fixture.dart` (new fixture: manifest writer + scripted fake zfa with argv log)
- red: `dart test --preset=all test/plugins/tdd/commands/corpus_run_command_test.dart`
  -> `Actual: []` (zero fake invocations) + `Expected: <1> Actual: <0>` (exit codes) — 8 failed: the T001 skeleton only printed usage
- green: implemented the driving loop in `lib/src/plugins/tdd/commands/corpus_run_command.dart`
  (manifest read with no-manifest/corrupt classes, progress load + concurrent
  refusal with zero prior writes, mark-driving -> spawn run -> spawn verify ->
  gate -> persist per feature, STOP-ON-ROADBLOCK ledger entries with the six
  FR-007 fields, not-ready skip-and-report, dropped computation, the human
  report, and the `corpus:` summary line with exits 0/1/2/3/4).
  Suite -> `00:00 +8: All tests passed!`; `dart analyze` -> No issues found
- refactor: fixed the plugin import path; record the gate on stopped
  features; simplified the exit-code expression
- notes: U22's first draft seeded the in-flight marker with pid 1, which
  `kill -0` cannot probe as a non-root user (EPERM -> correctly read as
  dead); the test now spawns a real `sleep` child and uses its pid.
- commit: (this commit)
## Cycle 8: A2 + A11 + SC-020 — resume, resolutions, the US1 e2e scenario

- test: `test/plugins/tdd/commands/corpus_run_command_test.dart::A2 + A11 — resume after a fixed gap` + `test/plugins/tdd/scenarios/sc_020_corpus_harness_e2e_test.dart::SC-020/US1`
- red: the resume test first failed on fixture/test bugs (the argv log was
  reset by the fake rewrite; the f2 call-count expectation forgot the
  failed first run) — fixed the fixture (log preserved across rewrites)
  and corrected the expectation with the reason recorded; the scenario
  then ran against cycle 7's implementation
- deliberate-mutant checks (the behaviors shipped with cycle 7's loop, so
  the playbook's pass-on-first-run protocol applied):
  1. resume skip removed (done features re-driven) -> the A2 test FAILED
     (`f1Calls` grew to 4); restored -> green.
  2. a stray write into `specs/<feature>/tdd/runner-junk.txt` injected into
     the loop -> the SC-020 specs-tree checksum FAILED; restored -> green.
  Both mutants were reverted exactly (verified by re-run + analyze).
- green: `dart test --preset=all` over the run-command tests + scenario ->
  `00:00 +10: All tests passed!`; `dart analyze lib/ test/plugins/tdd/` ->
  No issues found
- refactor: the fixture's rewriteFakeZfa now preserves the argv log
  (resume assertions count invocations across runs — SC-001)
- commit: (this commit)
## Cycle 9: A5 + A6 — the gate matrix and waivers (SC-002)

- test: `test/plugins/tdd/commands/corpus_run_command_test.dart::A5 — the gate matrix (SC-002)` (4 tests: fail_survived / fail_timeout / preflight_red / not_assessed) + `::A6 — waivers (never silent)` (3 tests)
- red: the gate/waiver evaluation shipped with cycle 7's loop, so these ran
  green on first contact — the playbook's deliberate-mutant protocol
  applied instead of a red:
  1. ABSORB MUTANT (`verifyResult.success || true` — every gate counts as
     done): the 4 gate-matrix tests FAILED (state not stopped, f2
     started, ledger empty). Reverted exactly.
  2. BROAD-WAIVER MUTANT (waiver matched on feature only, ignoring the
     gate label): the "waiver naming a different gate does NOT absorb"
     test FAILED. Reverted exactly.
- green: `dart test --preset=all test/plugins/tdd/commands/corpus_run_command_test.dart`
  -> `00:00 +16: All tests passed!`; `dart analyze` -> No issues found
- notes: not_assessed stops and ledger like every other non-pass gate —
  surfaced to the maintainer, never silently absorbed (FR-004, US2.AC2).
  A waived feature is terminal (never re-driven); the waiver's reason +
  actor + timestamp are visible in progress JSON and the report text.
- commit: (this commit)
## Cycle 10: A12 — ledger totals + named blocking gaps in the report

- test: `test/plugins/tdd/commands/corpus_run_command_test.dart::A12 — ledger totals + blocking gaps in the final report`
- red: green on first contact (the report shipped with cycle 7) — the
  playbook's deliberate-mutant protocol applied: suppressing the
  blocking-gap listing in the report made the test FAIL; restored exactly
- green: `00:00 +17: All tests passed!`; analyze clean
- notes: the first draft re-drove the corpus after hand-editing the ledger
  to prove filed/merged counts through the report — but a stopped feature
  is re-driven by design, appending a NEW gap. The filed/merged arithmetic
  stays pinned by U11's totals unit tests; this test pins the report's own
  obligation (the totals line + the named gap). Reason recorded here.
- commit: (this commit)
