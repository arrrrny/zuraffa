**Template Version**: `zuraffa-1.0`

# Spec: 1329-failed-step-zero-diagnostics

## Summary

During a `zfa tdd run` on a lane-format (spec-1000) feature, a `gen` step
failed with `outcome=error` and ZERO diagnostics were recorded anywhere:
`tdd/cycle-log.md` had no cycle entry for the failed gen, `tdd/journal.json`
recorded only `"violations": ["stopped_at=A7:gen"]` (no error message, no
exit code, no step output), and no log file was written under the feature
`specs/<feature>/tdd/` directory or the project. The only evidence was the
driver's stdout line `step failed — outcome=error`. The identical step then
succeeded non-deterministically on immediate retry, leaving nothing on disk
to diagnose. This feature makes the run driver's error-outcome path record
the same diagnostic evidence the red/green cycles already record: the
spawned command, the exit code, and a truncated stderr/stdout tail, in BOTH
the append-only cycle log and the journal entry — appended, never
overwritten, so transient failures leave a permanent audit trail.

## Acceptance Scenarios

1. **Given** a driven step (`gen`, `verify-red`, `make`, or `refactor`)
   fails with `outcome=error` (the honest-stop arm: any spawned step whose
   result is not success and not one of the named deferral/skip/block
   arms) **When** the run driver stops the feature **Then**
   `tdd/cycle-log.md` gains ONE new cycle entry for the failed behavior
   carrying the same evidence shape the red/green cycles record: `- kind:`
   `error`, `- command:` (the spawned command line), `- exit:` (the step
   process's exit code), and an `- output:` block holding the step's
   stderr/stdout tail truncated to 200 lines; the entry participates in the
   per-behavior tamper-evident hash chain like every other entry.
2. **Given** the same failed step **When** the lane journal entry is
   appended to `tdd/journal.json` **Then** the entry carries the error
   detail — the failed step, its outcome token, the exit code, the spawned
   command, and the truncated stderr/stdout — as a structured `error`
   object (schema-declared, additive), plus a machine-greppable
   `step_error=<behavior>:<step> outcome=<o> exit=<n>` violations line
   alongside the existing `stopped_at=<behavior>:<step>`; the entry no
   longer reads only `"violations": ["stopped_at=A7:gen"]`.
3. **Given** the user re-runs after a failure and the previously failing
   step now succeeds **When** the retry completes **Then** the previous
   failure's diagnostics REMAIN in `tdd/cycle-log.md` and
   `tdd/journal.json` (both are append-only; the retry's entries are
   appended after the failure's entries, never a rewrite), providing the
   audit trail for transient failures; the retry also re-drives the failed
   step from its current state (the error entry never counts as red or
   green evidence).
4. **Given** steps that succeed (or the existing deferral/skip/block stop
   arms: skipped make, deferred unexpressible, unexpected-green,
   not-green refactor, widget refusal, blocked contract) **When** a run
   completes or stops through those paths **Then** their recorded evidence
   is byte-identical to today's: the fix ONLY adds recording to the
   error-outcome path (the honest-stop arm and the pre-spawn runner-error
   arm); no cycle entry kind, summary line, exit code, or receipt verdict
   changes.

## Functional Requirements

- **FR-001** (failed step diagnostic recording): When any driven step
  fails through the honest-stop arm (a spawned `gen` / `verify-red` /
  `make` / `refactor` step whose `StepResult.success` is false and whose
  outcome matches no named deferral/skip/block arm), the run driver MUST
  append one `tdd/cycle-log.md` cycle entry containing the spawned
  command, the exit code, and the step's stderr/stdout tail truncated to
  200 lines (the tail, with a truncation marker naming how many lines were
  dropped) — the same evidence shape the red/green cycles already record
  (behavior, kind, criterion, test, command, exit, at, output).
- **FR-002** (journal error detail): The lane journal entry written for a
  run stopped on a failed step MUST include a structured `error` object —
  `behavior`, `step`, `outcome`, `exit_code`, `command`, `output` (the
  same truncated tail) — and a `step_error=...` violations line, not just
  `stopped_at`. The journal schema document (`tdd/journal.schema.json`,
  generated from the model) declares the new optional field so writer and
  schema cannot drift.
- **FR-003** (diagnostics survive retry): Cycle-log and journal writes for
  failed steps MUST be append-only (the existing writers' discipline): a
  successful retry appends its own entries and preserves every earlier
  failure entry. An `error`-kind cycle entry MUST NOT satisfy red or green
  evidence reconciliation (the retry re-drives the failed step honestly).
- **FR-004** (backward compatibility): Successful steps keep recording
  their normal evidence (command, exit code, stdout tail); the existing
  deferral/skip/block stop arms, the summary line shape, exit codes, and
  receipt verdicts are unchanged. The pre-spawn `runner-error` arm
  (entrypoint resolution failed before any spawn) records what is known:
  no spawned command, exit -1, and the resolution error message as the
  captured output.
- **FR-005** (never a gate): A failed diagnostic write (cycle-log or
  journal) is reported on stderr and never fatal to the driving that
  already happened — the receipt discipline every record write in the
  driver follows.

## Success Criteria

- **SC-1**: A driver run against the scripted fixture with a failing gen
  step (exit 1, stdout `zfa tdd gen: boom`) leaves `tdd/cycle-log.md`
  with an `error` entry whose output block contains `zfa tdd gen: boom`,
  whose `- exit:` is `1`, and whose `- command:` names
  `tdd gen <behavior>`.
- **SC-2**: The same run's `tdd/journal.json` last entry parses with an
  `error` object (`step: gen`, `outcome: error`, `exit_code: 1`,
  `output` containing `boom`) and validates against the shipped journal
  schema (the generated `validateEntry` walk).
- **SC-3**: Re-running after scripting the same step to succeed leaves
  the failure's error entry and journal error object in place (append
  order preserved: failure entry precedes the retry's entries) and the
  run completes all green.
- **SC-4**: The existing driver suites (`run_command_test.dart`, the
  two-cycle lane suites, the unified journal suite) pass unchanged.
