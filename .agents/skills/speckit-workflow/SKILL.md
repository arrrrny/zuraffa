---
name: "speckit-workflow"
description: "Run the full SDD lifecycle in Zed: specify → plan → tasks → implement (fully autonomous, no gates)"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "Zed"
  source: "workflow"
---

# Speckit Workflow (Zed) — Autonomous Mode

Run the full Specification-Driven Development lifecycle within Zed **without any user interaction**. This skill orchestrates the sequential execution of:

1. **Pre-Flight** — System context & project health
2. `/speckit-specify` — Create/update the feature specification
3. `/speckit-plan` — Generate the implementation plan
4. `/speckit-tasks` — Generate actionable tasks
5. `/speckit-implement` — Execute the implementation

**No review gates. No questions. No stops.** If information is missing, search the project codebase for the answer. If truly blocked, make a reasonable default decision and continue.

## User Input

```text
$ARGUMENTS
```

Parse the user input for the following:

**Required:**

- **Feature description** — A natural language description of what to build.

**Optional (extracted from input if present):**

- **scope** — One of `full`, `cli-only`, `generator-only`, `plugins-only`, `docs-only`. Defaults to `full`.
- **branch** — An explicit branch name to use (e.g., `--branch my-feature`). If not provided, the speckit-git-feature hook auto-generates one.

If no feature description is provided, **stop immediately** — do not ask the user to clarify. The workflow cannot proceed without a description.

## Core Rule: Never Ask, Always Search

When you encounter any ambiguity or missing information during any step:

1. **Search the project**: Use `grep`, `find_path`, or `claude_context_search_code` to find existing patterns in the codebase.
2. **Read the docs**: Check `docs/` for architecture documentation — these contain high-level system understanding.
3. **Check existing specs**: Look at `specs/` directory for similar features to understand conventions.
4. **Check existing implementations**: Look at the actual code in `lib/src/` for established patterns.
5. **Scan `AGENTS.md`**: Contains project-specific rules and conventions for v5.
6. **Use prior features**: Check `specs/` for closely related features — their specs, plans, and tasks.md files document existing patterns.
8. **Check `.zfa/` memory**: The `.zfa/` directory contains project memory — plans, runs, decisions, blueprints, manifests, and context.

Only if absolutely no information exists in the entire codebase should you make a reasonable default decision and document it. Never formulate a question to the user.

## Core Rule: Zuraffa v5 Generation Contract

When the feature involves creating or evolving generated architecture code (entities, usecases, repositories, datasources, etc.), follow the canonical v5 workflow:

```bash
zfa entity create -n EntityName --field ...
zfa make EntityName --preset=crud --methods=get,getList,create,update,delete --with=vpc --state --di --test
zfa cache adapter EntityName   # optional: register Hive adapters if caching needed
zfa build
```

**Hard rules:**
- **Do not use the removed legacy one-shot generator.**
- **Prefer `zfa make` over `zfa feature`.** `zfa feature scaffold` is only a wrapper over the feature preset.
- **Do not hand-create entities.** Use `zfa entity create`.
- **Do not call `build_runner` directly.** Use `zfa build`.
- **Do not invent alternate folder structures.** Zuraffa v5 assumes fixed domain root `lib/src/domain`.
- **Do not modify generated files by hand** — they are owned by `zfa`. Modify the source templates/generators instead.

## Core Rule: Context Awareness — Framework vs Generated Output

When implementing features **in the Zuraffa framework itself** (as opposed to building an app WITH Zuraffa):

- **Framework code**: Lives in `lib/src/` — CLI commands, generators, plugins, core types, models, config.
- **Generated output**: What `zfa make` produces for end-users — entities, usecases, repositories, datasources, controllers, views, DI registrations, tests.
- **Plugins**: 21 concrete generator plugins in `lib/src/plugins/` — each generates a specific layer (entity, usecase, repository, datasource, controller, etc.).

When modifying the framework:
1. **Modify the generator/plugin** if the change is about what code gets generated.
2. **Modify the core types/model** if the change is about how generation is configured or planned.
3. **Modify the CLI command** if the change is about user-facing command syntax or behavior.
4. **Add/update tests** in `test/` that correspond to the modified layer.
5. **Run `zfa build`** to regenerate any framework-internal generated code.
6. **Run `dart analyze`** to check for compilation errors.
7. **Run focused tests** (`flutter test test/path/to/test.dart`) targeting the changed area.

When the feature affects how generated output looks for end-users, check existing specs (`specs/`) and the plugin tests in `test/plugins/` to understand the expected output format.

## Workflow Execution

### Pre-Flight: System Context & Project Health

**Required before any step runs.** These checks ensure you understand the architecture and the project is in a healthy state.

#### 1. Triage — Task Classification & Depth Assessment

**First action in every workflow.** Classify the task and assess its
complexity to determine how much context gathering is needed.

1. **Classify the task** using the `triage` skill criteria:
   - **Bug Fix**: Something is broken
   - **New Feature**: Building something new
   - **Change to Existing Feature**: Modifying existing behavior
2. **Assess complexity** (Simple vs Complex vs Ambiguous) using the factors
   in the triage skill (scope, patterns, cross-cutting concerns, clarity, risk).
3. **Determine depth**:
   - **Simple/Straightforward** → Skip deep docs reading. Proceed with light Pre-Flight and move to the speckit steps quickly.
   - **Complex** or **Ambiguous** → Full deep-dive: check AGENTS.md, read relevant `docs/` files, check existing specs for prior art before proceeding.

Output the result so downstream steps can adjust:

> **Triage Result**: {Bug Fix | New Feature | Change to Existing Feature}
> **Complexity**: {Simple | Complex | Ambiguous}

#### 2. Context Gathering — Docs, Specs & Prior Art

**Depth depends on triage result.**

- **If Simple/Straightforward** (regardless of classification):
  - Light docs skim is sufficient — read just enough to understand the area.
  - Proceed quickly to implementation.

- **If Complex or Ambiguous**:
  - **Read `AGENTS.md`** for v5 contract, hard rules, and conventions.
  - **Read `CLI_GUIDE.md`** for the complete CLI reference.
  - **Check existing specs** in `specs/` for similar features — their design decisions, gotchas, and patterns inform your approach.
  - **Read `CACHING.md`** if the feature touches caching or offline sync.
  - **Read `docs/v4_vs_v5_comparison.md`** if the feature involves migration.
  - **Read `doc/PLUGIN_API_REFERENCE.md`** if the feature involves plugin development.
  - **Read `doc/MCP_SERVER.md`** if the feature touches the MCP server.

#### 3. Project Health Baseline

Establish a health baseline before any changes are made.

1. **Check `dart analyze`** for pre-existing errors:
   ```bash
   cd /Users/ahmettok/Developer/zuraffa && dart analyze
   ```
2. **If pre-existing errors exist**, note them in a baseline log so downstream
   steps can distinguish pre-existing issues from introduced ones.

   ```markdown
   **Health Baseline**: `dart analyze` shows {N} errors and {M} warnings.
   {X} errors are pre-existing (not caused by this workflow).
   ```

3. **If no errors**, log confirmation and proceed:

   ```markdown
   **Health Baseline**: ✅ No pre-existing analysis errors — proceeding.
   ```

4. **Check `zfa build` viability** (quick check, not a full run):
   ```bash
   cd /Users/ahmettok/Developer/zuraffa && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -20
   ```
   Note: Only run this if the feature will involve code generation. Otherwise skip.

**If the project has pre-existing failures that block the workflow** (e.g., `dart analyze` has errors that make it impossible to validate changes), note them and proceed anyway — partial implementation is better than none.

#### 4. Module/Plugin Affected Assessment

Before implementation begins, determine which parts of the framework the feature touches:

1. **CLI commands** — Is a new CLI command needed, or an existing one modified? Check `lib/src/commands/`.
2. **Generator plugins** — Is a new plugin needed, or an existing one modified? Check `lib/src/plugins/`.
3. **Core types** — Are `lib/src/core/` types affected (Result, Failure, hooks, plan resolution)?
4. **Generator pipeline** — Is the generation pipeline itself affected? Check `lib/src/generator/`.
5. **Configuration model** — Is `.zfa.json` config or the model layer affected? Check `lib/src/models/` and `lib/src/config/`.
6. **Domain layer base classes** — Are the UseCase base classes affected? Check `lib/src/domain/`.
7. **Presentation layer** — Are the Controller/View/Presenter shells affected? Check `lib/src/presentation/`.
8. **Tests** — Are tests in `test/` affected?

Document the affected modules so implementation steps can be scoped correctly:

> **Affected Modules**: {list of modules}
> **Scope**: {scope}

```markdown
Starting step 1 of 5: Pre-Flight — System context & project health...
```

### Step 1: Specify

Call `/speckit-specify` with the feature description as arguments.

```markdown
Starting step 2 of 5: /speckit-specify — Creating specification...
```

Wait for `/speckit-specify` to complete before proceeding.

**Check project health**: After the step completes, run `dart analyze` (quick check on affected files only).

- If **no new errors** beyond the baseline, proceed to the next step.
- If **new errors** are introduced, note them but do NOT stop — continue to the next step. The errors may be resolved by subsequent steps (e.g., generated code from `zfa build`).

**Note**: The speckit-specify process includes pre/post hooks (git branching, agent-context update, etc.). Let those hooks run. If a hook presents an optional prompt, skip it silently — this is an autonomous run.

When the spec is done, do NOT present it for review. Do not ask for approval. Immediately proceed to Step 2.

### Step 2: Plan

Call `/speckit-plan` with the feature description as arguments.

```markdown
Starting step 3 of 5: /speckit-plan — Generating implementation plan...
```

Wait for `/speckit-plan` to complete before proceeding.

**Check project health**: After the step completes, run `dart analyze` (quick check).

- If **no new errors** beyond the baseline, proceed to the next step.
- If **new errors** are introduced, note them but continue.

**Note**: The `plan` command reads the spec and generates design artifacts. If it encounters options or choices, make the safe/default choice. Look at how existing plans in `specs/` are structured if uncertain.

When the plan is done, do NOT present it for review. Immediately proceed to Step 3.

### Step 3: Tasks

Call `/speckit-tasks` with the feature description as arguments.

```markdown
Starting step 4 of 5: /speckit-tasks — Generating task breakdown...
```

Wait for `/speckit-tasks` to complete before proceeding.

### Step 4: Implement

Call `/speckit-implement` with the feature description as arguments.

```markdown
Starting step 5 of 5: /speckit-implement — Executing implementation...
```

Wait for `/speckit-implement` to complete.

The implement step reads tasks.md and executes them one by one. If any task has ambiguity:

- Search the project for the relevant pattern
- Check existing implementations for convention
- Make a reasonable decision and continue

## Scope Handling

If the user specified a scope other than `full`, pass it as context when invoking each step:

- **`cli-only`**: Only CLI command changes are in scope — skip generator plugin, core type, and presentation changes.
- **`generator-only`**: Only generator pipeline changes are in scope — skip CLI, config, and presentation changes.
- **`plugins-only`**: Only generator plugin changes are in scope — skip CLI, pipeline, and core type changes.
- **`docs-only`**: Only documentation changes are in scope — skip code changes entirely.

Include the scope constraint in a note at the start of each `/speckit-*` invocation:

> **Scope**: {scope} — Adjust implementation accordingly.

## Completion Report

When all steps complete successfully, report to the user:

```markdown
## Workflow Complete

The full SDD lifecycle finished successfully:

| Step       | Status |
| ---------- | ------ |
| Pre-Flight | ✅     |
| Specify    | ✅     |
| Plan       | ✅     |
| Tasks      | ✅     |
| Implement  | ✅     |

The feature has been fully implemented. See the spec, plan, and tasks for details.
```

## Error Handling

- The Pre-Flight health baseline is informational only — do NOT abort if there are pre-existing issues. Proceed regardless.
- If any step fails, **retry once**. If it fails again, **continue to the next step** — partial implementation is better than none.
- If a step produces warnings but doesn't error, **continue normally**.
- If a step times out, **retry once with a longer timeout**. If it times out again, **continue to the next step**.
- Never ask the user how to handle an error. Make the call: retry or skip, then keep going.
- After all steps are done (even if some failed), report what succeeded and what didn't.

## Post-Implementation

After `/speckit-implement` completes:

1. **Run `zfa build`** to regenerate any generated code if the feature modified generators, plugins, or entities:
   ```bash
   cd /Users/ahmettok/Developer/zuraffa && zfa build
   ```
   If `zfa build` fails, check if the failure is due to the changes or pre-existing conditions. Try running `dart run build_runner build --delete-conflicting-outputs` as fallback.

2. **Run `dart analyze`** to check for compilation errors introduced by the implementation:
   ```bash
   cd /Users/ahmettok/Developer/zuraffa && dart analyze
   ```
   Compare against the baseline from Pre-Flight. Report only **new** errors introduced by this workflow.

3. **Run focused tests** — target the specific area of changes:
   ```bash
   # If the feature touches regression-critical paths
   flutter test test/regression/docs_command_consistency_test.dart
   flutter test test/core/artifact_publisher_test.dart

   # If the feature touches a specific plugin
   flutter test test/plugins/{plugin_name}_test.dart

   # General test run (if time allows, use targeted tests first)
   flutter test test/path/to/relevant/test.dart
   ```

4. **If diagnostics exist**: Make 1-2 focused attempts to fix them. If you can't resolve quickly, leave them and report.

5. **Run `/insights`**: Extract non-obvious key findings from the session and persist them to `INSIGHTS.md`. This captures gotchas, workarounds, and architecture decisions discovered through trial and error.

6. **Run `/docs`**: Generate or update project documentation in `docs/` based on the implementation. Creates architecture diagrams, workflow docs, and component references.

7. **Report results**: Tell the user what was implemented, what was tested, any known issues, and what was captured in insights/docs.

**Note**: `/insights` and `/docs` run autonomously — they only write if there's meaningful content to capture. If the session didn't discover any non-obvious insights or architectural changes worth documenting, they'll report back with no changes.
