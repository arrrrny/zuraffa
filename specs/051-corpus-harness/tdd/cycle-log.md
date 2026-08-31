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
## Cycle 11: U25..U30 — the provenance scanner

- test: `test/plugins/tdd/services/provenance_scanner_test.dart` (11 tests: registry x2, refactor, provenance x2, carve-out, priority, normalization, unattributed x3)
- red: `dart test test/plugins/tdd/services/provenance_scanner_test.dart`
  -> `UnimplementedError` (11 failed against the scan stub)
- green: implemented `ProvenanceScanner` (lib/ walk; the four sources in
  priority order — artifacts.json subject_path, cycle-log refactor
  `changed:` lists, `.zfa/provenance/*.json` records, carve-out manifest;
  POSIX-relative normalization; malformed source rows skipped, never
  fatal). Suite -> `00:00 +11: All tests passed!`; analyze clean
- refactor: report counts split into three buckets (attributed excludes
  carve-out — US3's "attributed / carve-out / unattributed" summary) after
  the first green exposed the overlap; the U27 test's fixture
  double-listed a file across two records (priority made the first record
  win — correct), so the fixture was corrected instead
- commit: (this commit)

## Cycle 12: A7 + A8 + A9 + U31 + U32 — the audit command

- test: `test/plugins/tdd/commands/corpus_audit_command_test.dart` (4 tests)
- red: -> the T001 skeleton only printed usage (4 failed, `Actual` lines
  were the help text)
- green: implemented `zfa tdd corpus audit` in
  `lib/src/plugins/tdd/commands/corpus_audit_command.dart`: scan -> human
  summary + unattributed file names -> `.zfa/corpus/audit-report.json`
  (per-file source+command, carve-out list, counts, result) -> the
  `audit:` machine line; exit 0 pass / 1 fail. Suite (audit + scanner)
  -> `00:00 +15: All tests passed!`; analyze clean
- refactor: switched stdout.writeln to print (CliRunner.runCapturing
  captures print through the zone specification — the house pattern the
  loop commands use)
- notes: A9 pins the carve-out removal flip (the manifest is the only
  exemption path); U32 pins the vacuous files=0 pass.
- commit: (this commit)
## Cycle 13: A13 + A14 + U33 + U34 — the status command

- test: `test/plugins/tdd/commands/corpus_status_command_test.dart` (4 tests: A13 read-only report, A14 exit-0-exactly-when-complete, no-manifest, corrupt)
- red: `dart test test/plugins/tdd/commands/corpus_status_command_test.dart`
  -> `Actual: 'Run "zfa help"...'` / `Actual: <0>` (4 failed — the T001 skeleton printed usage)
- green: implemented `zfa tdd corpus status` (read-only aggregation of
  manifest + progress + ledger + waivers: per-feature state lines with
  gates and waivers, dropped list, ledger totals + blocking gaps, the
  resume point, the `corpus:` summary line with
  result=complete|incomplete|no-manifest|corrupt-state and exits
  0/1/2/3). Suite -> `00:00 +4: All tests passed!`; analyze clean
- refactor: fixed a String-vs-enum state comparison the analyzer flagged
- notes: U33 (byte-identical state files) is asserted inside the A13 test
  across manifest/progress/ledger/waivers.
- commit: (this commit)
## Bookkeeping: test-list states aligned (all 48 behaviors DONE)

The state column updates from cycles 4-13 silently failed on a table
spacing mismatch (rows end with an empty test cell; the update patterns
did not). All 30 affected rows (A10-A14, U10-U34) are now flipped to
DONE with their test references — every flip corresponds to a cycle
entry above with recorded red/green evidence or a deliberate-mutant
check. No behavior state changed that is not backed by a logged cycle.
## Cycle 14: T030 + T031 — quickstart validated live; the full suite

- quickstart (T030): scenarios 1-4 executed against a real scratch app
  through the real entrypoint (`dart bin/zfa.dart tdd corpus ...`):
  drive -> stop at f2 (ledger gap-001 with all six fields) -> fix ->
  resume (f1 not re-driven; res-001 appended, gap-001 untouched) ->
  status (result=incomplete, resume_at=f3-later, exit 1 — the not-ready
  feature blocks completion honestly) -> audit (unattributed file named,
  exit 1; after removal 100% attribution exit 0; carve-out removal flips
  its file). One quickstart bug found and fixed in the doc: the fake
  zfa's verify pattern must match `verify --feature <f>` (the argv shape),
  and the "fixed" fake needs machine-line defaults.
- full suite (T031): `dart analyze` -> No issues found; `dart format`
  -> zero diff; `tools/run_tests_chunked.sh` -> with two pre-existing
  runner bugs found by this verification and fixed in
  `tools/run_tests_chunked.sh` (fix(051) commit):
  1. `dart test` inside the `while read` loop slurped the here-string
     chunk list — only 36 of 64 chunks ran; every chunk from
     `test/plugins/method_append` on (including ALL of
     `test/plugins/tdd/*`, where this feature's tests live) was silently
     skipped. Fix: `< /dev/null`.
  2. Tag-empty folders (all tests slow-tier-tagged: test/benchmark,
     test/core/dependencies, test/integration, test/property,
     test/plugins/tdd/scenarios) exit 79 "No tests ran." and were counted
     as FAIL. Fix: counted as SKIP (the fast suite excludes them by
     design — reproduced on pristine master 11de4bfc).
- Final counts with the fixed runner: 64 chunks, 5 skipped
  (tag-empty), **2326 tests passed, 0 failed**, runner exit 0.
- notes: a mid-session `git checkout master -- .` verification sequence
  clobbered `lib/src/commands/tdd_command.dart` and the smoke test in the
  WORKING TREE only (HEAD was intact); restored from HEAD, verified
  green (15/15 commands, 7/7 smoke) before the final suite run.
- commit: (this commit)

## Cycle 15 (T033 remediation): A2 — red re-established for the resume skip

- context: T033 (verdict-blocking finding 1 from tdd.verify): the A2
  implementation shipped in cycle 7's batch before its test (cycle 8) —
  no red existed. Remediation protocol: revert the behavior's
  implementation to its pre-cycle-7 shape, observe the test fail, restore,
  verify green.
- revert: the resume skip in `corpus_run_command.dart`
  (`if (existing?.state == done || waived) continue;`) removed — every
  feature re-driven from scratch on every invocation (pre-cycle-7 shape).
- red: `dart test --preset=all test/plugins/tdd/commands/corpus_run_command_test.dart -N "A2 + A11"`
  -> `00:00 +0 -1: Some tests failed.`
  `Expected: an object with length of <2>` — `f1Calls` (the fake argv log)
  held 4 invocations for f1-good: the completed feature was re-driven on
  the resume. SC-001's zero-duplicate contract is exactly what the red
  pins.
- restore: implementation restored byte-exact (verified by
  `git diff --stat` -> empty); both files re-run ->
  `00:01 +18: All tests passed!`; `dart analyze` -> No issues found.
- commit: (this commit)

## Cycle 16 (T033 remediation): A5 — red re-established for the gate matrix

- revert: the verify-gate stop removed — every verify outcome absorbed as
  `done (gate: pass)` (the pre-gate shape: no STOP-ON-ROADBLOCK at the
  verify step).
- red: `dart test --preset=all test/plugins/tdd/commands/corpus_run_command_test.dart -N "A5"`
  -> `00:00 +0 -4: Some tests failed.` — all four gate-matrix tests
  (fail_survived / fail_timeout / preflight_red / not_assessed):
  `Expected: <1> Actual: <0>` (the run was expected to stop exit-1; it
  completed exit-0 with the gate silently absorbed).
- restore: restored byte-exact; the full two-file proof run ->
  `00:01 +18: All tests passed!`.
- commit: (this commit)

## Cycle 17 (T033 remediation): A6 — red re-established for waivers

- revert: the exact-match waiver lookup replaced with `final waiver = null;`
  (pre-waiver shape: no waiver is ever consulted, every non-pass gate
  stops).
- red: `dart test --preset=all test/plugins/tdd/commands/corpus_run_command_test.dart -N "A6"`
  -> `00:00 +1 -2: Some tests failed.` —
  'an exact-match waiver marks the feature waived, recorded fully':
  `Expected: <0> Actual: <1>` (waived completion vs stopped);
  'a waived feature is not re-driven on resume': `Expected: an object with
  length of <2>` (the stopped feature was re-driven). The third test
  ('a waiver naming a different gate does NOT absorb') still passed —
  correct: with no waiver consulted a foreign-gate waiver also does not
  absorb.
- restore: restored byte-exact; two-file proof run -> `+18: All tests
  passed!`.
- commit: (this commit)

## Cycle 18 (T033 remediation): A10 — red re-established for the six-field ledger entry

- revert: the `behavior` attribution in `_stopAtFeature` (parsed from the
  step's `stopped_at=B-002:make` marker) replaced with `final behavior =
  null;` — the pre-cycle-7 shape wrote ledger entries with no behavior
  attribution.
- red: `dart test --preset=all test/plugins/tdd/scenarios/sc_020_corpus_harness_e2e_test.dart`
  -> `00:00 +0 -1: Some tests failed.`
  `Expected: 'B-002' Actual: <null>` — the SC-020 six-field entry
  assertion (gap['behavior']) is the pin. (The specs-tree checksum half
  of A10 is structural — the runner writes only progress + ledger — and
  was already mutation-proven in cycle 8's stray-write mutant.)
- restore: restored byte-exact; two-file proof run -> `+18: All tests
  passed!`.
- commit: (this commit)

## Cycle 19 (T033 remediation): A11 — red re-established for resolution entries

- revert: the `_appendResolutionsIfGapped` call removed from the done-path
  (pre-shape: a previously-gapped feature passing writes no resolution
  entry).
- red: `dart test --preset=all test/plugins/tdd/commands/corpus_run_command_test.dart -N "A2 + A11"`
  -> `00:00 +0 -1: Some tests failed.`
  `Expected: an object with length of <2>` — the ledger held only
  `gap-001` (actual printed: the single gap entry); the resolution entry
  never landed. The A2 half of the same test passed (resume skip intact),
  isolating the red to A11.
- restore: restored byte-exact; two-file proof run -> `+18: All tests
  passed!`.
- commit: (this commit)

## Cycle 20 (T033 remediation): A12 — red re-established for report totals

- revert: the `_printReport` ledger lines removed (the
  `ledger: found=… filed=… merged=… blocking=…` totals line and the
  per-gap `blocking:` names) — pre-cycle-7 shape: the report carried
  feature state lists only.
- red: `dart test --preset=all test/plugins/tdd/commands/corpus_run_command_test.dart -N "A12"`
  -> `00:00 +0 -1: Some tests failed.`
  `Expected: contains 'ledger: found=1 filed=0 merged=0 blocking=1'` —
  the output had no totals line.
- restore: restored byte-exact; the T033 proof command
  `dart test --preset=all test/plugins/ttd/commands/... test/plugins/tdd/scenarios/sc_020...`
  (corrected path) -> `00:01 +18: All tests passed!`;
  `dart analyze` -> No issues found; `git diff --stat` -> empty (all six
  reverts restored byte-exact before this entry was written).
- commit: (this commit)

## Cycle 21 (T034 + T035): SC-020 split into phase tests; A1 split into per-observable tests

- T034 (finding 2): `sc_020_corpus_harness_e2e_test.dart`'s single
  ~25-assertion test split into 7 phase-scoped tests sharing ONE fixture
  lifecycle (`setUpAll`/`tearDownAll` + closure state — the phases are
  sequential by design and dart runs tests in declaration order):
  phase 1 (drive / FR-003 never-spawned / FR-007 six fields / A10
  byte-stable specs tree) then phase 2 (SC-001 resume / A11 history /
  honest report). Proof: a failing phase now names itself — verified by
  the phase labels in the runner output. Every original assertion kept.
  Green: `dart test --preset=all <file>` -> `+7: All tests passed!`.
- T035 (finding 3): the A1 contract test's five observables (order,
  exit, persistence, gate, summary) split into per-observable tests,
  each name stating its one observable; every test re-drives the same
  2-feature corpus on a fresh fixture. Green: the run-command suite ->
  `+21: All tests passed!` (was +17: one A1 test became five).
- commit: (this commit)

## Cycle 22 (T036 + T037): clock injection; fixture dialect unified

- T036 (finding 4), test-first: new group 'GapLedgerStore (T036 —
  injected clock)' written first ->
  `Error: No named parameter with the name 'clock'` (compile red,
  quoted from the run) -> `GapLedgerStore` gained an injectable
  `clock: DateTime Function()` (defaults to `DateTime.now`);
  `_now()` now uses it. Green: `dart test
  test/plugins/tdd/services/gap_ledger_store_test.dart` -> `+7: All
  tests passed!` (fixed-stamp assertion: `2026-08-31T12:00:00.000Z`
  in the entry, the resolution, and the persisted JSON; default-clock
  wall-time bounds test added alongside).
- T037 (finding 5): `corpus_fixture.dart`'s fake-zfa script rewritten
  onto `TddFixture.writeFakeZfaBin`'s conventions — `LOG`-variable
  append + `ARGV="$*"` header, dispatch via
  `if [[ "$ARGV" == *"<pattern>"* ]]; then … fi` blocks (the corpus
  keys `run:<f>`/`verify:<f>` map to the argv substrings the runner
  actually spawns), `set -e`; the `shellQuoteInner` no-op helper and
  the inline path-escaping removed. The corpus-only extensions (echoed
  machine lines, success defaults) stay explicit. First run RED: the
  default tail used prefix match (`"run "*`) while argv starts with
  `tdd` -> every default invocation fell through to `exit 2` ->
  `runner-error` (23 failures, root cause read from the failure
  output); fixed to substring match (`*" run "*` +
  `${ARGV#* run }` feature extraction). Green: all five corpus test
  files `--preset=all` -> `+43: All tests passed!`.
- commit: (this commit)
