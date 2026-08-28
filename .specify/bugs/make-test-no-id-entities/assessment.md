# Bug Assessment: zfa make --test still fails for no-id entities

- **Slug**: make-test-no-id-entities
- **Created**: 2026-08-27T13:15:21Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/514
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

#510 ("gate no-id loud failure on id-dependent plugins", Closes #508) claims to make `zfa make <Entity> --test` work for no-id entities. It does not: `zfa make AuthRequest --test` still errors with "the entity has no id field." The gate was correctly moved to fire only when an id-dependent plugin is active, but `zfa make --test` itself resolves to the plan `[usecase, test]`, and `usecase` is id-dependent — so the gate still fires. See https://github.com/arrrrny/zuraffa/issues/514.

## Symptom

`zfa make <NoIdEntity> --test` fails with "the entity has no id field" because the `--test` flag implicitly pulls in the id-dependent `usecase` plugin, which trips the #307 no-id gate even though only id-neutral test files are wanted.

## Reproduction

```bash
# in apps/zikzak_demo
zfa make AuthRequest --methods=get,update,toggle --test --dry-run
# AuthRequest is a no-id entity; resolves to plan [usecase, test]
# => ❌ Cannot generate architecture for "AuthRequest": the entity has no id field.
```

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Directly blocks the bulk mocktail-removal regeneration of `apps/zikzak_demo` (~250 test files) and `apps/forklift` for no-id entities (per AGENTS.md STOP-ON-ROADBLOCK these must be produced by `zfa`, not hand-edited).

## Open Questions

- [NEEDS CLARIFICATION: confirm the exact location of the no-id gate and the `_idDependentPlugins` list in `lib/src/commands/make_command.dart`, and whether `--test` implies `usecase` via `resolvePlan`.]
- [NEEDS CLARIFICATION: confirm the safe condition under which id-dependent plugins implied by `--test`/`--mock` can be dropped during no-id regeneration.]
