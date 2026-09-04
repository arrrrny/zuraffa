# Implementation Plan: Slice-Driven Isolation (073)

**Branch**: `073-slice-isolation` | **Date**: 2026-09-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/073-slice-isolation/spec.md` (issue #961)

## Summary

Prove the slice plugin end to end on the login rail: make `slice cut` emit a **runnable** sandbox (app shell + router harness exposing the feature's routes + mock DI binding every declared touchpoint, via the 072 dependency-mock rail), make the tdd loop run with the sandbox as project root and leave its journal/registry inside, give `slice verify` a machine-readable JSON verdict (self-containment, mock certification, suite state), and gate `slice merge` on a passing verify — landing artifacts + journal + registry into the host with the host suite green.

## Technical Context

**Language/Version**: Dart 3.13 (repo pins `sdk: ^3.11.0`)
**Primary Dependencies**: slice plugin (capabilities/engine/exporter/generators/merger/models/runner/verifier), tdd plugin (loop, profile, journal/registry), 072 dependency-mock rail
**Storage**: filesystem (sandbox project tree; manifest + verdict JSON)
**Testing**: `dart test` fast tier; widget-lane proof via the loop's generated suites
**Target Platform**: CLI
**Performance Goals**: deterministic scaffolding (byte-identical re-cuts)
**Constraints**: sandbox must not import the host (self-containment is the product); pure-Dart generator (no Flutter imports in generator code)
**Scale/Scope**: completion + proving pass over an existing plugin — no parallel plugin

## Constitution Check

- Test-first: behaviors land through `specs/073-slice-isolation/tdd/` red-first. ✅
- Errors-are-an-API: every refusal names path/reference/check + `--> fix:` hint. ✅
- Determinism: unchanged cut inputs → byte-identical wiring. ✅
- Manifest-as-treaty: the SliceManifest is the verified/landed truth. ✅

## Key Design Decisions

1. **Runnable = shell + router harness + mock DI.** `cut` composes: (a) the feature's spec + tdd artifacts (existing export surface), (b) a minimal app shell generator output (app_shell plugin's proven shape), (c) a router harness exposing exactly the slice manifest's declared routes, (d) a DI bootstrap binding certified mocks for every declared dependency — reusing 072's `zfa mock dependency` rail for the mocks and the channel fake rail for channels.
2. **Self-containment is a verified property, not a hope.** The verifier's import check (existing `import_verifier`) gains a host-reference scan: any reference escaping the sandbox root fails self-containment, named.
3. **JSON verdict.** `verify_slice` gains a `--json` machine verdict `{selfContainment, mockCertification, suiteState}` each with pass/fail + offenders; exit 0 only when all pass.
4. **The loop runs in the sandbox.** `tdd` commands already take `--project`; the slice runner sets the sandbox as root and the journal/registry land inside — proof: loop completion inside an isolated copy.
5. **Merge gates on verify.** `merge_slice` refuses when the manifest's verify verdict is failing or absent; landing copies artifacts + journal + registry and runs the HOST suite, reporting its outcome (074 later adds conformance gates).

## Project Structure

```text
specs/073-slice-isolation/
├── plan.md  research.md  data-model.md  quickstart.md
├── contracts/
│   ├── sandbox-layout.md      # what cut emits, deterministically
│   ├── verify-verdict.md      # JSON verdict contract
│   └── merge-landing.md       # landing + gate contract
└── tdd/

lib/src/plugins/slice/
├── capabilities/cut_slice_capability.dart      # runnable sandbox composition
├── capabilities/verify_slice_capability.dart   # JSON verdict
├── capabilities/merge_slice_capability.dart    # verify-gated landing
├── generators/ (shell/router/DI scaffolds)     # new deterministic generators
├── verifier/ (host-reference scan, suite runner)
└── models/slice_manifest.dart                  # declared facts + verdict
test/plugins/slice/073_*_test.dart              # behaviors
```
