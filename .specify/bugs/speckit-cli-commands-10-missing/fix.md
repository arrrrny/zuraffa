# Bug Fix: Speckit CLI Commands missing from extension manifest

- **Slug**: speckit-cli-commands-10-missing
- **Fixed**: 2026-08-28
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/verification.md (present only when the fix ran in TDD mode)

## Summary

The Speckit `zuraffa` extension advertised only 43 of the 54 commands exposed by
`zfa manifest`. Fourteen manifest commands had no `provides:` entry (and thus no
`commands/*.md`), so AI agents could not invoke them through the extension. The fix
generates the 14 missing command docs from the live manifest schema and registers
them in `extension.yml`. A parity test now guards this so the gap cannot reappear
silently.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `.specify/extensions/zuraffa/extension.yml` | modified | Appended 14 `provides:` command entries (aliases `zfa.<plugin>[.<name>]`). |
| `.specify/extensions/zuraffa/commands/integration/api_create-api-bridge.md` | added | `zfa api create-api-bridge` |
| `.specify/extensions/zuraffa/commands/utilities/cache_adapter.md` | added | `zfa cache adapter` |
| `.specify/extensions/zuraffa/commands/graphql/gql_generate.md` | added | `zfa gql generate` |
| `.specify/extensions/zuraffa/commands/graphql/create.md` | added | `zfa graphql create` |
| `.specify/extensions/zuraffa/commands/tooling/gym.md` | added | `zfa gym create` |
| `.specify/extensions/zuraffa/commands/integration/mcp_scaffold.md` | added | `zfa mcp scaffold` |
| `.specify/extensions/zuraffa/commands/testing/mock_json.md` | added | `zfa mock json` |
| `.specify/extensions/zuraffa/commands/scaffolding/module_create_module.md` | added | `zfa module create_module` |
| `.specify/extensions/zuraffa/commands/presentation/route_deep-link.md` | added | `zfa route deep-link` |
| `.specify/extensions/zuraffa/commands/presentation/route_shell.md` | added | `zfa route shell` |
| `.specify/extensions/zuraffa/commands/data/sqlite.md` | added | `zfa sqlite create` |
| `.specify/extensions/zuraffa/commands/domain/strategy.md` | added | `zfa strategy create` |
| `.specify/extensions/zuraffa/commands/utilities/sync_enable.md` | added | `zfa sync enable` |
| `.specify/extensions/zuraffa/commands/presentation/tui_create-tui-screens.md` | added | `zfa tui create-tui-screens` |
| `test/cli/standard/extension_command_parity_test.dart` | added | Parity + shape regression test (RED -> GREEN). |

## Diff Highlights

Each generated doc follows the existing template (frontmatter `name`/`description`/
`category`, `## Usage`, `## When to Use`, `## Required Parameters`, `## Flags`
derived from the manifest `inputSchema`, `## Output`). Example `provides:` entry:

```yaml
    - name: speckit.zuraffa.route.deep-link
      file: commands/presentation/route_deep-link.md
      description: Generate a deep-link GoRoute module and register the URL scheme ...
      aliases: [zfa.route.deep-link]
      category: presentation
```

## Tests Added or Updated

- `test/cli/standard/extension_command_parity_test.dart::every zfa manifest command is registered in the speckit extension` — shells `zfa manifest`, maps each command to its expected `zfa` alias (encoding the known irregular mappings), and asserts a `provides:` entry + on-disk file exists. RED with 14 missing, GREEN at 0.
- `test/cli/standard/extension_command_parity_test.dart::each command .md follows the template shape` — asserts every registered command doc has frontmatter + `## Usage` + `## When to Use`.

## Local Verification

- Commands run: `dart test test/cli/standard/extension_command_parity_test.dart` -> All tests passed (2/2).
- Manual checks: `zfa manifest` returns 54 commands; `extension.yml` `provides.commands` now has 57 entries (43 existing + 14 new); the 14 new `.md` files exist on disk.

## Deviations from Assessment

- The issue listed **10** missing commands (based on an older 53-command manifest).
  The current manifest has **54** commands; this fix covers the **14** genuinely
  missing ones (the 10 from the issue plus `cache/adapter`, `graphql/create`,
  `sqlite/create`, `tui/create-tui-screens`, which appeared after the issue was
  filed). Scope was broadened to full manifest coverage rather than the stale list.
- The assessment suggested running `zfa generate-commands`, but that command is
  **not implemented** in the CLI (no source for it). The docs were generated via a
  throwaway manifest-driven script instead. Implementing the generator itself is
  out of scope and noted as a follow-up.

## Follow-ups

- Implement `zfa generate-commands` (or a CI job) so the extension stays in sync
  with the manifest automatically; the parity test can gate that pipeline.
- Consider de-irregularizing the alias mapping (e.g. `feature/scaffold` ->
  `zfa.feature.scaffold`) to make the parity mapping mechanical.
