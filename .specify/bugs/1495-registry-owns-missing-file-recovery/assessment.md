# Bug Assessment: zfa tdd gen — registry-owns-missing-file is an unresolvable ownership conflict

- **Slug**: 1495-registry-owns-missing-file-recovery
- **Created**: 2026-09-13
- **Source**: https://github.com/arrrrny/zuraffa/issues/1495
- **Verdict**: valid — recovery dead-end confirmed by code reading + reproduction harness (see test.md RED)
- **Severity**: high — one deleted file pair bricks the behavior's entire TDD loop; the documented remedies all refuse

## Report (summarized)

`zfa tdd gen <id>` refuses with an `OwnershipConflict` when the registry
records an artifact that is missing from disk, and the refusal's remedy is
the very command that refused. `--adopt` covers only files-without-records;
no command covers records-without-files. `doctor` prescribes a full
`reset`, which drops every record and owned artifact of the feature —
disproportionate for a stale record with nothing on disk behind it.

## Symptom

Exit 1, verdict `refused`:

```
OwnershipConflict: the registry records test file "<path>", but it is
missing from disk. Refusing to overwrite non-owned content. Run
`zfa tdd gen <behavior-id>` after resolving the conflict.
```

The remedy repeats the refusing command. `--adopt` refuses with "a registry
record ... already exists — nothing unowned to adopt". The state is
unresolvable through the CLI.

## Reproduction

Covered by the committed RED tests (`test.md`, step 2): seed a registry
record for a behavior, delete both artifact files from disk, run
`zfa tdd gen <id>` → circular refusal; run `zfa tdd gen <id> --repair` →
usage error "Could not find an option named --repair" (pre-fix).

## Root Cause (verified against source)

`lib/src/plugins/tdd/services/artifact_registry.dart` — `preflight()`:

1. A prior record for the behavior id makes gen's computed paths a "reuse"
   candidate. The gate then requires BOTH recorded files to exist
   (`File(...).exists()`); either one missing throws `OwnershipConflict`
   with reason "the registry records <role> file <path>, but it is missing
   from disk".
2. `OwnershipConflict.toString()` appends the remedy "Run
   `zfa tdd gen <behavior-id>` after resolving the conflict" — for THIS
   direction that is the refusing command itself (circular), and for the
   opposite (exists-unowned) direction it omits the `--adopt` flag that
   would actually resolve it.
3. `gen_command.dart` catch block refuses (verdict `refused`) for any
   conflict unless `--adopt` is set; the adopt reconciliation path refuses
   when `findRecord(behavior.id) != null`, so it can never repair
   records-without-files.
4. `doctor_command.dart` classifies the state (records whose files are
   missing, no relocation match) and prescribes `zfa tdd reset <feature>`.
   Reset drops ALL records + owned artifacts of the feature. No surgical
   garbage-collect exists.

The state has a key property the code does not exploit: owned-and-absent
has NOTHING to clobber. The refusal exists to protect on-disk content;
when the recorded file is gone there is no content to protect — dropping
the record and regenerating cannot overwrite anything. The refusal is
correct as a DEFAULT (the operator must opt in, because the file could
have been moved/deleted by accident and other stores may reference it) —
what is broken is that no opt-in exists.

## Proposed Remediation (implemented in fix.md)

1. `OwnershipConflict` gains a `direction` discriminator
   (`ownedButMissing` vs `existsUnowned`); `toString()` remedy becomes
   direction-aware and non-circular: owned-but-missing →
   `zfa tdd gen <id> --repair` / `zfa tdd doctor <feature> --repair`;
   exists-unowned → `zfa tdd gen <id> --adopt`.
2. `ArtifactRegistry.dropRecords()` — surgical, atomic record drop (same
   write-and-rename discipline as every registry write). Registry-only;
   touches no file on disk.
3. `zfa tdd gen <id> --repair`: on an owned-but-missing conflict, drop the
   stale record, keep surviving halves ONLY after the same generated-shape
   verification `--adopt` uses (adopt discipline; survivors are adopted,
   never rewritten), regenerate missing halves, append a fresh record,
   audit-log `{"action":"repair", ...}` to the feature's `audit.log`,
   verdict `repaired`. Refusals inside the repair path leave the state
   RESOLVABLE (record dropped first, so the unshaped-survivor case
   degrades to the documented exists-unowned recovery instead of a dead
   end).
4. `zfa tdd doctor <feature> --repair`: garbage-collects every record whose
   BOTH files are gone (relocation-probe aware — relocated records are
   path-form drift for `migrate-paths`, never GC'd). Half-missing records
   still own a file on disk → repair refuses and keeps the `reset`
   prescription (GC would orphan the surviving half). Without the flag the
   missing-files drift for fully-gone records now names the surgical
   `doctor --repair` fix line instead of jumping straight to `reset`.

## Risks & Considerations

- Constraint check: preflight refusal semantics unchanged (still refuses
  by default); `--adopt` logic untouched; state machine untouched; only
  conflict-direction plumbing, remedy text, and two NEW opt-in flags.
- `dropRecords` is additive to the registry; append/preflight/register
  behavior byte-identical.
- Audit trail parity with #840: repair writes the same JSONL
  `specs/<feature>/tdd/audit.log` (action `repair` vs `adopt`).
- The `--all` batch threads the flag per row; a refusing row still stops
  the batch honestly at that row.
- Doc-comment updates in gen/doctor/registry headers keep VISION §4
  (errors-are-an-API) honest.

## Open Questions

- None blocking. `--reclaim` was considered as an alias; the args package
  does not support flag aliases, and the issue's primary name `--repair`
  is implemented.
