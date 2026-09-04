# Tasks: Plug-In Merge Contract (074)

**Feature**: specs/074-plugin-merge-contract | **Issue**: arrrrny/zuraffa#962
**Input**: design documents from `specs/074-plugin-merge-contract/` (plan, research, data model, contracts)

## Phase 1: Setup

- [ ] T001 Scaffold `specs/074-plugin-merge-contract/tdd/` (derived via `zfa tdd plan`)

## Phase 2: Behaviors (TDD — red first)

- [ ] T002 **[behavior U1]** Merge triggers the routing-index regeneration for the landed feature's modules (barrel includes them) — `slice_merger.dart` + route plugin seam
- [ ] T003 **[behavior U2]** Every declared route path resolves through the generated table to the declared page — `verifier/conformance_gate.dart` (routes check)
- [ ] T004 **[behavior U3]** A colliding route name/path refuses before landing naming both modules — route registration contract
- [ ] T005 **[behavior U4]** Merge generates + runs the DI graph-construction test; every manifest token resolves per flavor — `verifier/di_graph_check.dart`
- [ ] T006 **[behavior U5]** A missing binding fails the di check naming the token + fix — di graph check
- [ ] T007 **[behavior U6]** Views check: merged pages compose the host shell convention; an off-convention artifact refuses naming the file — conformance views check
- [ ] T008 **[behavior U7]** Merge snapshots the touched host files pre-landing (content-addressed) — `merger/host_baseline.dart`
- [ ] T009 **[behavior U8]** Any gate failure restores the snapshot byte-identical (re-hash proof) and exits non-zero naming the failed checks — rollback path
- [ ] T010 **[behavior U9]** The feature-suite gate compares against the pre-merge baseline: pre-existing reds never fail; NEW reds always do — host_baseline suite diff
- [ ] T011 **[behavior U10]** The verdict is JSON, one line per check (routes/di/views/featureSuite), exit-coded — conformance verdict contract
- [ ] T012 **[behavior U11]** Re-merge with unchanged artifacts is a byte no-op with gates re-passing — idempotence
- [ ] T013 **[behavior A1]** End-to-end: a verified login-shaped slice merges into a fixture host with zero hand-edits (route resolves, graph constructs both flavors, feature suite green) and the verdict is green
- [ ] T014 **[behavior A2]** End-to-end sabotage: a removed route declaration after verify → routes fail → byte-identical rollback + named failure

## Phase 3: Wiring & polish (non-behavior)

- [ ] T015 `MergeContract` + `HostBaseline` + `ConformanceVerdict` models; CLI flags (`--json`) + help text
- [ ] T016 Docs: docs/ + openwiki touchpoints for the conformance-gated merge

## Phase 4: Verification

- [ ] T017 `dart analyze` clean; scoped suites green; spec-whole verify (audit) for the feature
