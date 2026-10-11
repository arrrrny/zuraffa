**Template Version**: `zuraffa-1.0`

# Spec: 1374-baseline-scope-flag

GitHub issue: arrrrny/zuraffa#1374 (verify-misfire / missing-integration,
EPIC #1136 Phase C / spec-mutation arena #967)

## Summary

`tdd run` / `tdd make` unconditionally run the FULL-suite baseline
(`dart test` over the whole tree — the #741 once-per-run cache). On a
10 GB-disk agent that single invocation dies (`No space left on device`),
and no verb can produce the FIRST `run-baseline.json` without the very
run that cannot execute — a bootstrapping deadlock. The `--suite-baseline`
flag only consumes an EXISTING cached baseline; nothing produces the
first one.

## Locked decisions

1. `--baseline-scope <dir>` on BOTH verbs: the baseline suite command is
   the profile template with the scope appended — canonically the
   feature's test directory (`test/tdd/<feature>`), the same scoped
   surface the issue's workaround used.
2. A scoped baseline is per-feature: the corpus-wide cache is bypassed
   on BOTH sides (no reuse, no write) — a scoped snapshot must never
   masquerade as corpus-wide reuse (spec 069 T004 semantics preserved
   for the unscoped path).
3. The feature run-baseline is still written from the scoped snapshot
   (make steps reuse it, issue #741 unchanged).
4. Without the flag, behavior is byte-identical (the unscoped suite
   command, corpus cache as before).

## Functional requirements

- **FR-1**: `zfa tdd run <f> --baseline-scope <dir>` prints the scoped
  baseline command (`suite baseline: <suite> <dir>`).
- **FR-2**: `zfa tdd make <id> --baseline-scope <dir>` scopes its live
  baseline branch the same way.
- **FR-3**: without the flag the baseline command stays unscoped
  (guard), and the corpus cache is not bypassed.

## Acceptance scenarios

1. run with `--baseline-scope test/tdd/<f>` → the baseline line carries
   the scope (B1).
2. make with `--baseline-scope test/tdd/<f>` → the baseline line carries
   the scope (B2).
3. make without the flag → the unscoped line (B3).

## Success criteria

- **SC-001**: On a constrained agent, `run --baseline-scope
  test/tdd/<feature>` produces the first run-baseline.json — the
  deadlock is broken.
- **SC-002**: The tdd command suites stay green.

## Assumptions

- The scope string is appended verbatim to the profile suite command
  (single dir; the runner's compact-reporter wrapping handles the tokens).
