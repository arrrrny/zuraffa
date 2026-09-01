# Issue #657: fix(tdd): `zfa tdd make` returns unexpressible for non-entity behaviors — no generator surface for plain functions

- **State**: open
- **Fetched from**: https://github.com/arrrrny/zuraffa/issues/657
- **Fetched at**: 2026-08-31

## Summary

`zfa tdd make` returns `unexpressible` for behaviors that don't map to a zuraffa generator surface. The TDD cycle (`zfa tdd run`) stops at the first such behavior, blocking the whole feature.

Two concrete cases from the forklift repo:

1. **Spec 004 (cloud-agent-task-dispatch), U1** — `` `render` returns a non-empty string for a fully populated task ``
2. **Spec 003 (user-communication-interface), U3** — `System MUST provide a conversational interface between the operator`

Both hit: `zfa tdd make: cannot plan a generation for behavior ... no generator surface maps the behavior description to a \`zfa entity create\` / \`zfa make\` / \`zfa build\` invocation.`

## Root cause

The zuraffa generation pipeline (the planner behind `tdd make`) only maps behavior descriptions to these generator surfaces:

- `zfa entity create` — domain models
- `zfa make` — repositories, services, providers
- `zfa build` — build targets

Plain functions (rendering, formatting, parsing, pure logic) have no generator surface. The planner correctly identifies this as `unexpressible`, but the TDD cycle treats it as a hard stop rather than a signal to fall back to manual implementation or a `zfa func`-style generator.

## Reproduction

```bash
# From any repo with a spec that has non-entity behaviors:
zfa tdd init --feature <feature>
zfa tdd run --feature <feature>

# The run stops at the first non-entity behavior:
# [run] U1 gen -> ok
# [run] U1 verify-red -> certified
# [run] U1 make -> unexpressible
# zfa tdd run: step failed — behavior=U1 step=make outcome=unexpressible
```

## Proposed fix

Add a generator surface for plain functions/methods — e.g. `zfa func` or `zfa method` — so the planner can map behavior descriptions like "render X as a string" or "parse Y into Z" to a concrete generation target. At minimum:

1. **New generator surface** — `zfa func` that scaffolds a standalone no-argument function (or a method on an existing class), preserving the generated function name and deriving its return type from the behavior description.
2. **Planner mapping** — extend the generation planner to recognize verb phrases like "render", "format", "parse", "compute", "return" as function-generation intents.
3. **Fallback behavior** — when `make` would be `unexpressible`, log a clear message: `"no generator for '<verb>'; implement manually at <stub_path>, then re-run"` instead of hard-stopping the whole run.

## Verification

- A spec with a supported `render`-type behavior (`U1: render returns a non-empty string for a fully populated task`) should generate a working no-argument `String render()` implementation via `zfa tdd make`.
- The TDD cycle should complete recognized, supported plain-function intents without manual intervention.
- Unmapped behaviors remain `unexpressible` and require manual implementation at the recorded subject path; they are not completed automatically.
- Existing entity/service/repository generation is unchanged.

## Context

Discovered while running `zfa tdd run` on forklift specs 003 and 004. Both stopped at the first non-entity behavior. Spec 004's U1 (`render`) and spec 003's U3 (`conversational interface`) are both plain-function behaviors that the current generator pipeline cannot express.
