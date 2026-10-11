# Tasks: 0967-spec-mutation-arena

| id | task | status |
| -- | ---- | ------ |
| T-01 | RED: write the failing suites (spec_mutator_test, spec_fuzz_auditor_test, spec_fuzz_command_test, spec_fuzz_demo_test) and capture the real red evidence (command not found; URIs missing) | done |
| T-02 | SpecMutation models: operator set, candidate, verdict, gate decision, weakness report + markdown/JSON rendering | done |
| T-03 | SpecMutator: deterministic candidate generation per contract element (weaken/drop/swap-literal/widen/drop-must-not) + line-surgical application + budget/seed selection | done |
| T-04 | SpecFuzzAuditor: preflight, P1/P2/P3 pins, per-mutant capture/restore, verdicts, gate decision | done |
| T-05 | Ledger integration: deduplicated severity:contract gap appends for survivors; --no-ledger | done |
| T-06 | SpecFuzzCommand + SpecCommand group + CliRunner registration; flags; exit codes; machine line; verdict.v1 envelope; corpus mode | done |
| T-07 | Seeded weakness demo: toy feature, weak spec flagged / strengthened spec kills all — integration test (slow tier) + tools/spec_fuzz_demo.sh + CI job | done |
| T-08 | GREEN: full new suite + dart analyze (zero new issues vs baseline) + chunked fast suite + dart format (zero diffs) | done |
| T-09 | tdd/verification.md from the REAL runs; cycle-log red/green evidence | done |
