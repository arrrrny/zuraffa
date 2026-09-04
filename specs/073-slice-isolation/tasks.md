# Tasks: Slice-Driven Isolation (073)

**Feature**: specs/073-slice-isolation | **Issue**: arrrrny/zuraffa#961
**Input**: design documents from `specs/073-slice-isolation/` (plan, research, data model, contracts)

## Phase 1: Setup

- [ ] T001 Scaffold `specs/073-slice-isolation/tdd/` (derived via `zfa tdd plan`; 22 behaviors)

## Phase 2: Behaviors (TDD — red first)

- [ ] T002 **[behavior U1]** Cut emits the standalone pubspec (no host path deps) — `cut_slice_capability.dart` + generators
- [ ] T003 **[behavior U2]** Cut composes the shell bootstrap + router harness exposing exactly the manifest's declared routes — `generators/`
- [ ] T004 **[behavior U3]** Cut binds a certified mock per declared dependency (072 rail for service/storage; channel fake rail for channels) — `generators/` + `models/slice_manifest.dart`
- [ ] T005 **[behavior U4]** Cut installs the certified channel fake for a declared channel dependency — `generators/`
- [ ] T006 **[behavior U5]** Re-cut with unchanged inputs is byte-identical (scaffolding) — determinism pin
- [ ] T007 **[behavior U6]** The sandbox suite runs green with the host path unavailable (self-containment by execution) — cut + sandbox layout
- [ ] T008 **[behavior U7]** A widget test in the sandbox pumps the shell and navigates a declared route through mock DI — sandbox shape
- [ ] T009 **[behavior U8]** `tdd run` with the sandbox as project root completes its cycle and writes journal/registry INSIDE the sandbox — slice runner + tdd `--project`
- [ ] T010 **[behavior U9]** verify `--json` emits the three-check verdict and exits 0 when clean — `verify_slice_capability.dart` + `verifier/`
- [ ] T011 **[behavior U10]** A host-import inside a sandbox file fails self-containment with the offender named — `verifier/import_verifier.dart`
- [ ] T012 **[behavior U11]** An unbound declared dependency fails mockCertification naming the dependency — verify
- [ ] T013 **[behavior U12]** A red sandbox suite fails suiteState naming the failing test — verify
- [ ] T014 **[behavior U13]** Merge refuses when the verify verdict is failing or absent, naming `--> fix: zfa slice verify` — `merge_slice_capability.dart`
- [ ] T015 **[behavior U14]** Merge lands artifacts + journal + registry into the host and runs the host suite, reporting the outcome line — merger + runner
- [ ] T016 **[behavior U15]** A red host suite with NEW failures after landing names them (baseline-aware, no false blame) — merge outcome
- [ ] T017 **[behavior U16]** Cut refuses a missing/invalid host (exit 2) and an absent feature spec (exit 3) with fix hints
- [ ] T018 **[behavior A1]** End-to-end: cut → loop inside → verify → merge into a fixture host lands the feature with the host suite green

## Phase 3: Wiring & polish (non-behavior)

- [ ] T019 SliceManifest carries `dependencyBindings` + verdict; CLI help text for the new flags
- [ ] T020 Docs: docs/ + openwiki touchpoints for the proven slice workflow

## Phase 4: Verification

- [ ] T021 `dart analyze` clean; scoped suites green; spec-whole verify (audit) for the feature
