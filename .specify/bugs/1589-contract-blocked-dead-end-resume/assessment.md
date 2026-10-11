# Bug Assessment: contract BLOCKED dead-ends the documented resume path + poisons the phase-2 refactor pass

- **Slug**: 1589-contract-blocked-dead-end-resume
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1589
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Issue #1589 (arrrrny/zuraffa): blocked contracts dead-end the documented
resume path and silently poison the phase-2 refactor pass. `make` demands
red, `verify-red` can never produce it (BLOCKED by design, issue #1007).

Reproduction from the issue:

```
zfa tdd run calculator
# contract:A1 verify-red -> blocked (parked)
# run: result=blocked stopped_at=contract:A1:verify-red

# Resume:
zfa tdd make contract:A1 --feature calculator
# "has no certified-red evidence" → not-certified-red

zfa tdd verify-red contract:A1 --feature calculator
# "blocked — implement declared contract" → no red evidence written
```

Loop: make waits for red that verify-red is forbidden to write.

Second-order damage: parked contracts fail the full suite → the phase-2
refactor gate demands absolute green → every refactor is skipped for all
remaining behaviors.

## Symptom (verified against the code on this branch)

Three defects, none of them in the BLOCKED verdict itself:

1. **The blocked stop never names the hand surface.**
   `run_driver_core.dart` — the park arm prints only "the declared contract
   is not satisfied — the cycle is BLOCKED" + "parked — the run continues",
   and the terminal `result=blocked` block prints "resume: implement the
   declared contract, then re-run `zfa tdd run <feature>`" — no seam file
   path, no `zfa tdd wire contract:<n>`. `verify_red_command.dart`'s blocked
   stderr names only the contract and the re-run of verify-red. The operator
   is told to "implement the declared contract" with no indication of WHERE
   (the seam: the generated contract test under `test/tdd/<feature>/`) or
   HOW (`zfa tdd wire <id> --entity <Name>`, the subject-wiring step; the
   hand-step vocabulary issues #1308/#1483 already established).

2. **`make` does not accept the blocked verdict as a precondition.**
   `make_command.dart`'s precondition (FR-001) demands certified-red
   evidence in the cycle log. The contract lane (issue #1007) NEVER appends
   red evidence — a failing contract test is re-graded BLOCKED and its
   durable record is `contract-blocked.<id>.json`. So the documented resume
   path `zfa tdd make contract:A1` refuses `not-certified-red` with the
   remedy "Run `zfa tdd verify-red contract:A1` first" — the exact command
   whose output make requires and whose design forbids producing it. The
   loop is unbreakable as written. (The only exits today are the #1542
   born-green attestation or manual run-state surgery; the plain resume
   path dead-ends.)

3. **Parked behaviors fail the phase-2 refactor gate (no pre-existing-
   failure economics for THIS-run parkings).**
   The run's suite baseline (issue #741) is captured ONCE per run, BEFORE
   the first gen. A contract parked during THIS run fails its seam test —
   a file that did not exist at baseline. Issue #922's tolerance only
   excludes failures the BASELINE already records, so the parked seam
   failure is a NEW failure to every phase-2b `refactor` spawn: the
   preflight refuses (`not-green`), the driver records
   `refactor -> skipped (suite not green)` for EVERY green behavior, and
   the refactor pass is silently lost for the whole feature. The parked
   contract poisons the pass it was never part of.

## Root cause

- Blocked stop does not name the hand surface (seam file path or
  `zfa tdd wire`).
- `make` does not accept the blocked verdict as a precondition (nor plainly
  say "implement seam first").
- Parked behaviors are not covered by the baseline economics (#922) because
  the baseline predates their existence.

## Success criteria (measurable)

1. Blocked stop names the hand surface (seam file path +
   `zfa tdd wire contract:<n>`).
2. `zfa tdd make <contract>` accepts the blocked verdict as a precondition
   or says plainly "implement seam first".
3. Known parked behavior does not fail the phase-2 refactor gate
   (pre-existing-failure economics).
4. Resume instructions are followable as written.

## Hard constraints

- Fix ONLY the blocked-stop messaging, the make precondition, and the
  refactor gate for parked behaviors. Do NOT change the BLOCKED verdict
  itself, the contract lane, or the state machine.
- Must pass `dart analyze` with no new warnings.
- Related: #1007 (BLOCKED verdict), #1544 (blocked defer/skip), #1308
  (hand seam), #922 (baseline tolerance), #741 (baseline cache).

## Remediation sketch

- (a) Messaging-only: the park arm, the terminal `result=blocked` block,
  and verify-red's blocked stderr name the seam path and the wire command
  (entity derived from the contract trace when dotted).
- (b) In make's precondition: contract kind + blocked receipt present +
  the #1544 unchanged-world predicate agrees → refuse with the plain
  "implement seam first" stop (new `implement-seam-first` outcome) naming
  the hand surface. Any change signal (or an unreadable receipt) fails open
  to the existing refusal — the unblock-in-progress world keeps today's
  semantics (the #1542 born-green attestation path is the sanctioned
  recovery there; this fix must not silently certify over a stale receipt).
- (c) The driver collects the parked seams it KNOWS about (persisted
  blocked contracts with a receipt, the still-blocked skips, and this
  run's parkings) and hands `--parked-seam <test-path>` to every refactor
  spawn; refactor tolerates suite failures whose file matches a parked
  seam in BOTH the preflight and the re-proof (fail-closed on unparseable
  transcripts; standalone refactor without the flag keeps the absolute-
  green contract).
