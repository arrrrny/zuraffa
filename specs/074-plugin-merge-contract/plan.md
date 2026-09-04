# Implementation Plan: Plug-In Merge Contract (074)

**Branch**: `074-plugin-merge-contract` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/074-plugin-merge-contract/spec.md` (issue #962)

## Summary

Turn `slice merge` into a conformance-gated plug-in: after landing, the host's route barrel regenerates (`getAllRoutes()` — the existing route-index seam), the feature's bindings register through the host's flavor-switched DI and a DI-graph construction check (the bootstrap smoke pattern) proves the graph constructs in both flavors, merged views must compose behind the host's adaptive-shell convention, and the whole landing is verdict-gated — routes/DI/feature-suite each checked against a pre-merge host baseline, with byte-identical rollback and named failures on any red.

## Technical Context

**Language/Version**: Dart 3.13 (repo pins `sdk: ^3.11.0`)
**Primary Dependencies**: slice merger/verifier, route plugin (`getAllRoutes()` regeneration), di plugin (flavor-switched bindings #893/#934), smoke-test writer (bootstrap smoke), tdd suite/baseline (#741/#953), 073 verify verdict
**Storage**: filesystem (baseline snapshot = byte-level tree fingerprint; verdict JSON)
**Testing**: `dart test` fast tier
**Target Platform**: CLI
**Performance Goals**: baseline capture + gate run bounded by the host's own suite
**Constraints**: rollback must be byte-identical (content-addressed snapshot, not git)
**Scale/Scope**: merge hardening over existing seams — no new routing/DI mechanism

## Constitution Check

- Errors-are-an-API: failed gates name the offending route/token/behavior + `--> fix:`. ✅
- Verdicts, never prose (VISION §4): the conformance verdict is JSON, one line per check. ✅
- Manifest-as-treaty: gates check the manifest's declared facts. ✅
- Baseline fairness: pre-existing reds never fail a merge (FR-007). ✅

## Key Design Decisions

1. **Route registration = barrel regeneration.** The route plugin already
   regenerates `getAllRoutes()` when routes are added (`route index`
   regeneration). Merge invokes the same regeneration for the landed
   feature's route modules — additive; a conflicting route name refuses
   naming both. Route resolution is then proven by resolving each
   declared path through the generated table (pure check, no app boot).
2. **DI proof = graph construction, not string search.** A generated
   conformance test (smoke-test writer pattern) constructs the merged
   host's graph: every manifest token resolves in mock AND real flavor.
   The check runs as part of the conformance suite — evidence, not
   grep.
3. **View conformance = structural check.** Each merged page must
   compose the host shell convention (the view contract 071's proven
   shapes emit); an off-convention artifact refuses naming the file.
4. **Rollback = pre-merge byte snapshot.** Capture a content-addressed
   snapshot of every host file merge will touch (or the whole tree's
   fingerprint + copies of touched files); any gate failure restores
   exactly those bytes and verifies the restore byte-identically
   (FR/SC: byte-identical rollback without depending on git).
5. **Baseline-aware feature-suite gate.** Capture the host suite's
   pre-merge results; post-merge, only NEW failures fail the gate
   (pre-existing reds are reported, never blamed).

## Project Structure

```text
specs/074-plugin-merge-contract/
├── plan.md  research.md  data-model.md  quickstart.md
├── contracts/
│   ├── conformance-verdict.md     # the merge verdict contract
│   ├── route-registration.md      # barrel regeneration + resolution check
│   └── di-graph-check.md          # binding + construction check contract
└── tdd/

lib/src/plugins/slice/merger/slice_merger.dart      # gated landing + snapshot rollback
lib/src/plugins/slice/merger/host_baseline.dart     # NEW: snapshot + new-failure diff
lib/src/plugins/slice/verifier/conformance_gate.dart # NEW: routes/DI/views/suite checks
lib/src/plugins/slice/verifier/di_graph_check.dart   # NEW: graph construction test gen/run
lib/src/plugins/slice/capabilities/merge_slice_capability.dart
test/plugins/slice/074_*_test.dart                   # behaviors
```
