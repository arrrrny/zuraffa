**Template Version**: `zuraffa-1.0`

# Bug Spec: 1585 — the bug_828 doctor suite invokes `tdd doctor --feature`, a flag the command does not accept

**Input**: GitHub issue #1585 — 4 of the 13 tests in
`test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` fail with the
`tdd doctor` usage text, because the suite's `doctor()` helper passes
`--feature <name>` while `zfa tdd doctor <feature> [--project <path>]` takes the
feature positionally and declares only `--json` / `--repair` / `--project`.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: the `doctor()` helper in
  `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` MUST invoke
  `zfa tdd doctor` in the form the command declares — the feature as a POSITIONAL
  argument (`['tdd', 'doctor', feature, '--project', fx.root.path]`) — so the
  invocation is accepted by the arg parser and the doctor verdict is reached.
  Every other caller in the repo already uses this form
  (`bug_1495:380`, `bug_1324:294`, `bug_1264:142`, …); the command signature is
  the source of truth (same rule the #1573 fix applied, commit `8c927cf1`).
            traces: DoctorCommand
- **FR-002**: the four doctor tests that currently die on the usage error MUST
  reach their assertions and pass — tampered hash chain, pending journal,
  consistent stores, and green-claim-without-evidence — while the other nine
  tests in the file stay green (13/13).
- **FR-003**: `zfa tdd doctor` MUST recompute the evidence hash chain of every
  schema-1 cycle-log entry and report a mismatch as drift with a `--> fix:`
  line and exit 1: every `- prev-hash:` link must chain to the previous
  recorded `- hash:`, and every `- hash:` must equal the sha256 over
  `CycleLog.payloadFromFields(...)` — the canonical payload the writer and the
  doctor share. Legacy hash-less entries stay valid and are never failed.
  The walk existed at `1183009e` (`_verifyChain`) and was dropped by the
  `b6afda42` (#840) doctor rework; `cycle_log.dart` still documents it as the
  doctor's job.
            traces: DoctorCommand
- **FR-004**: the zero-drift pin MUST read the doctor's current machine
  contract — the verdict envelope's `verdict: healthy` + empty `drifts` array
  on the final stdout line (bug #840 / issue #969) — never the retired
  `doctor: feature=<f> drifts=<n>` summary line.

## Layer Contracts

**Test/CLI helper**:
- `doctor() -> Future<String>` (bug_828 suite) — argv must match
  `DoctorCommand`'s declared invocation `zfa tdd doctor <feature> [--project <path>]`.

**Doctor**:
- `DoctorCommand._hashChainDrifts(List<ParsedCycleEntry>) -> List<String>` —
  pure walk over the parsed entries; empty list = chain intact.

## Acceptance Scenarios

1. **Given** the pre-fix helper (`'tdd', 'doctor', '--feature', feature, …`)
   **When** `dart test --preset=all test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
   runs **Then** the captured output is the doctor usage text and 4 doctor tests
   fail (`+9 -4`) — the RED reproduction from the issue.
   **Type**: acceptance
2. **Given** the fixed helper (`'tdd', 'doctor', feature, …`) **When** the same
   command runs **Then** `13/13` pass, the four doctor tests exercising the real
   drift logic instead of the usage error.
   **Type**: acceptance
3. **Given** a cycle-log whose schema-1 entry was edited after certification
   (`- exit: 1` → `- exit: 2`, the recorded hash untouched) **When** `zfa tdd
   doctor <feature>` runs **Then** the run reports `hash chain broken` as drift,
   prints a `--> fix:` line naming the restore + re-certify remedy, and exits 1.
   **Type**: acceptance
4. **Given** consistent stores whose cycle-log carries only legacy hash-less
   entries **When** the doctor runs **Then** the verdict envelope reads
   `healthy` with an empty `drifts` array and the exit code is 0.
   **Type**: acceptance
