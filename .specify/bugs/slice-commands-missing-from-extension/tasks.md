# Tasks: slice-commands-missing-from-extension (bug 598)

## Phase 1: TDD remediation

From `tdd/verification.md` (verdict PASS_WITH_GAPS, finding 1). Bug 598's own
scope is complete; this task records the follow-up the audit surfaced.

- [ ] T1 Declare the remaining undeclared categories referenced by `provides:` entries in `.specify/extensions/zuraffa/extension.yml` — `integration` (speckit.zuraffa.api.create-api-bridge, speckit.zuraffa.mcp.scaffold), `graphql` (speckit.zuraffa.gql.generate, speckit.zuraffa.graphql), `tooling` (speckit.zuraffa.gym), `benchmark` (speckit.zuraffa.benchmark.list/register/run) — then widen the U1 guard to assert every referenced category is declared. Prove with: `dart test --preset=all test/cli/standard/extension_command_parity_test.dart -p vm` (all green, widened guard included).
