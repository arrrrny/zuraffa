# Bug Assessment: fix(tdd verify) — verification hangs on full-suite baseline with many pre-existing failures

- **Slug**: tdd-verify-hang-on-preexisting-red
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/924
- **Verdict**: valid — the verify preflight pays the full-suite baseline before the mutation config is resolved, so a corpus-scale project with many pre-existing failures never reaches its `gate: not_assessed` verdict inside any reasonable wall clock
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd verify --feature <name>` hangs indefinitely when the project has many pre-existing test failures (24+ in spec 004 / forklift). The verify step runs the full suite as the mutation-audit preflight and never returns; the process must be killed manually. The expected `gate: not_assessed` (missing `mutation-test.xml`) is never reached because the preflight does not complete. https://github.com/arrrrny/zuraffa/issues/924

## Symptom

Three compounding costs sit between `zfa tdd verify` and its verdict:

1. The preflight runs one combined `dart test` over the whole registered scope — at corpus scale with 24+ pre-existing failures this is the full-suite baseline: the test runner has to load every failing test file and report the load errors before exiting.
2. The mutation config resolution happens only AFTER the preflight (inside the mutation phase), so a missing/unresolvable config — the `mutation-test.xml not found` per-preset lookup failure — is discovered only after the suite cost has already been paid.
3. The operator sees no output and no exit, and kills the process (>30 min observed).

## Reproduction

1. Project with 24+ pre-existing test failures and a feature whose registered behaviors are green (13 behaviors in spec 004).
2. `zfa tdd verify --feature 004-cloud-agent-task-dispatch`
3. Observe: no output, no exit for >30 minutes; the expected `gate: not_assessed` (no `mutation-test.xml`) is never reached.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/mutation_auditor.dart` — `run()` orders the green-suite preflight (FR-013) BEFORE the mutation phase; the scoped mutation config (`_defaultMutation`) is written inside the mutation phase, after the preflight.
- `lib/src/plugins/tdd/services/mutation_auditor.dart` — `_defaultPreflight` spawns ONE combined `dart test <all scope test paths>` invocation: the full-suite baseline shape.
- `lib/src/plugins/tdd/commands/verify_command.dart` — the `--timeout` flag exists (bug #742) and bounds the preflight child, but the phase's default budget (10 min) still pays the baseline before the config verdict, and the combined invocation gives no per-behavior granularity.

## Root Cause Hypothesis

An ordering + granularity bug, not a missing-timeout bug: the config-first ordering is inverted (config resolution must precede any test run — a missing mutation config makes the whole audit NOT_ASSESED regardless of suite state, so the suite run buys nothing), and the preflight's combined invocation is the full-suite baseline the issue names. The #742 timeouts bound the hang but do not fix the wasted baseline or the unreachable verdict ordering.

## Proposed Remediation

1. **Config-first ordering**: resolve the scoped mutation config BEFORE the preflight. A config resolution failure returns `gate: not_assessed` immediately — no test process is ever spawned (remediation point 3).
2. **Per-behavior preflight**: when the feature has its own test files, run each registered test file individually (the TDD profile's single/file template shape) and fail fast on the first red, instead of one combined baseline invocation. The whole phase stays bounded by the #742 budget (one wall clock shared across the per-behavior runs). No own test files → green no-op; there is NO full-suite fallback (remediation point 2).
3. **--timeout respected + non-zero exit on timeout**: keep the #742 contract — `--timeout <minutes>` bounds the preflight phase and the mutation run; a timed-out phase is NOT_ASSESSED (never preflight_red) and the command exits non-zero (64 usage class) (remediation point 1).
4. **Diagnostics**: the files the per-behavior preflight actually executed are surfaced as `preflight_scope_ran` in `verification.md`, so a corpus-scale run shows exactly how far the fail-fast got.

**Files changed**:
- `lib/src/plugins/tdd/services/mutation_auditor.dart` (config-first ordering, per-behavior preflight loop, `preflight_scope_ran` diagnostics)
- `test/plugins/tdd/bug_924_verify_preflight_test.dart` (new: unit + CLI integration coverage)

**Tests to add**:
- config-first: missing/unresolvable mutation config → NOT_ASSESSED naming the config, preflight never invoked (unit, and CLI with a hanging fixture test to prove no suite run)
- per-behavior fail-fast: red file stops the run; `preflight_scope_ran` lists exactly what ran (unit + CLI)
- phase budget: per-behavior runs bounded by the shared `--timeout` budget → NOT_ASSESSED 'preflight timed out' (unit)
- no own test files → nothing runs, no full-suite fallback (unit)

## Risks & Considerations

- Per-behavior preflight adds per-file `dart test` startup cost in the all-green case (N × ~1–2 s). Accepted: bounded by the same phase budget, and the red case (the bug's scenario) gets strictly faster.
- The `runPreflight` list-level override (test seam) is preserved unchanged — existing tests keep their semantics; the per-behavior seam is additive.
- The mutation phase reuses the pre-written config; its behavior (scoped subjects per #837, bounded by #742) is unchanged.

## Open Questions

- [RESOLVED: should the preflight keep a full-suite fallback when the feature has no own test files?] No — the empty-scope green no-op stands (FR-012 already returns NOT_ASSESSED for an empty registry; a non-empty registry without test files proceeds with the '(no scope)' green preflight, unchanged from #837 behavior).
