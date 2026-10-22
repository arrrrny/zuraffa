# Bug Assessment: `zfa tdd compose` — a missing composed subject yields a bare runner-error

- **Slug**: 1974-compose-missing-subject-drift
- **Created**: 2026-10-21
- **Source**: https://github.com/arrrrny/zuraffa/issues/1974
- **Verdict**: valid — reproduced against `master` (see `red-evidence.txt`)
- **Severity**: medium — the command fails, but the failure names neither the
  drift nor the recovery; the operator has to know `zfa tdd doctor` exists
  to find out what happened

## Report (summarized)

`zfa tdd compose <id> --feature <f>` fails with a bare
`outcome=runner-error` when the composed subject file is missing from
disk. The summary line carries no reason and no `-->` fix line, so the
recovery path is not discoverable from the command itself. `zfa tdd doctor`
already models the exact same state (`owned-and-missing` drift, verdict
`drift`, prescription `reset` or `repair`) but compose does not point at
it.

## Symptom

Exit 1, summary line only:

```
compose: behavior=A1 outcome=runner-error feature=002-subscription-error-vocabulary
```

The same command fails identically for every other acceptance behavior of
the feature (`A2` … `A11`).

## Reproduction

```sh
cd packages/zuraffa_purchase
rm lib/tdd/002-subscription-error-vocabulary/a1_subject.dart
zfa tdd compose A1 --feature 002-subscription-error-vocabulary
```

Committed as the RED test
`test/plugins/tdd/commands/bug_1974_compose_missing_subject_drift_test.dart`.

## Root Cause (verified against source)

`lib/src/plugins/tdd/commands/compose_command.dart` — step 3 ("the subject
artifact must exist"):

1. Compose resolves the behavior's registry record, then checks the
   recorded subject path. A missing file ends the run with
   `ComposeOutcome.runnerError` — the catch-all label every unnamed
   failure shares.
2. The refusal text names the artifact but prescribes only
   `zfa tdd gen <id>`; it never mentions the registry drift the state
   actually is, and never names the doctor's prescription
   (`zfa tdd doctor <feature> --repair` / `zfa tdd reset <feature>`).
3. The machine verdict (`verdict.v1`) carries `drifts: []` and no `fix`
   field on that path, so a JSON consumer sees a failure with no
   actionable content either.
4. `lib/src/plugins/tdd/commands/doctor_command.dart` (block "2.
   Registry records with missing files") already classifies the state
   exactly: it probes every record's test/subject pair, distinguishes a
   fully-gone record (`collectible` — the surgical `doctor --repair`
   garbage-collect) from a half-missing one (the full `reset`), prints
   `drift: <id>: <path> is recorded but missing from disk` and prescribes
   ONE `--> fix:` line.
5. The classification lived INSIDE the doctor command, so compose could
   not reuse it — the two commands had no shared source of truth for the
   same drift, and compose invented its own (opaque) wording.

`zfa tdd gen --repair` already covers the same drift on the gen side
(issue #1495), so compose was the odd one out.

## Proposed Remediation (implemented in this change)

1. Extract the doctor's owned-and-missing classification into the shared
   service `lib/src/plugins/tdd/services/missing_artifact_drift.dart`:
   `MissingArtifactDrift.classify()` (per-record missing/relocated
   probe, the `drift:` lines, the collectible/half-missing split) and
   `MissingArtifactDrift.prescribe()` (the ONE fix line and its reason,
   with the `--repair` vs `reset` choice unchanged).
2. `doctor` consumes the shared service — its own output is byte-identical
   (the classification, the fix line and the reason text are the same
   strings, moved).
3. `compose` consumes the same service on its missing-subject path: it
   prints the doctor's `drift:` line(s) and the doctor's `--> fix:` line,
   reports the NAMED outcome `drift` (not the catch-all `runner-error`),
   and carries both the drift and the fix in the machine verdict
   (`drifts` / `fix`).
4. The two commands can no longer disagree: compose's line and doctor's
   line for the same file are produced by the same classifier, asserted
   by a committed test that runs both commands against one fixture.

## Risks & Considerations

- The doctor's observable behavior is unchanged — the shared service is a
  MOVE of its logic, and the doctor's own suites (bug #1495, bug #1573,
  bug #874) stay green.
- The compose outcome label for this path changes (`runner-error` →
  `drift`): the label was the opaque thing the issue is about. The two
  compose tests that asserted the old label are updated to the new
  contract; no other consumer parses compose's outcome label (the run
  driver classifies compose's exit code, not its label).
- The remedy text for this path changes from `zfa tdd gen <id>` to the
  doctor's prescription — the issue's explicit ask.
- No store is written, no file is touched, no artifact is regenerated:
  compose still stops before any write.

## Open Questions

- None blocking. The issue also allows "compose regenerates the composed
  subject" as an alternative; the diagnosis branch is the smaller and
  safer change (compose never writes an artifact it did not author), and
  it matches the `gen --repair` precedent on the gen side.
