# Implementation Plan: 1692 — tdd make path consults the 016 id-gate

**Branch**: `fix/1692-tdd-make-idless-entity-gate`

## Root cause (confirmed by reading the source)

The #307/016 id-gate lives in ONE place: the entity-resolution step of the main
`zfa make` command (`lib/src/commands/make_command.dart`, the
`EntityFieldResolver.resolveIdField` block that throws `MakeCommandException` for
an id-less entity when id-dependent plugins are active).

The tdd loop's unit make does NOT drive that surface for the CRUD stack. The
`GenerationPlanner` unit-entity pipeline (`lib/src/plugins/tdd/services/generation_planner.dart`)
plans, for a unit behavior `U<n>` whose FR traces to a spec Key Entity:

1. `entity create -n <Entity> --build` (idempotent reuse — phase 0 created the
   entity with the spec's fields),
2. `mock create --name <Entity> --certify` — the id-keyed CRUD mock datasource
   (`UpdateParams<String, UserSessionPatch>`, `item.id == params.id`),
3. `tdd wire <id> --entity <Entity> --feature <f>`,
4. `build`.

Nothing on that path consults the entity's identity: the mock datasource builder
defaults `idField` to `'id'` when the entity has none, emits the id-assuming CRUD
surface, and the mock certification sandbox (the backstop) refuses to certify the
non-compiling output downstream — surfacing as
`make: behavior=U<n> outcome=generation-error` AFTER generation ran.

## Remediation

Add the 016 id-check to the tdd make path (`lib/src/plugins/tdd/commands/make_command.dart`),
between plan finalization and pipeline execution:

- Scan the effective plan for id-dependent steps targeting the traced entity:
  `mock create --name <Traced>` (the datasource/mock surface) and
  `make <Traced>` (the repository/usecase surface, without `--no-entity`).
- When such a step exists AND the traced entity resolves id-less through the SAME
  resolver main make uses (`EntityFieldResolver.resolveIdField`: not a value
  object, `hasId == false`), refuse BEFORE generation:
  - print the #307 diagnostic (message + the three remediation hints) plus the
    tdd-path remediation (narrow the traced contract to id-neutral methods),
  - `_printSummary` with outcome `unexpressible` (existing vocabulary: non-zero
    exit, no green entry, run loop defers then stops honestly),
  - `exitCode = 1; return;` — no pipeline step, no subject mutation, no cycle-log
    entry.
- Every other shape (id-bearing entity, value object, missing entity file, no
  traced entity, no id-dependent step) keeps today's behavior byte-for-byte.

Files touched: `lib/src/plugins/tdd/commands/make_command.dart` (gate + helper),
new regression tests under `test/plugins/tdd/`. The #307 gate itself, the 016
contract, and the mock certification backstop are NOT modified.

## Verification plan

1. Red (pre-fix): run the idless_probe repro end-to-end — confirm the id-assuming
   CRUD code is emitted and the make dies at mock certification with
   `outcome=generation-error`.
2. Unit tests (red → green): new `test/plugins/tdd/` file proving
   (a) id-less traced entity + id-dependent plan → refusal BEFORE any pipeline
   invocation (the fake zfa log stays empty), #307 text present, exit non-zero,
   no green entry; (b) id-bearing traced entity → pipeline invoked, green.
3. Green (post-fix): re-run the idless_probe repro → refusal BEFORE generation
   with the #307 remediation text.
4. No-regression: an id-bearing probe drives the same pipeline to green
   generation.
5. `dart analyze` changed files clean; `dart format .` no drift; targeted
   `dart test` for the touched surface.
