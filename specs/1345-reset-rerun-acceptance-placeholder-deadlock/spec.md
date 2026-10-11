# Spec 1345 — fix: the reset→rerun recovery loop completes for acceptance behaviors (the compose-placeholder re-drive path)

GitHub issue: arrrrny/zuraffa#1345 (severity high — the documented recovery
loop still cannot complete for acceptance-lane behaviors; companion to
#1331/#1338)

## Problem

PR #1338 fixed the reset half of #1331 (reset now deletes all owned files —
verified: dropped=6 deleted=12) and added the `adopted` re-drive outcome. But
the documented `reset → doctor → run` recovery loop STILL cannot complete for
acceptance-lane (BOTH-lane) behaviors, because on re-drive the on-disk subject
is the born-green compose-pipeline placeholder (the exact bytes `zfa tdd gen`
emits for the behavior — the input shape the compose pipeline exists to
rewrite), and the adoption path deliberately withholds for born-green
placeholders (the issue #1036 guard in `make_command.dart`).

Repro:

```
zfa setup crm_check --platforms=ios,macos && cd crm_check
zfa tdd init --skin
# ingest+plan a spec with BOTH-lane acceptance behaviors, then:
zfa tdd run deal_list        # result=complete done=6
zfa tdd reset deal_list      # dropped=6 deleted=12
zfa tdd run deal_list        # -> stopped_at=A2:make subject-drift
zfa tdd doctor deal_list     # prescribes resume — dead-ends the same way
```

Actual output:

```
[run] A2 gen -> ok
[run] A2 verify-red -> unexpected-green
[run] A2 make -> subject-drift
   re-drive adoption withheld: the on-disk subject is a born-green
   placeholder, so the passing target test proves nothing (#1036) —
   the subject-drift refusal stands.
```

Root cause (traced): `make_command.dart` `_tombstonedReDrive` correctly
detects the re-drive, but `_subjectIsBornGreenPlaceholderOnDisk` returns true
for the regenerated acceptance placeholder (the compose pipeline's own
skeleton: the stub gen emits — the shape compose consumes and re-implements),
so `adoptable` is false and the #1036 subject-drift refusal stands. The two
remediations (#1331 adoption, #1036 placeholder guard) are individually
correct but their intersection — a placeholder that is ALSO the sanctioned
product of the acceptance pipeline's re-drive — has no path: adoption would
certify green on a vacuous subject (the exact greenwash #1036 exists to
prevent), and the refusal dead-ends the documented recovery loop.

## Deliverables

1. **Placeholder re-drive path (compose re-entry).** For a tombstoned
   re-drive whose on-disk subject is the born-green placeholder AND whose
   test-list row is acceptance-kind, `zfa tdd make` MUST re-enter the
   acceptance pipeline at compose/make phase-2 — fall through to generation
   planning so the composition fallback re-runs `compose → build` (compose
   re-implements the stub against the feature's green unit anchors, or
   reports already-composed for a surviving composed product) — instead of
   refusing with `subject-drift`. The make records the EXPLICIT
   `adopted-placeholder` outcome (exit 0, green evidence appended binding
   the CURRENT post-re-entry subject hash, generation steps recorded) so
   the accounting stays distinguishable from `green` (generated), `skipped`
   (#694), and `adopted` (#1331).

2. **Run driver accepts the new terminal outcome.** The step runner grades
   `outcome=adopted-placeholder` (exit 0) as a terminal make success — the
   loop advances (green → refactor → done) — and the bug #986 fall-through
   (the driver backfills the green evidence when the child's exit code
   disagrees with its outcome token) covers the new token exactly like
   `skipped`/`adopted`.

3. **Doctor prescription matches reality.** `zfa tdd doctor`'s prescription
   for the `evidence-without-artifact` drift class MUST describe the
   placeholder re-entry: make adopts each re-driven subject whose
   certification the reset invalidated (the `adopted` outcome, #1331) and
   re-enters compose for re-driven acceptance placeholders (the
   `adopted-placeholder` outcome, #1345). The current text promises an
   adoption the #1036 guard withholds for placeholders — unexecutable.

4. **Backward compatibility.** First-time acceptance behaviors (not
   re-drive) continue through the normal compose pipeline; every
   non-re-drive #1036 refusal class (born-green placeholder on a
   non-tombstoned behavior, green-basis drift whose evidence postdates the
   reset, no-tombstone drift), the #1259 vacuous-green gate, the #1331
   `adopted` adoption for non-placeholder re-drives, and unit/widget-kind
   placeholder re-drives (which keep the honest refusal) are unchanged.

## Success Criteria (measurable)

- **SC-1 (acceptance placeholder re-drive completes):** Given a tombstoned
  acceptance-kind behavior whose on-disk subject is the born-green
  placeholder (the gen stub shape) and whose target test passes, `zfa tdd
  make` exits 0 with `outcome=adopted-placeholder`, the composition
  pipeline re-ran (`compose` step recorded in the appended green entry's
  generation block), and the green evidence binds the CURRENT subject hash.
  Measured by behaviors B1/B2.
- **SC-2 (the run loop completes the recovery):** Given the same state,
  `zfa tdd run <feature>` does not stop at `<id>:make subject-drift`; the
  behavior advances green (the make's `adopted-placeholder` token is a
  terminal make success) and the loop completes. Measured by behavior B3.
- **SC-3 (doctor truthful):** doctor's `evidence-without-artifact`
  `--> fix:` line names the placeholder re-entry (`adopted-placeholder`,
  issue #1345) alongside the #1331 adoption, and the prescription remains
  `resume`. Measured by behavior B4.
- **SC-4 (refusal classes preserved):** a tombstoned re-drive whose
  subject is a born-green placeholder on a NON-acceptance row still
  refuses `subject-drift`; a non-tombstoned born-green placeholder still
  refuses; a green-basis drift whose evidence postdates the reset still
  refuses; the #1331 `adopted` outcome for a non-placeholder re-drive is
  unchanged. Measured by behaviors B5/B6.
- **SC-5 (no regressions):** the existing #1331 re-drive suite
  (`bug_1331_make_adopted_re_drive_test.dart`), the #1036 guard suite
  (`make_command_1036_test.dart`), and the #1162 subject-shape suite pass
  unchanged (only the files this spec names are modified).

## Scope Fence (hard constraints)

- Fix ONLY the re-drive path in `make_command.dart` (the
  `_tombstonedReDrive` / `_subjectIsBornGreenPlaceholderOnDisk` /
  adoptable logic), the new outcome token in `generation_plan.dart`, the
  step runner's make-outcome grading, the run driver's bug #986
  fall-through mapping, and doctor's prescription text.
- Do NOT change the core engine cycle, the compose pipeline itself, the
  gen writers, the #1036 guard for non-re-drive cases, or the verify gate.
- Do NOT weaken the #1036 refusal outside the tombstoned acceptance
  placeholder re-drive class; adoption (certifying green WITHOUT
  re-entering the pipeline) stays withheld for placeholders — the re-entry
  re-certifies from actual pipeline output, never from the vacuous pass.
- One PR per issue (arrrrny/zuraffa#1345).

## Risks and Mitigations

- **Risk:** the re-entry greenwashes a placeholder without real
  composition (no green anchors — nothing to compose against).
  **Mitigation:** the re-entry goes through the SAME composition fallback
  as a first drive: zero composable anchors disengages the fallback and
  the honest `unexpressible` stop stands (FR-009 unchanged) — the run
  driver defers it to phase 2 exactly like a first-drive acceptance
  behavior.
- **Risk:** the re-entry swallows a genuine drift (a hand-rewritten
  subject classified as the pipeline placeholder).
  **Mitigation:** the class requires ALL of: the last reset tombstone
  names the behavior (fail-closed timestamp parsing, #1331), the subject
  on disk is a born-green placeholder shape, and the row is
  acceptance-kind. A hand-implemented subject is NOT a placeholder shape
  and keeps the #1331 `adopted` path; a non-acceptance row keeps the
  refusal.
- **Risk:** double-crediting the outcome in run accounting (a token the
  driver grades as failure and ALSO backfills evidence for).
  **Mitigation:** the token joins the same terminal-success list and the
  same bug #986 fall-through branch as `adopted` — one classification,
  evidence backfill stays idempotent (`_hasEvidence` guard).
