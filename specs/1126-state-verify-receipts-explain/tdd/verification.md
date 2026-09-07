# TDD Verification: 1126-state-verify-receipts-explain

Environment: Dart SDK 3.13.3 stable. Targeted suites only (disk
discipline) — every suite below owns a file this spec touched. Full
run: 43 tests green across the state surface (26 new + 17 regression).

## Test-first evidence (red before green)

Recorded in tdd/cycle-log.md BEFORE any implementation landed:

| Suite | Red evidence |
|---|---|
| state_provenance_test.dart | compile error: `state_provenance.dart` did not exist |
| state_capability_receipt_test.dart | compile error: `state_receipt.dart` did not exist |
| state_config_schema_test.dart | `Method not found: 'validateStateConfig'` + empty `{}` schema assertions |
| state_explain_test.dart | `--explain` unregistered → usage refusal, no plan block |
| state_verify_gate_test.dart | `Could not find a subcommand named "verify"` |

Every behavior on tdd/test-list.md marked "Red first" went through the
red→green loop; the "gate" rows (spec-976 regressions) were required to
stay green throughout and did.

## Final results (post `dart format .`, zero residual diff)

| Suite | Result |
|---|---|
| test/plugins/state/state_provenance_test.dart | 4/4 pass |
| test/plugins/state/state_capability_receipt_test.dart | 5/5 pass |
| test/plugins/state/state_config_schema_test.dart | 7/7 pass |
| test/plugins/state/state_explain_test.dart | 2/2 pass |
| test/plugins/state/state_verify_gate_test.dart | 8/8 pass |
| state_create_json_receipt_test.dart (spec 976 SC-2a–e) | 5/5 pass |
| state_snapshot_test.dart (goldens, re-baselined once) | 1/1 pass |
| state_make_drift_test.dart (create ≡ make) | 3/3 pass |
| state_output_schema_test.dart | 2/2 pass |
| state_builder_test.dart + state_structural_test.dart | 6/6 pass |
| state_compile_test.dart | 1/1 pass |
| state_property_compile_test.dart (sandbox analyze tier) | 3/3 pass |
| exit_protocol_golden_test.dart | 14/14 pass |
| dead_positional_grammar_test.dart | 11/11 pass |
| exit_code_sweep_1139_test.dart | 15/15 pass |

`dart analyze` on every changed file: **No issues found**.

## Mutation evidence

**Mutation 1 — verifier digest comparison flipped**
(`stateSha == currentSha` → `!=` in `StateVerifier.verify`):

- Initial run: SURVIVED — the clean-path test only asserted exit 0 and
  the absence of fix lines; a flipped comparison silently demoted every
  matched method to stale while still exiting 0. The gate caught a real
  test-strength gap.
- Test strengthened (SC-1126-o now asserts `2 match`, `0 stale`,
  `0 missing` in the prose classification).
- Re-run with mutation: **KILLED**
  (`Expected: contains '2 match'` → red).
- Reverted; suite green again.

**Mutation 2 — unknown-key rejection disabled**
(`if (propRaw is! Map)` → `if (false && …)` in `validateStateConfig`):

- Result: **KILLED** — SC-1126-h (rejects unknown keys) went red.
- Reverted; suite green (7/7).

## Acceptance criteria coverage

| Criterion | Proved by |
|---|---|
| AC-1 verify gate (drift or clean, exit 0/1/2, `--> fix:`, `--json`) | SC-1126-o…v (8 tests, state_verify_gate_test.dart) |
| AC-2 explain block without generating (prose + json envelope skip) | SC-1126-m, SC-1126-n |
| AC-3 `.zfa/receipts/state-<entity>.json` after create (capability + CLI, bindings, latest-wins, dry-run honesty) | SC-1126-a…e (state_capability_receipt_test.dart) |
| AC-4 provenance header on generated state files (both emission branches, deterministic) | state_provenance_test.dart + regenerated goldens |
| AC-5 config schema rejects unknown keys (+ wrong types, empty-schema refusal, capability JSON refusal) | SC-1126-f…l (state_config_schema_test.dart) |
| SC-6 no `--json` regression / timestamped #1138 receipt kept / create ≡ make / goldens | state_create_json_receipt_test.dart + state_make_drift_test.dart + state_snapshot_test.dart |

## Honest gaps / flagged items

- **Provenance header timestamp deviation**: the header carries the
  generator VERSION and a regeneration hint, not a wall-clock
  timestamp — run-varying bytes would permanently break the
  byte-identity gates (snapshot goldens, make-drift). The run timestamp
  lives in the receipt's `at` field. Recorded in spec.md Constraints.
- **Goldens re-baselined once** (the test's own documented procedure
  for intentional emission changes) — they are byte-stable across runs
  after re-baselining (proven by the deterministic-header test).
- **Capability `force`/`dryRun` knobs**: while wiring receipts, the
  capability path was found to ignore `force`/`dryRun` (they live in
  `GeneratorOptions`, not `GeneratorConfig`) — a pre-existing
  "flags that lie" instance (#876 family). Fixed within scope by
  deriving builder options from capability args; SC-1126-c/d/e now
  pin dry-run honesty and force regeneration.
- **Unrelated pre-existing failure** (flagged, not fixed, out of
  scope): `test/commands/capability_receipt_test.dart` →
  `spec 0996 — … observer create Watcher` fails because the observer
  plugin was removed (issue #1149). The same suite's
  `state create Counter` leg passes with this spec's changes.
- **Full suite NOT run** (per cloud-agent disk discipline — the full
  suite compiles a ~6.5 GB kernel cache). Coverage is every suite that
  owns a touched file, per the standing instruction.
