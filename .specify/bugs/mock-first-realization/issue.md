# Bug Issue: EPIC: Mock-First Realization — ZikZak 100% TDD lifecycle (supersedes #848)

- **Slug**: mock-first-realization
- **Fetched**: 2026-09-03
- **Issue**: 908
- **URL**: https://github.com/arrrrny/zuraffa/issues/908
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body

"# [ROADMAP] EPIC: Mock-First Realization — ZikZak 100% TDD, 100% VISION-aligned

Supersedes #848 (stub-first TDD-120 epic). This is the plan of record, shaped by live validation across a 5-feature build and a full audit of every past issue.

## The honest claim

"100% TDD-built" = every line of the app is either **generated** by zfa or a **gate-proven hand-delta** — never anything else. "100% generated" is NOT the claim; real adapters carry unforeseeable nuance. The lifecycle makes the split measurable instead of pretending.

## The Contract Ladder (per-behavior state machine)

```
PENDING → RED → MOCKED → REAL → DONE(verified)
```

- **RED** — certified honest red (existing machinery)
- **MOCKED** — green via `zfa mock` contract-conforming mocks; app boots in simulation mode
- **REAL** — mock swapped for real adapter behind the SAME interface; contract suite unchanged and green + differential gate passed; hand-deltas receipted
- **DONE** — verify/mutation green in the real era

`complete(mocked)` and `complete(real)` are reported as distinct states. We never lie about which one we're in.

## Workstreams (issues linked below)

| Priority | Issue | Unblocks |
|---|---|---|
| P0 | make-default→mock + mocked tier | The whole ladder |
| P0 | Spec-parser hardening (all 120 formats) | Corpus start |
| P0 | Generator/runtime version-skew contract | Consumers compile |
| P0 | Template self-hosting (templates born TDD) | Template correctness debt |
| P1 | `zfa tdd realize` (swap + gates + receipts) | The REAL tier |
| P1 | Simulation-mode DI binding | Runnable app on mocks |
| P1 | Differential harness (mock vs real fixtures) | Realization honesty |
| P2 | Corpus economics to minutes | 120-spec feasibility |
| P2 | Treaty + error API unification | Agent determinism |
| P2 | CI referee + provenance dashboards | Publishing |

## Definition of Done for this epic

1. `zfa tdd corpus` drives all 120 ZikZak specs to `complete(mocked)` with zero hand-edits
2. Realization ladder exercised on ≥10 adapter families to `complete(real)`
3. Provenance SBOM per feature: generated / mock / hand-delta ratios, all receipts gate-proven
4. CI referee (#CI issue) returns the corpus verdict on every PR
5. The rebuilt zik_zak publishes from this pipeline

## VISION alignment

§1 spec→mock compile · §2 two-tier referee · §4 error API · §5 token economics · §6 evidence as memory · §8 self-healing templates · §9 simulation worlds as the DEFAULT, not a feature.
"

## Comments

**arrrrny** (?):

"## Backlog ledger (absorbed from closed issues, tracked here until promoted)\n\n- Entity schema management: remove-field / rename-field / entity list (from #783)\n- Real benchmark scenarios + register (from #784)\n- Transactional generation journal / zfa undo (from #787)\n- setup --template day-one starters (from #790; simulation-mode #914 delivers the core dividend)\n- MCP server v2 (from #791; follows ZAP #809)\n- Slang i18n codegen inside the TDD loop (from #834; required for specs 006/091 REAL tier)\n\nPromotion rule: when a P0/P1 workstream needs one of these, it gets its own issue referencing this ledger."
