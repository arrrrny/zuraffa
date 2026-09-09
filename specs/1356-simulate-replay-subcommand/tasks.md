# Tasks — Spec 1356 simulate replay subcommand

- [ ] T001. [behavior: B1] CLI: bare replay after init+run → GREEN deterministic proof. Traces FR-1/AS-1.
- [ ] T002. [behavior: B2] CLI: replay with no recorded receipt → honest exit 1 + run-first fix. Traces FR-2/AS-2.
- [ ] T003. [behavior: B3] CLI: replay on a mutated world → exit 1 naming both hashes. Traces FR-2/AS-3.
- [ ] T004. [behavior: B4] CLI: tampered digest → exit 1 DIGEST MISMATCH + both digests. Traces FR-3/AS-4.
- [ ] T005. [behavior: B5] Help lists replay; legacy flag surface regression guard. Traces FR-4/AS-5.
- [ ] T006. Implement SimulateReplayCommand + parser-only registration + docs (turns B1–B5 GREEN). Traces FR-1..FR-4.
- [ ] T007. Regression pin: scoped simulate suites green; analyze + format clean. Traces SC-002.
