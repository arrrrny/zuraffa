# Implementation Plan: `zuraffa_ocr` federated plugin delivery

**Branch**: `1602-zuraffa-ocr-plugin` | **Date**: 2026-09-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/1602-zuraffa-ocr-plugin/spec.md`

## Summary

Deliver the OCR instance of the proven spec-1601 generator: run
`zfa package create-plugin zuraffa_ocr` (OCR description,
`arrrrny/zuraffa_ocr` identity), prove the generated family is healthy
(per-package pub get / analyze / test, publish dry-runs), and push the
repo to GitHub. No generator changes — this feature pins and verifies the
OCR instance.

## Technical Context

**Language/Version**: Dart 3.13 (repo pins `sdk: ^3.11.0`); generated
packages are pure Dart (no Flutter SDK)

**Primary Dependencies**: the delivered `zfa package plugin` / `create-plugin`
command (spec 1601), `package:test`, `run_zfa_source` helper

**Storage**: N/A — generator writes the caller's filesystem; delivery
creates one git repo

**Testing**: `dart test` per `.specify/memory/tdd-profile.md`; feature
scope `test/package_sdk/`; slow tier via `--preset=integration` (network
for pub get)

**Target Platform**: CLI (generated family targets Android/iOS/macOS
consumers)

**Performance Goals**: fast tier < 30 s; full board (5×pub get + analyze +
test + dry-run) < 15 min

**Constraints**: zero manual edits between scaffold and green board; no
generator modifications

**Scale/Scope**: 2 test files (fast instance test + slow e2e), 1 delivery
procedure, 1 pushed repo

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution file remains the unfilled template — no project-specific
gates. Repo hard rules honored: `dart format lib test` before commits;
STOP-ON-ROADBLOCK applies to the delivery board (first unexpected failure
stops the run and reports). **Gate result: PASS** (post-design: PASS).

## Project Structure

### Documentation (this feature)

```text
specs/1602-zuraffa-ocr-plugin/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── ocr-delivery.md  # The delivery contract (invocation + board)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
test/package_sdk/
├── plugin_ocr_instance_test.dart   # NEW fast tier: OCR stamps/wiring/harness (B1–B2)
└── plugin_ocr_e2e_test.dart        # NEW slow tier: family health board (B3)
```

**Structure Decision**: instance tests live beside the spec-1601
generator tests and reuse their helpers; no lib/ changes at all (the
generator is frozen for this feature).

## Complexity Tracking

> No constitution violations — table intentionally empty.
