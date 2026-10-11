# Tasks — Spec 1365 split skin-contract parity

- [x] T001. [behavior: B1] Split renders the typed skin contract sections + machine JSON. Traces FR-1/AS-1/SC-001.
- [x] T002. [behavior: B2] Malformed section refuses (exit 2, no artifacts). Traces FR-2/AS-2.
- [x] T003. [behavior: B3] No-section guard: pre-1004 shape. Traces FR-3/AS-3.
- [x] T004. [behavior: B4] Forced re-split keeps the contract. Traces FR-4/AS-4.
- [x] T005. Implement: parseAdaptiveSkinContract in the split path + renderSkinPlan skinContract + refusal envelope. Traces FR-1..FR-4.
- [x] T006. Regression pin: split 1000, #1309, plan-skin-contract, skin-receipt suites; analyze + format clean. Traces SC-002.
