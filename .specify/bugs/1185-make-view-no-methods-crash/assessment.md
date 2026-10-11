# Assessment — issue #1185 (make view no-methods crash)

## Triage

**Confirmed, reproduced, root-caused.** Not a regression from a recent change —
the shape is a latent gap: `--with=vpc --view` without `--methods` is absent
from the AGENTS.md canonical examples, so no test covered it.

## Reproduction matrix (verified live on this branch's base)

| Invocation | Result | Why |
|---|---|---|
| `make Product --with=vpc --view --skin --no-entity` | ❌ `Bad state: No element`, exit 1 | presenter `_buildMethods` custom branch → `useCases.first` on an EMPTY list |
| `make Product --with=vpc --view --skin --methods=get --no-entity` | ✅ Done | methods non-empty → custom branch skipped |
| `make Product --with=vpc --view --skin` (entity present, no methods) | ✅ Done | plugin-level default `['get','update','toggle']` fires (context.data['methods'] is null → `??` default) |

## Root cause (exact)

Stack trace (from `--verbose` run):

```
#0      List.first (dart:core-patch/growable_array.dart:352:5)
#1      PresenterPlugin._buildMethods (presenter_plugin.dart:450:55)
#2      PresenterPlugin.generate (presenter_plugin.dart:160:27)
```

`GeneratorConfig`:

- `isEntityBased => methods.isNotEmpty && !noEntity`
- `isCustomUseCase => methods.isEmpty || noEntity`

With `--no-entity` and no `--methods`: `isCustomUseCase == true` and
`config.methods.isEmpty == true`, so `_buildMethods` enters the custom-method
branch and evaluates `useCases.first`. But `_buildUseCaseInfo` legitimately
returns an EMPTY list for that shape:

- entity-based infos: skipped (`!config.noEntity` guard);
- synthetic custom-usecase info: skipped (branch requires
  `isCustomUseCase && methods.isEmpty && !config.noEntity` — the
  `!config.noEntity` clause excludes exactly this shape).

The two branches disagree: `_buildUseCaseInfo` knows a no-entity run has no
usecase info, `_buildMethods` assumed one exists whenever
`isCustomUseCase && methods.isEmpty`. The controller's twin branch
(`controller_plugin_methods.dart:74`) does NOT crash — it builds from
`config.nameCamel`, never from the list — which is why only the presenter
crashed (and before it, the view plugin had already emitted fine).

## Fix design (both layers of the issue's "Expected")

1. **Guard the unguarded `first`** (the crash):
   `presenter_plugin.dart` custom branch now requires `useCases.isNotEmpty`.
   Skipping is correct, not a downgrade: with no usecase info there is no
   method to build, and the emitted bare presenter is byte-identical to the
   issue's own accepted success shape (`--methods=get --no-entity`, which
   also emits a method-less presenter because noEntity runs never produce
   entity-based usecase infos).

2. **Default the method set for view-bearing runs** (spec 1002 pattern):
   `MakeCommand` gains `_viewDefaultMethods = ['get', 'update', 'toggle']`
   — deliberately the SAME set the presenter/controller plugins already
   fall back to — injected after `resolvePlan` when the plan is
   view-bearing (`view`/`presenter`/`controller` in `plan.pluginIds`),
   `--methods` was never parsed, no `--from-json` config supplied methods,
   and the run is entity-backed (`--no-entity` not requested).

   Two deliberate safety properties:
   - **After plan resolution**: `PlanResolver._hasEntityMethods` implies the
     `usecase` plugin from a non-empty method set. Injecting before
     resolution would silently add plugins to existing invocations — a
     behavior change far beyond the bug. Injecting after keeps every plan
     byte-identical.
   - **Entity-backed only**: with `--no-entity` there is no entity surface
     to hang methods on; forcing a method set there changes nothing (noEntity
     runs never produce entity-based usecase infos) and would lie about what
     was generated. The bare-scaffold success (layer 1) is the honest result.

3. **Clear usage error on missing flag**: not needed as a separate path —
   after (1) + (2) the missing-flag case is either a sensible default
   (entity-backed) or a valid bare scaffold (`--no-entity`); the crash the
   error message would name can no longer occur.

## Blast radius / non-goals

- Controller branch untouched (never crashed).
- View plugin untouched (already handles empty methods gracefully).
- No plan changes for ANY invocation (default injected post-resolution).
- Engine preset behavior untouched (`_engineDefaultMethods` unchanged).
