# TDD Verification — bug #840 (first-class TDD recovery commands)

- **Branch**: `fix/840-tdd-recovery-commands`
- **Date**: 2026-09-02
- **Mode**: bug-fix TDD loop (red -> green -> verify), spec-kit TDD extension v1.1.2
- **Audit context**: same-session audit (not independent cold-context); mutation
  testing not run — recorded as unmeasured below.

## Verdict: PASS_WITH_GAPS

All three recovery commands are green with JSON verdicts, the driver suite is
green, and the full chunked fast suite passes with no new failures. Gaps:
mutation testing unmeasured; the audit was written by the same session that
wrote the fix (recorded, not assumed away).

## 1. Root cause (from the committed assessment, confirmed in code)

Design gap, not a code bug: the TDD pipeline has NO recovery commands. After a
crash/interrupt/merge, generated files exist on disk that `artifacts.json`
does not own; `gen` refuses them with the FR-008 ownership conflict, `run`
refuses at its own preflight, and the only "recovery" was hand-editing
`run-state.json` — the trust violation VISION forbids. Confirmed: no adopt
mechanism in `ArtifactRegistry`, no reset command, no doctor command anywhere
in `lib/src/plugins/tdd/` on master.

## 2. Red evidence (captured, pre-fix)

Driven through `test/plugins/tdd/bug_840_recovery_commands_test.dart` against
the fixture harness (9 tests):

- `gen <id> --adopt` -> `Could not find an option named "--adopt"` (x3 tests).
- `tdd reset <feature>` -> unknown command (x2 tests).
- `tdd doctor <feature>` -> unknown command (x4 tests).

## 3. Green evidence (captured, post-fix)

Implementation:

- **`zfa tdd gen <id> --adopt`** (`commands/gen_command.dart` +
  `services/generated_shape.dart`): when the ownership preflight reports an
  unowned conflict, adopt mode verifies every existing file against the
  GENERATED-SHAPE contract — the `// GENERATED TEST` / `// GENERATED STUB`
  provenance header plus the matching `// behavior_id:` (the assessment's
  open "content shape" question resolves to this structural check:
  deterministic, dependency-free, not satisfiable by arbitrary compiling
  code). Shaped files are adopted in place (never rewritten, never deleted by
  the transactional cleanup); missing halves are generated; shape mismatches
  are refused with `verdict=refused` and the registry untouched. Adoption is
  audit-logged as a JSONL record in `specs/<feature>/tdd/audit.log`
  (`"action":"adopt"`). Refusals follow the house exit pattern (exitCode +
  return, verdict stays the final stdout line).
- **`zfa tdd reset <feature>`** (`commands/reset_command.dart`): loads the
  registry, prints the DIFF SUMMARY before acting (records to drop, owned
  files to delete, foreign count), then deletes EXACTLY the registry-owned
  paths that exist, drops `tdd/artifacts.json` and `tdd/run-state.json`.
  Foreign files (on disk, not registry-owned) are counted, reported as kept,
  and NEVER deleted — the delete set is exactly the union of the records'
  paths. The append-only cycle-log and the audit log are never touched.
- **`zfa tdd doctor <feature>`** (`commands/doctor_command.dart`): reads the
  three stores plus the gen layout and prescribes EXACTLY ONE action with a
  `--> fix:` line, deterministically: adopt (unowned generated-shape files) >
  reset (registry records whose files are missing — resume cannot pass the
  ownership preflight past them; also corrupt run-state) > resume (in-flight
  marker or claims whose matching evidence is missing) > healthy. Same state
  -> same prescription (pure priority over store contents; no clocks).
- **JSON verdicts + exit protocol**: every command's final stdout line is a
  parseable JSON object (`command`, `verdict`, and per-command fields —
  `adopted`/`created`/`audit_log` for gen, `dropped_files`/
  `dropped_records`/`foreign_files_kept` for reset, `prescription`/`fix`/
  `drifts` for doctor). Exit 0 = success/healthy, 1 = refusal/drift.

Test results (all run in this session):

| Suite | Result |
| --- | --- |
| `test/plugins/tdd/bug_840_recovery_commands_test.dart` | 9/9 pass |
| `dart test test/plugins/tdd` (fast tier) | 405/405 pass |
| `dart analyze` (changed files) | 0 issues (47 pre-existing `examples/todo_tdd` issues untouched) |
| `tools/run_tests_chunked.sh` (67/67 chunks) | OK: all chunks passed |
| `dart format .` + `git diff --stat` | no formatting diffs outside the fix files |

## 4. Test strength

- Behavioral asserts: registry contents after adoption, file existence after
  reset (owned deleted / foreign kept), audit-log contents, doctor
  prescriptions, exit codes, and `jsonDecode` of the final verdict line.
- The shape check is exercised from both sides (a real writer-rendered pair
  vs a hand-written file without the header).
- Determinism is asserted by running doctor twice on the same state and
  comparing the encoded verdicts.
- Mutation testing: **unmeasured** (not run in this scope) — recorded as a
  gap.

## 5. Suite notes (honest deltas)

- No existing tests were modified on this branch; the gen JSON verdict is an
  additive final stdout line (existing tests use `contains(...)` asserts).
- Analysis issues (47) are all in `examples/todo_tdd/` (pre-existing); zero
  issues in changed files.
- This branch is based on master per the one-PR-per-bug protocol; it does NOT
  include the #828 transactional-writer changes. The `tdd_command.dart`
  subcommand registration and the doctor command will conflict with the #828
  PR textually (both add `zfa tdd doctor`); the #840 doctor is the superset
  (prescription + JSON verdict) and is the one to keep on merge.

## 6. Remediation tasks

- [ ] Run mutation testing on `generated_shape.dart`, `reset_command.dart`,
  and the doctor prescription order (epic #848 Wave 1 follow-up).
- [ ] On merge with the #828 PR, reconcile the two `doctor` implementations
  (keep #840's prescription + JSON verdict; fold in #828's hash-chain
  verification) and de-duplicate the `tdd_command.dart` registration.
- [ ] Consider wiring `reset` to optionally archive (move aside) owned files
  instead of deleting, if operators need undo.
