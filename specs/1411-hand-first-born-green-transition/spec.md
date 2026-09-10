**Template Version**: `zuraffa-1.0`

# Spec: 1411-hand-first-born-green-transition

GitHub issue: arrrrny/zuraffa#1411 (severity medium; guide §5a item 1,
issues #1259/#1308 hand-step flow; compare #1373's UX gap)

## Summary

The designed hand-step flow (guide §5a item 1, issues #1259/#1308)
prescribes: replace the vacuous-guard test with real assertions,
hand-implement the subject, re-run `zfa tdd run`. When the hand step is
completed BEFORE the pipeline's first pass, no red evidence exists yet in
`cycle-log.md`. Inside run, verify-red sees the already-passing test →
unexpected-green → skipped; make then refuses with `not-certified-red`.
The run stops and there is no supported ordering for "hand-implemented
before first red certification" — a catch-22 (the generated test header
itself instructs "Replace the subject's stub body with real
implementation", i.e. the pipeline's own artifacts prescribe hand-first
without warning). The documented workaround (temporarily reduce the
subject to a wrong-value stub → verify-red → restore → make) synthesizes
red evidence by hand.

## Locked decisions

1. The transition is make's own, flag-gated, EXPLICIT — analogous to
   verify-red's `--re-certify` (issue #1162) but for the no-prior-red
   case: `zfa tdd make <id> --born-green`. It never fires implicitly.
2. The gate shape (ALL of): no certified-red evidence in cycle-log.md
   (make's existing precondition), the target test PASSES an honest
   re-run, the vacuous-guard marker is ABSENT, the test carries the
   `U<n>:hand` attestation header, and the on-disk subject is NOT a
   born-green placeholder (the `subjectIsBornGreenPlaceholder` #1036
   class). Any failed check refuses safe-failure with the exact remedy.
3. The attestation header is the machine-greppable token
   `zfa:tdd: <behaviorId>:hand` — a `//` comment line the hand author
   adds when completing the designed hand step; the run driver's
   hand-off message names the exact line. Detection is content-keyed
   (mirroring the `zfa:tdd: scaffolded` / `zfa:tdd: vacuous-guard`
   markers), case-insensitive on the token.
4. Green evidence is appended through the EXISTING `CycleLogEntry`
   format (kind green, explicitly empty generation block, honest zero
   suite numbers per the #741 skip pattern, `subject-hash` bound to the
   current subject, `- evidence:` note naming the transition). The
   cycle-log FORMAT does not change.
5. The run driver's make `not-certified-red` handling gains the hand-off
   arm keyed on THIS drive's unexpected-green (the passing-test
   signature) + the generated test's content state: attested → name the
   `--born-green` command; un-attested → name the exact header line AND
   the command; marker still present (partial hand step) → name the
   completion + the command. Stop at the named hand step
   `stopped_at=<id>:hand` (the #1308/#1373 messaging parity).
6. Red-first ordering (verify-red → hand-implement → make) is unchanged:
   with certified red present the flag is inert and the normal flow owns
   the behavior; the driver arm fires only on the not-certified-red +
   unexpected-green signature, which an in-order red-first cycle never
   produces.
7. The `born-green` outcome is a distinct terminal make success token
   (accounting distinguishable from `skipped` #694 / `adopted` #1331 /
   `adopted-placeholder` #1345, per the #1331 rationale); the run
   driver's step contract accepts it as exit-0 make success.

## Functional requirements

- **FR-1 (born-green hand transition)**: make `--born-green` with the
  full gate shape satisfied → the target test re-runs honestly, green
  evidence is appended in the existing format, summary
  `make: behavior=<id> outcome=born-green feature=<f>`, exit 0.
- **FR-2 (offer)**: make without the flag, no certified red, marker
  absent + header present → the `not-certified-red` refusal names the
  exact `--born-green` recovery command.
- **FR-3 (safe-failure)**: `--born-green` with the marker still present
  → `vacuous-green` refusal naming the completion remedy; with the
  header absent → `not-certified-red` refusal naming the exact header
  line; with a placeholder subject → `vacuous-green` refusal (the #1036
  class); with a FAILING target test → `not-certified-red` refusal
  naming `zfa tdd verify-red <id>` (the honest red-first remedy).
- **FR-4 (author hand-off)**: run driver on make not-certified-red +
  this drive's unexpected-green → the hand-off message names the exact
  recovery command and stops at `stopped_at=<id>:hand`; the lane
  journal carries the `hand-step=<id>:hand` violation with the #1411
  vocabulary.
- **FR-5 (backward compatibility)**: red-first ordering unchanged; the
  born-green transition fires ONLY for the hand-first ordering (no
  certified red + attested hand step); the generic not-certified-red
  stop stands when the signature does not match.

## Acceptance scenarios

1. **AS-1 (AC1)**: hand-first state (test passes, marker absent, header
   present, no red evidence) → `make <id> --born-green` exits 0 with
   `outcome=born-green` and a green evidence entry.
2. **AS-2 (AC2)**: the same state driven through `zfa tdd run` (fake
   verify-red unexpected-green, fake make not-certified-red) → the run
   stops with the author hand-off naming `zfa tdd make <id>
   --born-green` and `stopped_at=<id>:hand`.
3. **AS-3 (AC3)**: red-first ordering (certified red present) → make
   behaves exactly as before (the flag is inert; e.g. an already-green
   target reports `skipped`, not `born-green`), and a not-certified-red
   stop WITHOUT the catch-22 signature keeps the generic stop.

## Success criteria

- **SC-001**: The hand-first catch-22 has a supported, honest recovery:
  `make <id> --born-green` certifies green only from a genuinely passing
  attested test (measurable: AS-1 passes; AS-1 variant with a failing
  test refuses).
- **SC-002**: The run no longer dead-ends: the stop message names the
  exact recovery command (measurable: AS-2 output contains the command).
- **SC-003**: Red-first compatibility (measurable: AS-3 passes; the
  #1373, #1308/#1309, and make-command suites stay green).

## Assumptions

- The attestation header is hand-added (gen is NOT modified — the
  generated shape is unchanged); the run driver's hand-off and make's
  refusal teach the exact line.
- The transition certifies from the passing target test alone (no suite
  re-run) — the same trust level as the #694 skip transition; the
  subject hash is bound so post-adoption drift still refuses.
- Unit scope: the shape keys on the vacuous-guard seam (unit lane).
  Widget tests are excluded upstream (the 3b scaffolded refusal owns
  the scaffolded shape before the born-green block runs).
