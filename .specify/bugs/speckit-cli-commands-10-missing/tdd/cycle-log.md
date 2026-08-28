# Cycle Log: speckit-cli-commands-10-missing

Append-only evidence for the TDD loop. One entry per cycle.

## Baseline

- commit: 49e049c4
- suite_baseline: unknown (repo not run in full; scoped parity test added)
- parity test did not exist yet.

## Cycle 1 — write failing parity test (RED)

- Test: `test/cli/standard/extension_command_parity_test.dart`
- Command: `dart test test/cli/standard/extension_command_parity_test.dart`
- Result: FAILED (1 of 2)
- Reason: 14 `zfa manifest` commands had no `provides:` alias in
  `.specify/extensions/zuraffa/extension.yml`:
  - api/create-api-bridge -> zfa.api.create-api-bridge
  - cache/adapter -> zfa.cache.adapter
  - gql/generate -> zfa.gql.generate
  - graphql/create -> zfa.graphql
  - gym/create -> zfa.gym
  - mcp/scaffold -> zfa.mcp.scaffold
  - mock/json -> zfa.mock.json
  - module/create_module -> zfa.module.create_module
  - route/deep-link -> zfa.route.deep-link
  - route/shell -> zfa.route.shell
  - sqlite/create -> zfa.sqlite
  - strategy/create -> zfa.strategy
  - sync/enable -> zfa.sync.enable
  - tui/create-tui-screens -> zfa.tui.create-tui-screens
- Mapping exceptions encoded in the test (irregular by design):
  method_append -> method/method-append, feature/scaffold -> zfa.scaffold,
  private-method -> .private.

## Cycle 2 — generate the 14 missing command docs + register (GREEN)

- Change: generated 14 `commands/*.md` files from `zfa manifest` inputSchema
  (flags table derived per command) and appended 14 `provides:` entries to
  `extension.yml` (aliases `zfa.<plugin>[.<name>]`).
- New categories introduced: integration/, graphql/, tooling/.
- Command: `dart test test/cli/standard/extension_command_parity_test.dart`
- Result: All tests passed (2/2). parity -> 0 missing; shape -> all docs valid.

## Refactor

- No refactor needed; the generated docs are additive and consistent with the
  existing template. The parity test encodes the irregular alias mapping so future
  gaps surface as RED instead of drifting silently.
