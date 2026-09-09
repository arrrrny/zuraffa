# Tasks — Spec 1360 unknown-option crash

- [x] T001. [behavior: B1] Undeclared subcommand option → exit 2 clean usage error (no null-check text). Traces FR-1/AS-1.
- [x] T002. [behavior: B2, B3] Parent-level clean refusal + valid invocation guards. Traces FR-2, FR-3/AS-2, AS-3.
- [x] T003. [behavior: B4] SPEC 917 fix line on the usage path. Traces FR-1/AS-1.
- [x] T004. Implement _CrashSafeCommandRunner.parse override. Traces FR-1..FR-3.
- [x] T005. Regression pin: cli suites green; analyze + format clean. Traces SC-002.
