# Bug Assessment: zfa tdd make: uses behavior ID as entity name for zfa make

- **Slug**: tdd-make-uses-behavior-id
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/696
- **URL Policy**: allowlisted (github.com)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

`zfa tdd make` for unit behaviors attempts to run `zfa make <behaviorId>` (lowercased), treating the behavior ID (e.g. `U5`, `u5`) as an entity name. Since behavior IDs are not entity names, `zfa make` fails with `no entity source file was found`. See https://github.com/arrrrny/zuraffa/issues/696.

## Symptom

`zfa tdd make U5 --feature=001-app-bootstrap` exits with code 1 and the message `Cannot run zfa make for u5: no entity source file was found.` — the command lowercases the behavior ID and passes it as an entity name to `zfa make`, which has no entity file for `u5`.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy spec, run `zfa tdd plan 001-app-bootstrap`
4. `zfa tdd gen U5 --feature=001-app-bootstrap`
5. `zfa tdd verify-red U5 --feature=001-app-bootstrap`
6. `zfa tdd make U5 --feature=001-app-bootstrap` → fails as described

## Suspected Code Paths

- `lib/src/plugins/tdd/services/generation_planner.dart:148–159` — The CRUD/use-case branch (step 2) calls `_slugify(summary.behaviorId)` to derive the entity slug, producing `u5` from `U5`. The slug is then passed as `zfa make <slug>` in the plan step.
- `lib/src/plugins/tdd/commands/make_command.dart:477–487` — The make command's entity-existence guard throws `Cannot run \`zfa make\` for "$entityName": no entity source file was found.` when `EntityFieldResolver.entityFileExists` returns false for the passed name.
- `lib/src/plugins/tdd/services/pipeline_runner.dart:93–112` — The runner executes each plan step as `Process.run`, so the failing `zfa make u5` sub-process is what surfaces the error to the user.

## Root Cause Hypothesis

**Confidence: high.**

The `GenerationPlanner` has three expressible branches: entity-bearing, CRUD/use-case, and function-intent. Unit behavior IDs like `U5` match none of these, so the planner should reach the misfire branch (step 4) and report `unexpressible`. However, when the behavior description **does** match the CRUD/use-case keywords (step 2), `_slugify(summary.behaviorId)` is used as the fallback slug, producing `u5` from `U5`. This slug is passed to `zfa make u5`, which fails because no entity file for `u5` exists.

The root cause is in `generation_planner.dart:148–151`: `_slugify(summary.behaviorId)` should **not** be used as the entity name for behaviors whose description is just a unit-level test name without a real entity target. The behavior ID is not a domain entity.

## Proposed Remediation

**Preferred**: In `GenerationPlanner`, before falling into the CRUD/use-case branch, check whether `summary.target` (the entity name parsed from the description, if any) is null. When it is null, the behavior description does not name an entity, so a unit behavior should go directly to misfire/unexpressible rather than being routed through `zfa make <behaviorId-as-slug>`. This is a one-line guard: if `summary.target == null`, return the misfire plan rather than the CRUD plan with a slugified behavior ID.

**Alternative 1**: If the behavior's trace (e.g., `FR-xxx`) maps to a known entity in the feature, extract that entity name instead of the behavior ID. This requires the planner to read the feature's artifact or trace metadata.

**Alternative 2**: Add a `--no-entity` / `--skip-make` flag to `zfa tdd make` that skips the `zfa make` step for unit behaviors entirely. The behavior would only run through `zfa tdd wire` (if wired) or skip generation altogether for pure unit tests.

**Files likely to change**:
- `lib/src/plugins/tdd/services/generation_planner.dart`

**Tests to add or update**:
- Add a unit test in `test/plugins/tdd/generation_planner_test.dart` covering the case where a behavior ID (e.g. `U5`) maps to a description that matches the CRUD/use-case keywords but has no real entity target — verify the planner returns an unexpressible plan rather than a `make` step with a slugified behavior ID.

## Risks & Considerations

- The fix must not regress existing entity-bearing or CRUD/use-case behavior planning (the current CRUD branch correctly handles behaviors whose descriptions name real entities, e.g., "create user repository").
- The fix is scoped to the planner's slug-derivation logic — no changes needed to `PipelineRunner` or the make command itself.
- If the behavior's trace is available at planning time, extracting the entity from the trace (Alternative 1) would be the most semantically correct fix but requires additional registry reading.

## Open Questions

- [NEEDS CLARIFICATION: Does the artifact registry or trace metadata expose the entity that a unit behavior operates on? If so, Alternative 1 would be the preferred fix.]
- [NEEDS CLARIFICATION: Is there an existing `--no-entity` or equivalent flag in `zfa make` that `zfa tdd make` could pass through?]
