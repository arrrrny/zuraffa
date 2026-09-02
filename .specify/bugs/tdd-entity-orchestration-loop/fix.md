# Fix: entity orchestration inside the TDD loop (issue #829)

## What changed

The TDD loop never read the spec's Key Entities: plan didn't extract them,
run didn't create them, every unit behavior went to the plain-function
surface (empty subjects that sidestep the architecture), and `tdd wire`
refused valid pipeline-generated subjects with `unrecognized shape`. Five
changes, one per remediation item:

1. **Plan extracts Key Entities.** `SpecParser.parseKeyEntities` reads the
   spec's `### Key Entities` section (any heading level, case-insensitive):
   each `- **Name**: prose` bullet becomes a `SpecEntity` — the generic
   suffix stripped (`ToggleParams<I, F>` → `ToggleParams`), bullets that do
   not resolve to a valid Dart identifier skipped, and backticked
   `` `name: Type` `` pairs kept as fields. `plan_command` renders them as a
   `## Key entities` table (`| entity | fields |`) appended to the test
   list — the same artifact, so plan stays the single writer. A spec
   without the section produces a byte-identical list shape (no section).
2. **The reader speaks the section.** `TestListReader.read()` skips
   `## Key entities` rows instead of rejecting them as malformed (the
   reader is the single format contract, so it must speak every shape plan
   writes); the new `readEntities()` returns the declared entities with
   fields normalized to the `name:Type` argv shape
   (`zfa entity create --field` parses).
3. **Run phase 0.** After state reconciliation and BEFORE the baseline and
   phase 1, the driver creates every declared entity that does not exist
   yet (`[run] phase-0 entity <Name> -> created|reused`, spawning
   `zfa entity create -n <Name> --field <f>...` through the same
   `--zfa-bin`/deadline machinery as every other spawn) and runs
   `zfa build` once when anything was created
   (`[run] phase-0 build -> ok`, skipped on pure reuse). A failed or hung
   spawn stops the run honestly: `result=runner-error`,
   `stopped_at=phase-0:entity|build`, non-zero exit, no behavior driven.
   A feature whose list declares no entities runs no phase-0 spawn at all —
   every pre-829 run is unchanged.
4. **Entity-traced unit behaviors route to the entity pipeline.** Make
   resolves the record's description against the declared entities
   (case-sensitive `\b<Name>\b`, first match in declared order) and passes
   the trace into the planner (`BehaviorSummary.entityTraced`). A traced
   `U<n>` behavior plans `entity create -n <Name>` → `make <Name>`
   (usecases/repos/di — the domain layer) → `tdd wire <id> --entity <Name>`
   → `build`, exactly the pipeline the issue names. Untraced unit behaviors
   keep the bug #718 func surface; acceptance and legacy-dashed ids keep
   their existing routing untouched.
5. **Idempotent entity creation + the wire shape fix.** Make realizes every
   `entity create -n <Name>` plan step idempotently: when the entity file
   already exists (`entity_lookup.locateEntityFile`, canonical
   `lib/src/domain/entities/<snake>/<snake>.dart` plus recursive fallback —
   the same lookup wire already used, now shared) the step is dropped with
   `entity <Name> already exists — reuse (never overwrite hand-tuned
   fields)`. The core command regenerates unconditionally, so the LOOP must
   never re-invoke it over an existing entity — this gates the new unit
   entity pipeline AND the pre-existing #758 acceptance create step. Wire's
   classification is now comment-aware (`_hasExecutableUnimplementedError`):
   an `UnimplementedError` mention confined to comments (the gen stub
   header that `tdd func`'s scaffold preserves) is residue →
   `already-wired`, exit 0; an executable `UnimplementedError` in a shape
   this command did not generate is still refused (U-W5 unchanged).

## Files

- `lib/src/plugins/tdd/services/spec_parser.dart` — `SpecEntity`,
  `EntityField`, `parseKeyEntities`.
- `lib/src/plugins/tdd/commands/plan_command.dart` — the `## Key entities`
  section + the extraction report line.
- `lib/src/plugins/tdd/services/test_list_reader.dart` — section skip in
  `read()`, `readEntities()`, `DeclaredEntity`.
- `lib/src/plugins/tdd/services/entity_lookup.dart` — NEW shared
  `locateEntityFile`/`toSnakeCase` (wire's private pair, deduped).
- `lib/src/plugins/tdd/commands/run_command.dart` — phase 0
  (`_runEntityPhaseZero`), spawn plumbing, honest stops.
- `lib/src/plugins/tdd/services/generation_planner.dart` —
  `BehaviorSummary.entityTraced`, the unit entity-pipeline plan.
- `lib/src/plugins/tdd/commands/make_command.dart` — `_tracedEntityFor`,
  `_gateExistingEntityCreateSteps` (the `-n` argv shape parsed from the
  plan; an unexpected shape fails open to the ungated step).
- `lib/src/plugins/tdd/commands/wire_command.dart` — comment-aware
  classification; the shared entity lookup.

## Out of scope (documented, unchanged)

- The core `zfa entity create` still overwrites an existing entity when
  invoked explicitly (R5's probe). The loop never does; fixing the core
  command's semantics (a `--force` guard + diff report) belongs to the core
  command's own lineage, not the TDD loop's orchestration bug.
- #827 (per-feature artifact namespacing) is unmerged; nothing here
  deepens cross-feature coupling.
