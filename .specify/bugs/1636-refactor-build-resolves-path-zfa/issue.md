# Bug Issue: refactor build pass resolves the PATH-installed zfa instead of the driving binary

- **Slug**: 1636-refactor-build-resolves-path-zfa
- **Fetched**: 2026-09-15T14:06:00+00:00
- **Issue**: 1636
- **URL**: https://github.com/arrrrny/zuraffa/issues/1636
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: (none)

## Body

## Evidence (production, calculator corpus, post-#1629 master)

`scripts/zfa tdd refactor A1 --feature calculator --project ~/Developer/calculator` (driving CLI = the freshly compiled `.dart_tool/zfa_cli_bin/zfa_exe`, master @ 8480a53e):

```
zfa tdd refactor: applying passes
   pass: build
     command: /Users/arrrrny/.local/bin/zfa build     ← the PATH install, not the driving binary
```

The driving binary was compiled from today's master; the PATH install may predate it (same `6.3.0` version string, older code — the #1472 version pin cannot fire on an equal version).

## Root cause

`StepRunner.resolveEntrypoint` tiers: 1-3 (source) → **4. PATH `zfa`** → 5/6 (`Platform.script` / `Platform.resolvedExecutable`). When the driving process IS a compiled binary that is not on PATH (e.g. the compile-cache artifact, or an install dir earlier/later on PATH), tier 4 short-circuits and every resolved child — including `zfaBuildCommand`'s build pass (`refactor_passes.dart`, the #717 chain) — executes the PATH binary. The #1472 pin probes versions and cannot distinguish same-version/different-code installs.

## Why it matters

The no-JIT directive is "the driving built binary always". The build pass — the heaviest child a refactor spawns — is exactly the one that can silently run different code than the CLI driving the run.

## Fix direction

When `Platform.resolvedExecutable` is a compiled (non-VM) executable, prefer **the running binary** (tier 6) over the PATH tier (4) — the running binary is definitionally what the operator invoked. Needs care against the #690/#864/#1371/#1472 history (each tier exists for a repro); add tier tests for the cache-exe driver shape.

## Comments

None.
