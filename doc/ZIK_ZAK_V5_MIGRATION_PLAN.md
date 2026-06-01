# ZikZak → Zuraffa v5 Migration Plan

This plan migrates `Developer/zik_zak` from legacy/transition-era Zuraffa usage to the v5 contract.

The goal is not a big-bang rewrite.
The goal is to make `zik_zak` a proof-quality downstream app for the v5 pipeline.

---

## Current assessment

### Already compatible
- project structure already uses `lib/src/domain`, `lib/src/data`, `lib/src/di`, and `lib/src/presentation`
- entities already live under `lib/src/domain/entities`
- app already depends on `zuraffa` and `zorphy_annotation`
- app already has a large generated architecture footprint

### Not yet migrated
- `.zfa.json` still uses legacy flat keys
- `.zfa/` does not exist yet
- `AGENTS.md` still teaches `zfa generate`, `--vpcs`, and old generator mental models
- many specs/quickstarts/tasks still teach `zfa generate`
- generated comments in project files still mention removed commands
- macOS-specific UI divergence is hand-split (`presentation/macos_views/*`) rather than mapped to v5 adaptive layouts

---

## Migration principles

1. **Do not big-bang rewrite the app.**
2. **Migrate the project contract before regenerating large slices.**
3. **Use one small pilot feature first.**
4. **Treat `zik_zak` as downstream validation, not as a speculative redesign.**
5. **Preserve hand-authored UI and platform-specific implementation details until the v5 adaptive path is proven.**

---

## Phase 0 — baseline and freeze

### Tasks
- create migration branch: `v5/zik-zak-migration`
- record baseline:
  - `flutter analyze`
  - `flutter test`
- capture current platform-specific UI behavior for key screens:
  - macOS
  - mobile
- inventory legacy references:
  - `zfa generate`
  - `--vpcs`
  - `zuraffa_generate`
  - old generated headers

### Output
- migration baseline report
- list of high-risk feature areas

---

## Phase 1 — migrate project contract first

### 1. Rewrite `AGENTS.md`
Replace legacy generator guidance with the v5 contract:
- `zfa entity create`
- `zfa make`
- `zfa build`
- fixed domain root: `lib/src/domain`
- Zorphy-only entities
- `.zfa/` memory model
- generated architecture vs manual UI boundary

### 2. Rewrite `.zfa.json`
Convert from the legacy flat shape to the v5 shape.

### Recommended target

```json
{
  "plugins": {
    "defaults": {
      "di": true,
      "test": true,
      "method_append": true,
      "route": false,
      "mock": false,
      "gql": false,
      "cache": false
    },
    "disabled": [
      "graphql"
    ]
  },
  "planning": {
    "presets": {},
    "aliases": {}
  },
  "ui": {
    "adaptiveLayouts": true,
    "platformShells": true,
    "layoutTargets": ["mobile", "tablet", "desktop", "macos"],
    "adaptivePreset": "adaptive-feature"
  },
  "entity": {
    "entityFirst": true,
    "jsonByDefault": true,
    "compareByDefault": true,
    "filterByDefault": true
  },
  "buildByDefault": false,
  "formatByDefault": false
}
```

### 3. Seed `.zfa/`
Run at least one representative `zfa make` flow so `zik_zak` gains:
- `.zfa/plans/`
- `.zfa/runs/`
- `.zfa/context.json`
- optional first `decisions/` and `blueprints/`

### Output
- `zik_zak` has a v5 project contract before source migration begins

---

## Phase 2 — migrate planning/spec artifacts

### Target files
- `specs/*/quickstart.md`
- `specs/*/tasks.md`
- `specs/*/plan.md`
- `specs/*/research.md`
- `specs/*/data-model.md`

### Tasks
- replace `zfa generate` with `zfa make`
- replace old flags like `--vpcs` with v5 patterns
- rewrite assumptions around output/domain overrides to the fixed v5 contract
- update any constitution/agent guidance that still requires old commands

### Output
- future humans and agents stop learning the wrong workflow from project-local planning docs

---

## Phase 3 — pilot feature migration

Start with one contained feature before touching large domains.

### Recommended pilot candidates
- `feedback`
- `locale`
- `customer`

### Why these are good pilots
- smaller blast radius than `listing`, `chat_session`, or grocery flows
- enough structure to validate generator parity
- visible enough to prove migration success

### Tasks
- choose one pilot feature
- regenerate the feature with `zfa make`
- compare current files vs regenerated output
- keep hand-authored implementation details where needed
- verify usecases, repositories, datasources, DI, presenters, controllers, state, and tests

### Output
- one real feature slice proven under the v5 pipeline

---

## Phase 4 — adaptive layout pilot

### Current issue
`zik_zak` currently has manual platform divergence via:
- `presentation/macos_views/*`
- separate page views without generated `layouts/`

### Goal
Move one small slice to the v5 adaptive layout model:
- shared presenter/controller/state
- `pages/<feature>/layouts/`
- `AdaptiveViewState`
- `AppShellResolver`
- platform/device fallback logic

### Recommended screens
- `profile`
- `feedback`
- `login`

### Output
- proof that the v5 platform/layout story works in a real downstream app

---

## Phase 5 — clean generated headers and stale guidance

### Tasks
- update generated comments that still say `zfa generate`
- remove stale planning references after regeneration
- ensure project docs and source comments no longer advertise removed commands

### Output
- source tree and guidance match the actual toolchain in use

---

## Phase 6 — formalize `.zfa/` project memory

### Recommended artifacts
- `.zfa/blueprints/zik_zak_app.md`
- `.zfa/decisions/manual-ui-zones.md`
- `.zfa/decisions/platform-shell-strategy.md`
- `.zfa/decisions/provider-vs-datasource-boundaries.md`
- `.zfa/decisions/legacy-slices-still-manual.md`

### Output
- future agents can enter the project without rediscovering architectural intent manually

---

## Phase 7 — broader rollout

After the pilot proves stable:
- migrate additional feature docs/specs
- regenerate more slices under v5
- plan second-wave migrations for complex domains:
  - `listing`
  - `chat_session`
  - `grocery_*`
  - `barcode_*`

---

## Suggested execution order

1. baseline branch + inventory
2. `AGENTS.md` rewrite
3. `.zfa.json` rewrite
4. seed `.zfa/`
5. planning/spec artifact rewrite
6. pilot feature regeneration
7. adaptive-layout pilot
8. header/comment cleanup
9. broader rollout

---

## Success criteria

`zik_zak` migration is considered successful when:
- it teaches the v5 pipeline in project guidance
- it uses v5 `.zfa.json` shape
- it has a seeded `.zfa/` memory surface
- at least one feature slice is regenerated successfully with `zfa make`
- at least one platform-divergent screen is validated against the adaptive layout model
- the app no longer teaches removed generator commands to humans or agents
