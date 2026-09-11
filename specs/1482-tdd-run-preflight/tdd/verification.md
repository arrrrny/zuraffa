# Verification: 1482-tdd-run-preflight

## Test-first evidence (red → green)

| behavior | red evidence | green evidence |
| -------- | ------------ | -------------- |
| U-1482-1 (FR-001/FR-005 provenance read) | RED 1: `dart test test/plugins/tdd/issue_1482_run_preflight_test.dart` — compile errors: `RoutingProvenancePreflight` / `kRoutingPreflightSuggested` undefined (`Error: Method not found: 'RoutingProvenancePreflight'`) | GREEN: 12/12 fast tier — finding carries id, description, criterion token `FR-001`; rendered line is the exact spec shape |
| U-1482-2 (FR-001/FR-006 offending filter) | RED 1 (same compile failure — the filter vocabulary did not exist) | GREEN: acceptance/widget fallback rows, declared unit rows, DONE fallback rows and hand-completed (non-vacuous) fallback rows are never offending; only the provably-doomed unit rows list |
| U-1482-3 (FR-005/SC-4 fail-open + O(1)) | RED 1 (same compile failure) | GREEN: no test list → ok; no provenance section → ok; lane meta-index resolves provenance from 04-ENGINE.md; declared/refused route lines are not fallback |
| U-1482-4 (FR-002/FR-004/SC-1 command refusal) | RED 2: `dart test --preset=all test/plugins/tdd/issue_1482_run_preflight_driver_test.dart` — no preflight wiring: transcript drove the loop instead of refusing (no refusal block, steps spawned) | GREEN: 4/4 driver tier — exact refusal block (header, `  U1 — ... (no declared contract trace, fallback to FR-001)`, `  U2 — ...`, `Suggested:` line), all-zero `result=stopped` summary line as the final stdout line, exit 1, `stepInvocations()` and `stepArgvLog()` EMPTY (zero spawns), journal entry `gate_state=preflight_red` / `phase=gate` / `result=stopped` with one violation per row |
| U-1482-5 (FR-003/SC-2 --force) | RED 2 (same — no `--force` flag existed: `Could not find an option named "force"`) | GREEN: `--force` bypasses ONLY the routing preflight — the loop drives gen/verify-red/make and the honest vacuous-green stop is byte-identical (`stopped_at=U1:make`, the #1308 remedy line), exit 1 |
| U-1482-5b (declared feature passes vacuously) | — (green by construction pre-change; pinned to stay green) | GREEN: declared-routed feature drives to `result=complete`, exit 0, no refusal block |
| U-1482-5c (FR-003 #1303 interplay) | RED 2 (same — no `--force` flag) | GREEN: with a stale path override AND `--force`, the #1303 gate still refuses (exit 3, `preflight: dependency_overrides` line) and the routing preflight never runs |
| U-1482-REG1 (SC-3 regression guard) | — | GREEN: `run_command_test.dart` 50/50, `run_engine_command_test.dart` + `run_skin_command_test.dart` 17/17, `issue_1308` fast+driver 9/9; `bug_1259_vacuous_green_test.dart` shows 3 failures that are BYTE-IDENTICAL on the clean base commit (94048e31, verified by stash-diff) — pre-existing environmental failures in the real-gen-pipeline scenarios U4/U5/U6, unrelated to this change |

## Test runs (cloud-agent scope: changed files only — no full suite)

```text
dart analyze lib/src/plugins/tdd/commands/run_command.dart
             lib/src/plugins/tdd/services/routing_provenance_preflight.dart
             test/plugins/tdd/issue_1482_run_preflight_test.dart
             test/plugins/tdd/issue_1482_run_preflight_driver_test.dart   → No issues found!
dart format (changed files)                                              → 0 changed
dart test test/plugins/tdd/issue_1482_run_preflight_test.dart            → 12/12 pass
dart test --preset=all test/plugins/tdd/issue_1482_run_preflight_driver_test.dart → 4/4 pass
dart test --preset=all test/plugins/tdd/run_command_test.dart            → 50/50 pass
dart test --preset=all test/plugins/tdd/commands/run_engine_command_test.dart
                        test/plugins/tdd/commands/run_skin_command_test.dart → 17/17 pass
dart test --preset=all test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart
                        test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart → 9/9 pass
dart test --preset=all test/plugins/tdd/bug_1259_vacuous_green_test.dart → 4/7 pass (3 pre-existing failures, identical on clean base — stash-diff verified)
```

## Test-smell rubric

- **Assertion strength**: the refusal tests pin the EXACT strings (header
  with the count, both rendered row lines, the `Suggested:` remedy), the
  exit code, the journal entry fields, and the ABSENCE of step spawns
  (argv-log emptiness) — not loose `contains('preflight')` matches.
- **No test-only backdoors**: the production path is driven end-to-end
  through `CliRunner` over a scripted fake zfa; the service tier reads
  hand-seeded plan artifacts in the exact shapes `plan_command.dart` /
  `lane_split.dart` render.
- **Honesty checks**: the `--force` test asserts the honest stop is
  BYTE-IDENTICAL (same `stopped_at=U1:make`, same remedy) — the preflight
  never papered over the runtime stop; the DONE-row and hand-completed
  tests pin "evidence beats state" so the gate cannot block legitimate
  resumption.

## Acceptance-criteria coverage

- SC-1 → U-1482-4 (zero spawns, all rows named in one block, exit 1).
- SC-2 → U-1482-5 (--force drives; honest stop byte-identical).
- SC-3 → U-1482-REG1 + the scoped suites above.
- SC-4 → U-1482-3c (lane meta-index) + the service takes the resolved
  `featureDir` (the #1471 pin layout works by construction —
  `TddFeaturePaths.resolveWithPin` output feeds the gate unchanged).
