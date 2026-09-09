# Tasks — Spec 1357 registry path re-anchor

- [x] T001. [behavior: B1] Registry with sandbox-absolute paths loads repo-relative (incl. runnable prefix). Traces FR-1/AS-1.
- [x] T002. [behavior: B2] Existing absolute path kept verbatim. Traces FR-2/AS-2.
- [x] T003. [behavior: B3] Unresolvable absolute path passes through. Traces FR-2/AS-3.
- [x] T004. [behavior: B4] Relative paths pass through. Traces FR-2/AS-4.
- [x] T005. [behavior: B5] MutationScope.derive yields existing test paths. Traces FR-3/AS-5.
- [x] T006. Implement the read-boundary re-anchor in ArtifactRegistry (pure reanchorRecordPath + record rewrite). Traces FR-1..FR-3.
- [x] T007. Regression pin: tdd plugin suite; analyze + format clean. Traces SC-002.
