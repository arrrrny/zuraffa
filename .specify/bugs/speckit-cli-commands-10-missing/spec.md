# Bug Spec: Speckit CLI Commands missing from extension manifest

- **Slug**: speckit-cli-commands-10-missing
- **Source issue**: https://github.com/arrrrny/zuraffa/issues/499
- **TDD feature dir**: .specify/bugs/speckit-cli-commands-10-missing

## Problem

The Zuraffa Speckit extension (`specs`/`zuraffa` extension) advertises commands
through `.specify/extensions/zuraffa/extension.yml` `provides:` entries, each pointing
at a `commands/*.md` file. The `zfa` CLI exposes its full command surface via
`zfa manifest` (currently **54** plugin commands). The extension only registers
**43** command files, so **14** manifest commands are unavailable to AI agents through
the extension. The `zfa generate-commands` command that is supposed to keep these in
sync is **not implemented** in the CLI (no source), so the gap is invisible until
someone diffs the two.

## Acceptance Criteria

- **AC1** — Every command returned by `zfa manifest` has a corresponding
  `provides:` entry in `.specify/extensions/zuraffa/extension.yml` (by `zfa`
  alias), and the referenced `commands/*.md` file exists on disk.
- **AC2** — Each generated command `.md` follows the existing template convention
  (YAML frontmatter `name`/`description`/`category`, `## Usage`, `## When to Use`,
  `## Required Parameters`, `## Flags` derived from the manifest `inputSchema`,
  `## Output`).
- **AC3** — Running the parity check reports **0** missing commands.

## Out of scope

- Implementing the `zfa generate-commands` regeneration script itself (tracked
  separately). This fix covers the currently-missing commands manually.
- Re-categorizing already-covered commands.

## Reproduction (failing scenario)

1. `dart run bin/zfa.dart manifest` → 54 commands.
2. Parse `.specify/extensions/zuraffa/extension.yml` `provides:` aliases.
3. For each manifest command, map to its expected `zfa` alias
   (`zfa.<plugin>` for the `create` subcommand, else `zfa.<plugin>.<name>`).
4. Assert a `provides:` alias matches → **fails** for the 14 missing commands:
   `api/create-api-bridge`, `cache/adapter`, `gql/generate`, `graphql/create`,
   `gym/create`, `mcp/scaffold`, `mock/json`, `module/create_module`,
   `route/deep-link`, `route/shell`, `sqlite/create`, `strategy/create`,
   `sync/enable`, `tui/create-tui-screens`.
