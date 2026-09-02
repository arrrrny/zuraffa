# Bug Issue: [BUG] make routes acceptance behavior to zfa make A3 (behavior-ID as entity, no --no-entity) — regression of #696 family

- **Slug**: acceptance-make-routing
- **Fetched**: 2026-09-03
- **Issue**: 873
- **URL**: https://github.com/arrrrny/zuraffa/issues/873
- **State**: open
- **Severity**: high (blocks every spec whose acceptance wording mentions "use case")
- **Author**: arrrrny
- **Labels**: bug

## Body

## Regression: acceptance behavior routed to `zfa make <BehaviorId>` (no --no-entity)

Wave-1 rebuild (includes #826/#827/#828/#840, commit 17a40434 lineage), fresh project, spec 004-dependency-injection after a fully-complete spec 001.

### What happened

```
[run] A1 gen -> ok / verify-red -> certified / make -> unexpressible -> deferred (phase 2)
[run] A2 gen -> ok / verify-red -> certified / make -> unexpressible -> deferred (phase 2)
[run] A3 gen -> ok / verify-red -> certified
[run] A3 make -> generation-error
```

Direct rerun:

```
$ zfa tdd make --feature 004-dependency-injection A3
   plan: 4 step(s)
   generation step failed at index 1 (generate use-case/repository scaffolds for A3 (behavior A3)):
   command: `/Users/ahmettok/.local/bin/zfa make A3`
   exit: 1
   output (tail):
❌ Error: Cannot run `zfa make` for "A3": no entity source file was found. Create the entity first with `zfa entity create -n A3` (or pass --no-entity ...)
```

### Analysis

1. This is the #696/#718 family resurfacing on a NEW path: the behavior ID `A3` is passed to `zfa make` as an entity name — and this time WITHOUT `--no-entity` (post-#728 unit routing added that flag; this acceptance-path spawn drops it).
2. Asymmetry suggests keyword routing: A1 "all **data sources** are registered..." and A2 "all **repositories** are registered..." defer as unexpressible; A3 "all **use cases** are registered as factories" gets a 4-step plan whose index-1 step is use-case/repo scaffolding. The planner appears to keyword-match "use case" in the description and route to the entity pipeline, which then needs an entity named A3.
3. Expected behavior per #829: acceptance behaviors either compose (phase 2) or the orchestrator creates a REAL entity from the spec's Key Entities — never `zfa make <BehaviorId>`.

### Repro

1. Fresh `zfa setup --platforms=macos`
2. Run spec 001 to completion (done=21)
3. Copy spec 004, plan, run → stops at `A3:make generation-error`

### Impact

Blocks every spec whose acceptance-scenario wording mentions "use case" (very common in the ZikZak corpus).
