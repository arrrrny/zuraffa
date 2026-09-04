# Bug Assessment: Fleet exit-code + receipt honesty sweep

- **Slug**: lying-success-sweep-995
- **Created**: 2026-09-04
- **Source**: https://github.com/arrrrny/zuraffa/issues/995
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

~15 plugins exit 0 on error, crash on bare invocation (RangeError), or print success before verification. The fleet report lists specific plugins: view, controller, datasource, shadcn, xray deck, gym, gql, graphql, feature, presenter, api, module, observer, cache, sync.

## Symptom

Bare `zfa cache` crashes with RangeError; bare `zfa sync` crashes with RangeError; many plugins exit 0 even when generation fails; some print "Generated successfully!" before verifying the output.

## Reproduction

1. `zfa cache` (no subcommand) → RangeError crash
2. `zfa sync` (no subcommand) → RangeError crash
3. Run any affected plugin with bad args → exit 0
4. Run `zfa view Foo` without entity → prints success, exit 0

## Suspected Code Paths

See issue body for exact line references per plugin.

## Root Cause Hypothesis

Most plugins were scaffolded without the `reportSubcommandUsage()` guard or explicit `exitCode` assignment. The fixed plugins (state, di, repository, provider, service, sqlite, test) show the correct pattern.

## Proposed Remediation

Port `reportSubcommandUsage()` + exit 64 on bare invocation; set `exitCode = 1` on generation failure; gate success messages on verification. Add property test walking all commands.

## Risks & Considerations

- Large surface area — 15+ files to touch
- Each plugin's run() has unique arg parsing
- Property test needs access to all registered commands

## Open Questions

None — issue is well-scoped with exact file/line references.
