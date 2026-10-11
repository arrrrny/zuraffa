# Plan — Spec 1363 contract stub duplicate arg0

**Branch**: `1363-contract-stub-dup-args` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`ContractParam.parse(cell, {index})`: bare identifier cells → declared
name + `dynamic` type; non-identifier cells without a top-level space →
positional `arg$index`; the typed-cell branch's invalid-name fallback →
`arg$index`. Call site passes the cell position. The test writer's
summary renders the same params — unique by construction.

## Test strategy

`test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart`: writer-level
pair generation for the issue repro + typed/unnamed/mixed rows, with a
depth-aware signature-name extractor (comment lines skipped — the stub
header echoes the declared grammar verbatim). Scoped pin: the #1323 seam
tests + analyze.
