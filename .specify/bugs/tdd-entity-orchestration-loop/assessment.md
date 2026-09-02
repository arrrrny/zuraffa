<<<<<<< HEAD
# Bug Assessment: entity orchestration inside the TDD loop — spec Key Entities → entity create → make → wire

- **Slug**: tdd-entity-orchestration-loop
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/829
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The TDD loop never reads the spec's Key Entities. Agents must run `zfa entity create` manually; `zfa tdd wire` then refuses subjects it did not generate. The pure-function path produces empty subjects — it sidesteps the architecture. The REAL pipeline must generate the domain layer. https://github.com/arrrrny/zuraffa/issues/829

## Symptom

`zfa tdd plan` does not extract Key Entities from spec.md. `zfa tdd run` never runs `zfa entity create` for declared entities. Unit behaviors traced to an entity's FR cannot route to the entity pipeline. `zfa tdd wire` refuses subjects with "unrecognized shape". Empty subjects are generated instead of real domain entities.

## Reproduction

1. Spec declares Key Entities (e.g. `ZikZakConfig`, `Listing`)
2. `zfa tdd plan` does not extract them into the plan artifact
3. `zfa tdd run` skips entity creation — behaviors get empty subjects
4. Manual `zfa entity create` + `zfa tdd wire` fails with "unrecognized shape"

## Suspected Code Paths

- `zfa tdd plan` — does not parse Key Entities section from spec.md
- `zfa tdd run` phase 0 — no entity creation step
- `zfa tdd wire` — shape detection rejects valid UnimplementedError stubs
- Entity pipeline (usecases/repos/di) — never invoked by the TDD loop

## Root Cause Hypothesis

High confidence: the TDD loop was designed for pure-function generation and never integrated the entity pipeline. Plan doesn't extract entities, run doesn't create them, and wire's shape detection is too strict for current stubs.

## Proposed Remediation

**Preferred**: (1) `zfa tdd plan` extracts Key Entities from spec.md into the plan artifact. (2) `zfa tdd run` phase 0: idempotent `zfa entity create` + `zfa build` before behaviors. (3) Unit behaviors traced to entity FRs route to entity pipeline. (4) Fix wire shape detection. (5) Idempotent entity reuse — never overwrite without `--force`.

**Alternatives** (optional):
- Manual entity creation before TDD run — the current workaround; doesn't scale to 120 specs.

**Files likely to change**:
- Plan command (entity extraction)
- Run command (phase 0 entity creation)
- Wire command (shape detection fix)
- Test suite

**Tests to add or update**:
- Plan extracts entities from spec with Key Entities section
- Run creates entities before driving behaviors
- Wire accepts current gen'd stub shape
- Entity reuse: existing entity not overwritten

## Risks & Considerations

- Entity creation must be idempotent — never overwrite hand-tuned fields
- Wire shape detection must accept valid stubs without false negatives
- 60+ specs affected (all data-bearing specs)
- Depends on #827 (artifact namespacing) for correct paths

## Open Questions

- [NEEDS CLARIFICATION: Should entity extraction use AST parsing or regex on the spec markdown?]
- [NEEDS CLARIFICATION: What is the correct stub shape that wire should accept?]
=======
# Assessment: entity orchestration inside the TDD loop (issue #829)

> NOTE (provenance): the task brief expected a committed `assessment.md`
> under this slug; none existed anywhere in the repository (searched every
> ref). The remediation below restates the issue's own "Required (system
> fix)" section and the hard constraints attached to the bug — it adds no
> new triage. Root-cause evidence gathered at fix time is recorded in
> `fix.md` and `tdd/verification.md`.

## Root cause (from the tracker issue, confirmed empirically at fix time)

Four independent gaps compose into the sidestep:

1. `SpecParser` never reads the spec's `### Key Entities` section, and
   `zfa tdd plan` therefore writes a test list with no entity record
   (empirical RED R1: `grep -i "key entities" tdd/test-list.md` finds
   nothing on a corpus-shaped spec).
2. `zfa tdd run` has no phase 0: nothing creates the declared entities
   before behaviors are driven (RED R2: `lib/src/domain/entities` absent
   after a `result=complete` run).
3. The planner's unit-kind dispatch (bug #718) sends EVERY `U<n>` behavior
   to the plain-function surface regardless of what its FR says, so
   data-bearing unit behaviors get empty `String subject_<id>()` subjects
   (RED R3: the run exits 0 with the domain layer entirely missing).
4. `zfa tdd wire` classifies "already implemented" vs "unrecognized shape"
   with a raw `contains('UnimplementedError')`. The gen'd stub's header
   comment ("Throws [UnimplementedError] until the real implementation
   lands") survives `tdd func`'s line-splice scaffold, so every
   pipeline-generated subject that func had scaffolded was refused with
   `unrecognized shape` (RED R4, real CLI, exit 1).

Plus the overwrite hazard underlying remediation 5: the core
`zfa entity create` regenerates the entity file unconditionally, so a
re-invocation silently destroys hand-tuned fields (RED R5: an entity
created with `email:String` lost the field on a second create).

## Remediation (the issue's Required list, as implemented)

1. `SpecParser.parseKeyEntities` extracts `### Key Entities` bullets
   (generic suffixes stripped, backticked `name: Type` field pairs kept);
   `zfa tdd plan` renders them as a `## Key entities` table in the test
   list; `TestListReader` skips the section when resolving behavior rows
   and exposes `readEntities()`.
2. `zfa tdd run` phase 0 (before the baseline and phase 1): for each
   declared entity, reuse when its file exists, else spawn
   `zfa entity create -n <Name> --field <f>...`; then `zfa build` once
   when anything was created. Failures stop the run honestly
   (`result=runner-error`, `stopped_at=phase-0:...`).
3. Unit behaviors whose description names a declared Key Entity route to
   the entity pipeline: `entity create -n <Name>` (realized idempotently)
   → `make <Name>` (usecases/repos/di) → `tdd wire <id> --entity <Name>`
   → `build`.
4. Wire classifies by executable code (line-comment-stripped), not raw
   text: comment-only mentions are gen-stub residue → `already-wired`;
   an executable `UnimplementedError` in a non-stub shape is still
   refused (U-W5 preserved).
5. Make drops any `entity create -n <Name>` step whose entity file
   already exists (`already exists — reuse`), which gates both the new
   unit entity pipeline and the pre-existing #758 acceptance create step.

## Hard constraints (attached to the bug)

- Entity creation must be idempotent — enforced at every loop spawn site
  (phase 0 and the make plan); the core command's overwrite semantics are
  out of this bug's scope but the loop never re-invokes it over an
  existing entity.
- Wire shape detection must accept valid stubs — U-W5's "never rewrite a
  file you did not generate" contract is explicitly preserved.
- Depends on #827 (per-feature artifact namespacing) — #827 is unmerged;
  this fix reads entities from the same feature's own
  `specs/<feature>/tdd/test-list.md` the behaviors come from, so it
  introduces no new cross-feature coupling and stays namespacing-neutral.
- Minimal change, one PR for this bug.
>>>>>>> 60c87542 (fix(829): TDD loop orchestrates entities from spec Key Entities)
