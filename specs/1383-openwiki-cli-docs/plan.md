# Plan — Spec 1383 openwiki cli docs

**Branch**: `1383-openwiki-cli-docs` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`tool/generate_openwiki_cli_docs.dart`: spawn `zfa --help` → parse the
"Available commands" block → per command spawn `zfa <cmd> --help` →
render `docs/openwiki/cli.md` (generated marker, registry count, SPEC 917
taxonomy, envelope contract, per-command fenced help). Drift pin:
`test/docs/openwiki_cli_docs_test.dart` (B1 exists, B2 ≥50 sections, B3
key verbs, B4 taxonomy + envelopes).

## Test strategy

Hermetic file assertions in the fast tier; the generator runs only at
regeneration time.
