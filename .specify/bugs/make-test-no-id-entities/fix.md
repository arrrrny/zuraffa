# Bug Fix: zfa make --test still fails for no-id entities

- **Slug**: make-test-no-id-entities
- **Issue**: https://github.com/arrrrny/zuraffa/issues/514
- **Branch**: `fix/make-test-no-id-entities`
- **Verdict**: fixed

## Root cause

Issue #510 moved the #307 loud no-id failure so it only fires when an
**id-dependent** plugin is active. But `zfa make <NoId> --test` still failed
because `usecase` was being pulled into the active set by a **config default**
(`usecase` is `true` under `plugins.defaults` in `apps/zikzak_demo/.zfa.json`),
not by an explicit user request.

`--test` itself only adds the id-neutral `test` plugin (see
`PlanResolver._selectionFromOptions` in `lib/src/core/planning/plan_resolver.dart:183`).
So `zfa make AuthRequest --test` resolves to `{usecase, test}` only when
`usecase` is enabled by default — and the implied `usecase` trips the gate even
though the user only wanted id-neutral test regeneration.

## Approach

In the no-id branch of `MakeCommand.run()` (`lib/src/commands/make_command.dart`,
the `else` at the old line 478), distinguish **explicitly requested** id-dependent
plugins from **implied** ones (config defaults / presets). When the user's intent
is id-neutral (`--test` / `--mock`) and they did **not** explicitly request any
id-dependent plugin (no `--methods` / `--usecase` / `--service` / `--with` /
positional), drop the implied id-dependent plugins so the id-neutral
regeneration proceeds — mirroring the existing value-object drop above it.

Explicit detection (`_explicitIdDependentPluginIds`):
- positional plugin args and `--with` entries that are id-dependent;
- plugin flags the user actually passed (`wasParsed`, since the argParser
  defaults every plugin flag to `true`);
- `--methods` implies `usecase` (`PlanResolver._hasEntityMethods`);
- `--service` implies `usecase` + `service` + `provider`.

A genuinely explicit id-dependent plugin keeps the loud failure armed, so
`zfa make AuthRequest --test --methods=get` and bare `zfa make AuthRequest`
still fail loudly (correct #307/#508 behavior).

Also cleaned up the dangling comment on the `test` entry of
`_valueObjectRootPlugins`.

## Files changed

- `lib/src/commands/make_command.dart`
  - Reworked the no-id loud-failure block to drop implied id-dependent plugins
    for id-neutral intent.
  - Added `_explicitIdDependentPluginIds` and `_splitListOption` helpers.
  - Fixed the `test` value-object comment (line 42).
- `test/commands/make_command_test.dart`
  - Added two #514 regression tests (id-neutral success + bare-make still fails).

## Test evidence

`dart test test/commands/make_command_test.dart` → **All tests passed (17)**,
including:
- `#508 — --test only on an id-less entity succeeds` (unchanged green)
- `#508/#307 — a mixed request (--test plus --methods) still fails loudly` (green)
- `#514 — no-id entity with usecase default-enabled: --test regenerates
  id-neutrally` (new: 3 usecase test files regenerated, query key =
  `ChatMessageFields.content`, pre-existing usecase stub untouched)
- `#514 — bare make (no --test/--mock) still fails loudly` (new)

## Risks

- Narrow: only affects no-id entities where an id-dependent plugin is active
  purely via config default and the user passes `--test`/`--mock` with no
  explicit id-dependent request. Existing loud-failure and value-object paths
  are unchanged.
- The drop notice informs the user which plugins were dropped.
