# Zuraffa v5 Roadmap

This roadmap replaces the legacy pre-v5 roadmap. It is organized around the actual goal of Zuraffa v5:

> When an AI agent is asked to build a feature, it must go through the Zuraffa pipeline:
> `zfa entity create` → `zfa make` → `zfa build`.
>
> Zuraffa owns the architecture skeleton. Humans and agents fill in the narrow implementation details afterward.

---

## Current v5 status

### What is already true

- `zfa make` is the canonical generator.
- `zfa generate` is removed from the public CLI surface.
- generation planning is normalized and shared across CLI/programmatic flows.
- `.zfa/` project memory exists for plans, runs, decisions, blueprints, manifests, and context.
- platform-aware layout primitives exist (`AdaptiveViewState`, platform resolver, shells).
- hermetic default test execution is working.
- public docs are largely aligned to the v5 workflow.

### What is not fully complete yet

- release identity still needs to be fully aligned around the actual v5 release contract.
- downstream migration is not complete, especially for `Developer/zik_zak`.
- MCP and repo surfaces still need stronger enforcement of the canonical pipeline.
- legacy compatibility residues still exist in historical/example surfaces.
- adaptive layout primitives need stronger real-world proof in a downstream app.

---

## MUST for v5

These items are required to consider v5 complete as a product, not just as a code foundation.

### 1. Release integrity

- align package/documentation/versioning around the real v5 release
- remove remaining contradictions between code, docs, and release messaging
- ship a crisp breaking-change boundary for pre-v5 users

### 2. Canonical AI pipeline enforcement

- ensure all AI-facing surfaces teach the same contract:
  - `zfa entity create`
  - `zfa make`
  - `zfa build`
- ensure MCP advertises and defaults to the same pipeline
- ensure generated comments/examples reinforce the same workflow

### 3. Legacy residue cleanup

- remove outdated public docs, examples, and helper surfaces that still teach removed commands or obsolete flags
- hide or delete placeholder/no-op public surfaces that confuse agents and users
- clean generated/example comments that still imply legacy workflows

### 4. `zik_zak` migration proof

- validate v5 against a real downstream app
- migrate `zik_zak` guidance, config, and planning artifacts to v5
- prove at least one real feature slice through the v5 pipeline
- use `zik_zak` as the real validation target for adaptive layouts and app-scale agent workflows

### 5. Operational `.zfa/` project memory

- ensure `.zfa/` is not just created, but intentionally used
- define what belongs in `blueprints/`, `decisions/`, `manifests/`, and `context.json`
- make `.zfa/` a dependable surface for future agents

---

## SHOULD for v5.x

These are high-value follow-ups that strongly improve adoption and trust.

### 1. `zfa migrate`

A migration command should:

- rewrite legacy `.zfa.json` into v5 structure
- update docs/prompts/specs from legacy command patterns
- seed `.zfa/` where missing
- flag unsupported/ambiguous legacy layouts

### 2. `zfa doctor`

Doctor should validate:

- architecture compliance
- missing generated layers
- stale generated files
- DI completeness
- `.zfa/` integrity
- project setup issues that break agent confidence

### 3. `zfa diff`

Provide a reviewable diff surface before apply/regeneration so humans and agents can inspect exactly what changed.

### 4. GraphQL decision

The product should make a deliberate choice:

- either commit to a real, supported GraphQL generation story,
- or remove/keep hidden incomplete GraphQL public surfaces until they are real.

### 5. Adaptive layout validation in a real app

The current layout primitives are good, but they need downstream validation in actual macOS/mobile divergence.

### 6. Unified root resolution

Consolidate all project-root discovery and remove duplicate discovery logic across runtime-critical paths.

---

## NICE to have

These are useful, but should not block v5 completion.

### Developer tooling

- richer interactive docs and tutorials
- curated recipes for common feature types
- stronger blueprint workflows
- export/reporting helpers for project architecture summaries

### Generation ergonomics

- incremental regeneration improvements
- performance optimizations for large projects
- better progress reporting for larger runs

### Additional framework expansions

- carefully scoped route helpers
- carefully scoped realtime/data-sync scaffolds
- adapter ecosystem work after the v5 core is truly stable

---

## Recommended execution order

### Phase A — close v5 product gaps

1. release/versioning alignment
2. MCP + docs pipeline enforcement
3. legacy residue cleanup in active/public surfaces
4. repo-wide tests guarding the v5 contract

### Phase B — downstream proof

1. migrate `zik_zak` docs/config/guidance
2. seed `.zfa/` for `zik_zak`
3. validate one pilot feature through the v5 pipeline
4. validate adaptive layout migration on a small real slice

### Phase C — v5.x productivity

1. `zfa migrate`
2. `zfa doctor`
3. `zfa diff`
4. stronger `.zfa/` blueprint/decision workflows

---

## Exit criteria for “v5 is complete”

Zuraffa v5 should only be treated as truly complete when:

- all public and AI-facing surfaces teach the same pipeline
- legacy command drift is gone from active/public surfaces
- `.zfa/` is operational and trustworthy
- `zik_zak` (or equivalent downstream app) has a successful migration story
- the framework is proven in a real downstream adaptive-layout scenario
- the release identity is fully aligned with the product story
