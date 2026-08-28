# Bug Assessment: Speckit CLI Commands: 10 commands missing from extension manifest

- **Slug**: speckit-cli-commands-10-missing
- **Created**: 2026-08-28
- **Source**: https://github.com/arrrrny/zuraffa/issues/499
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

Issue #499 reports that the Zuraffa Speckit extension is missing 10 commands from `zfa manifest` output. The manifest exposes 53 plugin commands, but the extension only has 43 `.md` files registered, so 10 CLI commands are unavailable through the extension. Missing commands: `zfa api create-api-bridge`, `zfa gym create`, `zfa mock json`, `zfa mcp scaffold`, `zfa module create_module`, `zfa route deep-link`, `zfa route shell`, `zfa sync enable`, `zfa strategy create`, `zfa gql generate`. See https://github.com/arrrrny/zuraffa/issues/499.

## Symptom

The Speckit extension manifest does not include 10 plugin subcommands that exist in `zfa manifest`, so AI agents cannot invoke them through the extension.

## Reproduction

1. Run `dart run bin/zfa.dart manifest | jq 'length'` → 53.
2. Count `.specify/extensions/zuraffa/commands/*.md` files → 43.
3. Diff plugin/subcommand pairs → 10 missing.
4. Confirm missing commands absent from `extension.yml` provides section.

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: …]
