# Tasks — Spec 1378 proof prune

- [x] T001. [behavior: B1] Dry run lists the dead receipt, deletes nothing. Traces FR-1/AS-1.
- [x] T002. [behavior: B2] --apply deletes the dead receipt, keeps live. Traces FR-2/AS-2.
- [x] T003. [behavior: B3] Partial receipts kept even under --apply. Traces FR-3/AS-3.
- [x] T004. [behavior: B4] Empty store → honest no-receipts message. Traces FR-4/AS-4.
- [x] T005. Implement ProofPruneCommand + registration + usage line. Traces FR-1..FR-4.
- [x] T006. Regression pin: the four proof suites; analyze + format clean. Traces SC-002.
