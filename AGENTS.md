# AI Agents Guide for Zuraffa

This file defines the current v5 contract for AI agents working in Zuraffa projects.

## Generation contract: use the canonical v5 workflow

When you need to create or evolve architecture code, use this sequence:

1. `zfa entity create`
2. `zfa make`
3. `zfa cache adapter <EntityName>` (if entity needs cache/local storage)
4. `zfa build`

### Canonical example

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double

zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test

zfa cache adapter Product   # optional: register Hive adapters if caching needed

zfa build
```

## Hard rules

- **Do not use the removed legacy one-shot generator.**
- **Prefer `zfa make` over `zfa feature`.** `zfa feature scaffold` is only a wrapper over the feature preset.
- **Do not hand-create entities.** Use `zfa entity create`.
- **Do not call `build_runner` directly in normal agent flows.** Use `zfa build`.
- **Do not invent alternate folder structures.** Zuraffa v5 assumes a fixed domain root.

## STOP-ON-ROADBLOCK RULE (HARD, NON-NEGOTIABLE — HARDCODED)

**The FIRST time a `zfa` command errors, OR succeeds but produces output other than
expected (non-compiling generated code, missing files the generated code references,
missing symbols the generated code uses, silent 0-output builds, crashes), the agent
MUST STOP IMMEDIATELY. This overrides any "keep going" instinct.**

- **Your first instinct to STOP is the correct one. Trust it.** When something is off,
  stop and report. Do not rationalize it away, do not "just try one more command," do
  not assume it is a stale cache / wrong flag / your own mistake. Report it as a zuraffa
  gap first; the maintainer decides if it is real.
- **Never continue** the generation/build task after a roadblock. Do NOT work around it
  with different flags, `--force` re-runs, explicit `--methods`, re-making only the
  "id-having" entities, hand-written patches, or "trying the next entity." **Bounded or
  partial progress is STILL a violation** — if a gap blocks one entity, it blocks the
  whole workflow. The smoke-test goal is to build a seamless app *only* via zfa commands
  so we can **find and fix zuraffa gaps**, not to produce a working mock by skirting them.
- **Never hand-write code** to route around a zfa misfire. Every Dart file in
  `apps/zikzak_demo` must come from a `zfa` command; if `zfa` cannot produce it, that
  *is* the bug to report.
- **Document** in the tracking file (`apps/zikzak_demo/PROGRESS.md`) exactly:
  1. the command that was run,
  2. what was expected,
  3. what was actually output,
  4. the root cause (trace it in zuraffa source if possible).
- **File a GitHub issue** on `arrrrny/zuraffa` with that same detail (repro, expected,
  actual, root cause, suggested fix).
- **End the goal / stop the run.** Wait for the issue to be **MERGED** (not just opened
  or PR'd) before resuming. Resume ONLY when a new goal is invoked that references
  `apps/zikzak_demo/PROGRESS.md` — the resume marker records the exact stopping step so
  the next run picks up from there.

This rule takes precedence over any desire to keep making incremental progress. A
single un-fixed zfa gap invalidates the entire "zfa-only" contract, so one roadblock
stops the whole workflow until zuraffa itself is repaired.

## Fixed layout assumptions

Zuraffa v5 public docs assume:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example:

```text
lib/src/domain/entities/product/product.dart
```

Also assume:

- fixed domain root: `lib/src/domain`
- entities are Zorphy-first on public v5 surfaces
- output examples should target `lib/src`, not custom architecture roots

## Spec Kit: Branch Naming

When running `/speckit-specify`, the git branch name MUST match the feature directory name exactly.
This is non-negotiable: `specs/010-offline-first-sync` → branch `010-offline-first-sync`.

The `before_specify` git hook is responsible for creating this branch. If it does not run
(e.g., when an AI agent drives the workflow directly), the agent MUST manually create the
branch with `git checkout -b <feature-directory-name>` before proceeding.

## What `make` should be used for

Use `zfa make` for:

- CRUD architecture around an entity
- adding or regenerating repository/data layers
- adding VPC layers via `--with=vpc` and `--state`
- enabling DI, tests, cache, mock, route, gql, or graphql support
- custom use cases and orchestrators

Examples:

```bash
# Basic CRUD stack
zfa make Product --preset=crud --methods=get,getList,create,update,delete

# Add presentation and tests
zfa make Product --preset=crud --with=vpc --state --test --methods=get,getList

# Add cache + DI + mocks
zfa make Product --preset=crud --cache --di --mock --use-mock --methods=get,getList

# Custom use case
zfa make SearchProducts usecase --domain=search --params=SearchQuery --returns=List<Product>
```

## `feature` is still available, but not primary

If a user explicitly asks for `zfa feature`, treat it as wrapper syntax over the normalized feature preset.

Equivalent examples:

```bash
zfa make Product --preset=feature --plan
```

```bash
zfa feature scaffold Product --plan
```

In tutorials, prompts, and examples, prefer `zfa make`.

## Generated architecture vs manual UI

Use `zfa` for generated architecture ownership:

- entities
- repositories
- datasources
- usecases
- presenters/controllers/state
- DI/test/mock/cache/route/graphql support

Handcraft only the parts that are intentionally manual, such as:

- view composition details
- page-specific widget layout adjustments
- styling and presentation refinements
- feature-specific business implementation inside generated extension points

## `.zfa.json` and `.zfa/` memory for agents

Agents should treat these as the project memory surfaces:

- **`.zfa.json`**: project defaults, plugin defaults, entity-first settings
- **`.zfa/`**: canonical v5 memory for plans, runs, decisions, blueprints, manifests, and context

Canonical memory layout:

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

During the migration period, some internals may still use older storage paths. Use `.zfa/` as the public-facing docs contract and `.zfa.json` as the active config file.

## Search guidance

- Prefer semantic/code-aware search when available.
- Use exact grep only when you need literal string matches.
- When updating docs, verify examples match the current CLI help and tests.

## Validation guidance

After editing generation-related docs or workflows, prefer focused validation such as:

```bash
# fast unit checks (default run)
dart test test/core/artifact_publisher_test.dart
# slow regression tier (excluded by default — use the preset)
dart test --preset=regression test/regression/docs_command_consistency_test.dart
```

`dart test` runs the fast unit suite by default. Use `--preset=all` for the
full suite, or `--preset=regression` / `integration` / `property` / `benchmark`
for a single slow tier. See `test/README.md`. Use `dart analyze` on the files you touched.

## Migration shorthand for older projects

If you encounter older guidance, normalize it to:

- old entity setup → `zfa entity create`
- old generation step → `zfa make`
- old direct build-runner step → `zfa build`

For a user coming from older Zuraffa docs, the shortest correct explanation is:

> In v5, create the entity first, generate architecture with `zfa make`, and finish with `zfa build`. Treat `zfa feature` as a wrapper, not the primary workflow.


# Shared terminal (`herdr`)

Long-running or user-visible commands (e.g. `flutter run`, `zfa build`, `bun run watch:dev`) should run in the **`herdr` terminal workspace** so both the human and agents see the same terminal. The human attaches with `herdr`; agents drive it via the `herdr` CLI or the socket API: `herdr agent list`, `herdr agent prompt <id> <text>`, `herdr agent read <id>`, `herdr agent wait <id> --state blocked`, `herdr pane send-keys <pane> <key...>`. See `~/Developer/herdr` + `herdr --help`.

<!-- SPECKIT START -->

For additional context about technologies to be used, project structure,
shell commands, and other important information, read specs/016-fix-make-test-no-id/plan.md

## OpenWiki

This repository has documentation located in the /openwiki directory.

Start here:
- [OpenWiki quickstart](openwiki/quickstart.md)

OpenWiki includes repository overview, architecture notes, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

When working in this repository, read the OpenWiki quickstart first, then follow its links to the relevant architecture, workflow, domain, operation, and testing notes.

<!-- SPECKIT END -->
