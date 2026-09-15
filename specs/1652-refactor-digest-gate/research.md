# Research: 1652-refactor-digest-gate

**Date**: 2026-09-15 | **Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## R1: Why can't the existing #1624/#1588 machinery absorb this?

- **Decision**: New record (`make-post-state.json`), checked after the
  ledger miss under the same `--pass-batch` opt-in.
- **Rationale**: Verified by reading `pass_batch_ledger.dart` +
  `refactor_command.dart` (~L569): the ledger is written by a green
  REFACTOR application and matches only the tree THAT refactor proved.
  Forward progress changes `lib/` on every make, so behavior k+1's
  spawn never matches behavior k's proof — structural (the issue's
  "by construction"), not incidental. What behavior k+1's spawn DOES
  match is its own make's post-state.
- **Alternatives considered**: Widening the ledger's match (e.g. lib-only
  digest) — rejected: weakens the byte-identity gate the #1588 contract
  names; `test/` changes are exactly what a preflight must re-prove.

## R2: Which of the issue's three proposals?

- **Decision**: Proposal 2 (digest-gate against make's certified
  post-state), full-inherit variant — the hit skips preflight, registry,
  and re-proof, exactly like the #1588 ledger hit.
- **Rationale**: Zero contract change to refactor scheduling (proposal 1
  re-audits every stop/resume path) and no heuristic gate weakening
  (proposal 3). The probe's cycle-log shows the registry is `applied: 0
  actions, no-op: true` on freshly generated trees, so skipping it on an
  inherited proof removes the remaining ~10 s honestly; format/fix still
  run per run at phase-2b and at any standalone refactor.
- **Alternatives considered**: "Skip to the pass registry" (run
  registry, inherit only the preflight) — kept as a future knob; it
  halves the win on measured no-op trees and adds a partial-execution
  path this feature does not need.

## R3: Who writes the record, and when?

- **Decision**: The DRIVER (run_driver_core), best-effort, after a make
  step green-applies at phase-1 and phase-2a call sites; make_command is
  untouched.
- **Rationale**: The driver already owns the pass-batch opt-in
  (`_refactorBatchArgs` → `--pass-batch`), already knows
  `suiteBaselinePath`, `projectRoot`, `featureDir`, and the blocked-id
  exempt set the refactor will receive. A driver-side write keeps the
  make contract and its test surface out of the diff entirely. The write
  is two `TreeSnapshot.capture` walks + hashes + one small JSON — the
  same cost class the very next refactor spawn pays today.
- **Alternatives considered**: make_command writes it under a new
  flag — rejected (expands the make contract; the driver observes the
  same moment from the outside); writing inside StepRunner — rejected
  (StepRunner is the generic spawn seam, not run-policy).

## R4: What exactly does the refactor compare, and can the two sides disagree safely?

- **Decision**: Same five context keys as the ledger (suite template,
  baseline content key, config key, exempt set, `lib`+`test` digests),
  computed by shared helpers on both sides.
- **Rationale**: Verified the driver can compute every key the refactor
  computes: suite via `SingleTestRunner.loadSuiteTemplate(workingDirectory:
  projectRoot)` (the same call the driver's phase-0 baseline capture
  makes), baseline key from the threaded `suiteBaselinePath`, config key
  via `PassBatchLedger.configKeyFor(projectRoot)`, digests via
  `PassBatchLedger.treeDigest(TreeSnapshot.capture(...))`, exempt set =
  blocked ids (the same list `_refactorBatchArgs` passes as
  `--exempt-behaviors`; refactor filters it to still-blocked ids — a
  filtered difference is a miss → full pipeline → safe).
- **Alternatives considered**: Comparing only digests (no context keys)
  — rejected: a baseline/config/exempt change between make and refactor
  means the gate make certified is not the gate this spawn would run.

## R5: Where do the tests hook in?

- **Decision**: Two tiers, mirroring the #1588 suite exactly:
  command-level tests run the real `zfa tdd refactor` against fixture
  projects with a logging suite wrapper (suite-spawn counting is the
  economics assertion; stdout tokens `1652`/`make-post-state` name the
  hit); driver-level tests use the scripted fake zfa and assert the
  record is written on make-green with tree-matching digests, and that
  a write failure is only a warning.
- **Rationale**: Verified the #1588 harness shapes exist and are reused
  (`bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart`):
  `TddFixture.seedAlreadyCleanLib`, the profile override pointing
  `suite:` at the logging wrapper, `CliRunner.runCapturing`, spawn-count
  assertions, and the corrupt-payload fallback table.
- **Alternatives considered**: End-to-end `zfa tdd run` for the
  inheritance — already covered indirectly: the driver-level tier proves
  the record write and the command-level tier proves the inheritance;
  a full run pays real AOT/gen costs the fast tier forbids.

## R6: Does anything else read `tdd/make-post-state.json`?

- **Decision**: No — single consumer (the `--pass-batch` refactor fast
  path), single writer (the driving run), derived data with no other
  reader; `zfa tdd reset`/resume paths treat it like the ledger
  (stale = inert).
- **Rationale**: Grep over `lib/` shows the pass-batch ledger has
  exactly the same single-consumer shape; the record copies it. A stale
  record from an interrupted run mismatches on digests (the tree moved
  on) and falls back safely.
- **Alternatives considered**: Cleaning the record up at run end —
  rejected: it is one small file, and keeping it lets a resume's next
  make-green overwrite it in place (derived data, recomputed at every
  green application).
