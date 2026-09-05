# Implementation Plan: skin-contract runtime binding (issue #1165 stage 2a)

**Branch**: `079-skin-contract-binding` | **Date**: 2026-09-05 | **Spec**: [spec.md](spec.md)

## Summary

Pure-Dart binding layer turning a parsed `SkinContract` into the runtime kit's inputs:
route table (reusing `RouteContractTable` from #1102), per-view state bindings
(toaster/inline/none + empty), audit-row descriptors from `stateRows`, and contract
identity from the `## Skin Contract: <name>` heading (parser extended to carry it).

## Technical Context

- Dart 3.13, pure Dart; extends `lib/src/skin/contract/`; exported via `lib/skin.dart`.
- Consumer: `zuraffa_flutter` (Flutter shell) across the package boundary; no Flutter here.
- Tests: `dart test test/plugins/skin_contract/` + behavior tests `test/tdd/079-*`.

## Research decisions

| Decision | Rationale |
|---|---|
| Binding object `SkinContractRuntimeBinding` (name + routeTable + stateBindings + auditRows) | One call, one object — the shell mounts it whole (FR-001, FR-005) |
| `RouteContractTable.fromRouteNames` reuse | #1102 semantics preserved verbatim (SC-002); set semantics dedupe duplicate paths |
| Parser gains declaration-level API: `parseSkinContractDeclaration(markdown)` → `{name, contract}` | Identity lives in the heading, not the JSON body; keeps `parseSkinContractJson` unchanged for existing callers |
| `StateBinding` as pure data (errorKind: none/toaster/inline, empty: bool) | The Flutter shell maps toaster/inline to real UI; core stays UI-free (FR-006) |

## Constitution Check

- Engine lane stays Flutter-free (analyzer-verifiable); v5 layout respected (`lib/src/skin/contract/`). No violations.
