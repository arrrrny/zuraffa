# Fix: Bug #1495 — registry-owns-missing-file is unresolvable, remedy is circular

- **Branch**: `fix/1495-registry-owns-missing-file-recovery`
- **Closes**: #1495
- **Related**: #840 (`--adopt`, opposite drift direction), #1429, #683

## Root cause (one paragraph)

`ArtifactRegistry.preflight` refuses when the registry records an artifact
that is missing from disk (`OwnershipConflict`, reason "the registry records
… but it is missing from disk"). The exception's remedy text named
`zfa tdd gen <behavior-id>` — the very command that refused — so the
owned-and-missing drift direction had NO resolving command: plain gen
refuses identically on every retry, `--adopt` refuses ("a registry record
… already exists — nothing unowned to adopt"), and `doctor` prescribed a
full `zfa tdd reset` (drop every record + owned artifact of the feature)
where a surgical record drop would do. The refusal itself is correct as a
DEFAULT — what was missing was the opt-in that resolves it.

## What changed (3 files + tests)

### 1. `lib/src/plugins/tdd/services/artifact_registry.dart`

- New `OwnershipConflictDirection` enum: `existsUnowned`,
  `ownedButMissing`, `pathMismatch`. `OwnershipConflict` carries a
  `direction` (default `existsUnowned` — every pre-existing construction
  site stays valid).
- `OwnershipConflict.toString()` remedy is direction-aware and
  non-circular:
  - ownedButMissing → "Owned-and-missing has nothing to clobber. Run
    `zfa tdd gen <behavior-id> --repair` … or `zfa tdd doctor <feature>
    --repair` …"
  - existsUnowned → "Run `zfa tdd gen <behavior-id> --adopt` after
    verifying the file is a generated artifact." (the pre-#1495 text
    omitted the flag that actually resolves this direction)
  - pathMismatch → points at `zfa tdd doctor <feature>` (deterministic
    diagnosis).
- `preflight` tags each throw with its direction; refusal SEMANTICS are
  unchanged (still refuses, still touches nothing).
- New `dropRecords(Set<String>)`: surgical, atomic (write-and-rename,
  bug #828 discipline) record drop; returns the dropped records;
  registry-only — never touches a file on disk.

### 2. `lib/src/plugins/tdd/commands/gen_command.dart`

- New `--repair` flag (help text documents the #1495 contract).
- On a conflict where `--repair` is set, not a dry-run, and the direction
  is `ownedButMissing`:
  1. drop the stale record FIRST — every later refusal leaves a
     RESOLVABLE state (the survivor degrades to the documented
     exists-unowned direction) instead of a dead end;
  2. shape-verify every surviving half with the SAME
     `matchesGeneratedTestShape`/`matchesGeneratedSubjectShape` checks
     `--adopt` uses; verified survivors are adopted (kept byte-identical,
     protected from the transactional cleanup), never rewritten;
  3. regenerate the gone halves through the normal bounded write flow;
  4. append a fresh record (exactly one record for the id afterwards);
  5. audit-log `{"action":"repair","dropped_record":true,"kept":[…],
     "created":[…]}` to `specs/<feature>/tdd/audit.log` (#840 discipline);
  6. verdict `repaired` (single + `--all` batch chains; the batch verdict
     folds `repaired` between `adopted` and `regenerated`).
- The refusal (non-repair path) now names the RESOLVING command per
  direction — `gen <id> --repair` / `gen <id> --adopt` /
  `doctor <feature>` — in the verdict reason, the stderr line, and the
  StateError (`--> fix:` line). The foreign-owner check (#874) is
  unchanged and still runs first.
- `--adopt` logic and the FR-008 contract are untouched.

### 3. `lib/src/plugins/tdd/commands/doctor_command.dart`

- New `--repair` flag: garbage-collects EVERY registry record whose BOTH
  files are gone (relocation-probe aware — a record whose missing paths
  all relocate is path-form drift for `migrate-paths`, never collected).
  Surgical: healthy records stay, no file on disk is touched,
  audit-logged, verdict `repaired`, exit 0, with the re-drive hint
  (`gen <id> --feature <ref>` / `run <ref>`).
- Safety bound: a record that still owns a surviving half (or a
  relocatable path) is NEVER collected — GC would orphan it; `--repair`
  on that state refuses and keeps the `zfa tdd reset` prescription.
- Without the flag, the fully-gone drift keeps exit 1 and now names the
  surgical `zfa tdd doctor <feature> --repair` fix line (prescription
  `repair`) instead of jumping straight to `reset`.

## Deliberately NOT changed

- The ownership contract: preflight still refuses both drift directions
  by default; nothing regenerates without the operator's explicit
  `--repair`.
- `--adopt` logic, verdict vocabulary, and the reconciliation order.
- The state machine (run driver, make, verify-red, reset).
- `--reclaim` was considered as an alias; the args package has no flag
  aliases and the issue's primary name is `--repair`.

## Verification summary

- `dart analyze` on every touched file: No issues found.
- New suite `test/plugins/tdd/bug_1495_registry_owns_missing_file_test.dart`:
  10 tests, all green (RED evidence: 9 failures pre-fix — see
  `red-evidence.txt`).
- `ArtifactRegistry.dropRecords`: 4 new unit tests in
  `artifact_registry_test.dart`, all green.
- Regression: `bug_1397_path_form_mismatch_test.dart`,
  `artifact_registry_test.dart` fully green; `bug_840_recovery_commands_test.dart`
  and `bug_874_doctor_cross_feature_adoption_test.dart` match their
  PRISTINE-tree baseline failure sets exactly (5 and 4 pre-existing
  environment failures, verified by stashing this branch's changes) —
  zero new failures. One #840 test updated ON PURPOSE: doctor's
  fully-gone prescription is now the surgical `doctor --repair`
  (the remedy text this issue demands); the test comment records why.
- Full details and raw outputs: `test.md`, `tdd/verification.md`.
