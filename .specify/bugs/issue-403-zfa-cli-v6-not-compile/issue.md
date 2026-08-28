# Bug Issue: DROP: zfa CLI does not compile on v6 WIP (app_shell + AppCommand undefined)

- **Slug**: issue-403-zfa-cli-v6-not-compile
- **Fetched**: 2026-08-23T11:49:39.475676+00:00
- **Issue**: 403
- **URL**: https://github.com/arrrrny/zuraffa/issues/403
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: none

## Body

# DROP CARD - 2026-08-21

- Agent: miki (straddle build agent, Daytona sandbox)
- Date: 2026-08-21
- Repo: arrrrny/zuraffa (v6 WIP, box checkout feat/397-package-gym)

## I did
Tried to run zfa (Zuraffa code generator) in the Daytona sandbox to start building straddle via zfa entity create / zfa make / zfa build.

## I expected
zfa --help to print the command list and scaffold entities, use cases, value objects, providers, repositories for straddle.

## What happened
zuraffa v6 in this box does NOT compile. dart run bin/zfa.dart fails:

1. lib/src/commands/app_shell_command.dart:237 - buildXRayDecksBarrel not defined on AppShellBuilder.
2. lib/src/plugins/app_shell/builders/app_shell_builder.dart - getter xray undefined; leading declared twice.
3. lib/src/cli/cli_runner.dart:91 - AppCommand added to runner but class AppCommand does not exist anywhere.

Same break exists in pub-cache commit 42a3b4e (the ref other projects depend on). Not a branch fluke - v6-in-progress CLI rot.

## So I dropped
Sandbox-only build fork at /workspace/zuraffa-run (copy of pub-cache 42a3b4e). Commented out two broken refs in cli_runner.dart:
- import of app_shell_command.dart
- _runner.addCommand(AppCommand());

After that zfa --help runs with full command set. WORKAROUND, not a fix. User feat/397-package-gym untouched.

## Why it matters (gym material)
Exactly the misfire the architect wants as zuraffa gym equipment: diagnose a CLI referencing undefined command classes / half-merged features, then complete the feature or cleanly remove dead wiring. Filed as GitHub issue on arrrrny/zuraffa.

## Blocker status
Not blocked. Straddle build continues on /workspace/zuraffa-run fork.

## Comments

None.
