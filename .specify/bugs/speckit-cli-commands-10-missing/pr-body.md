## Summary

The Speckit `zuraffa` extension advertised only 43 of the 54 commands exposed by
`zfa manifest`. Fourteen manifest commands had no `provides:` entry (and no
`commands/*.md`), so AI agents could not invoke them through the extension. This PR
generates the 14 missing command docs from the live manifest schema and registers
them in `extension.yml`, and adds a parity test that fails when any manifest command
is missing from the extension.

## Missing commands now covered

`api create-api-bridge`, `cache adapter`, `gql generate`, `graphql create`,
`gym create`, `mcp scaffold`, `mock json`, `module create_module`, `route deep-link`,
`route shell`, `sqlite create`, `strategy create`, `sync enable`, `tui create-tui-screens`.

(Note: the original issue #499 listed 10; the manifest has since grown to 54, so this
fix covers the 14 genuinely missing commands, including `cache/adapter`,
`graphql/create`, `sqlite/create`, and `tui/create-tui-screens` which appeared after
the issue was filed.)

## Changes

| File | Change |
|------|--------|
| `.specify/extensions/zuraffa/extension.yml` | Appended 14 `provides:` entries (aliases `zfa.<plugin>[.<name>]`) |
| `.specify/extensions/zuraffa/commands/{integration,graphql,tooling}/...` + others | 14 generated command `.md` docs |
| `test/cli/standard/extension_command_parity_test.dart` | New parity + shape regression test |

## Verification

- `dart test test/cli/standard/extension_command_parity_test.dart` → 2/2 passed (0 missing commands; all docs follow the template).
- Deliberate mutant: removing one `provides` entry made the parity test fail, then pass again on restore — the safety net is real.

Assessment: .specify/bugs/speckit-cli-commands-10-missing/assessment.md

Closes #499.
