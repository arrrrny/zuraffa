# Test List: 1482-tdd-run-preflight

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1482-1 | RoutingProvenancePreflight.check reads the plan-produced `## Routing provenance` section (test-list.md, following the lane meta-index into 04-ENGINE.md/04-SKIN.md) plus TestListReader rows and returns a finding for a fallback-routed UNIT row: id, description, and the FR-shaped criterion token parsed from the traces cell | FR-001, FR-005 | GREEN |
| U-1482-2 | the offending-row filter is exactly: kind unit AND provenance `[fallback: ...]` AND state not done AND (no generated test OR contentIsVacuousGreen) — acceptance/widget fallback rows, declared unit rows, DONE fallback rows, and fallback rows with a hand-completed non-vacuous test are never offending | FR-001, FR-006 | GREEN |
| U-1482-3 | fail-open boundaries: no/unreadable test list → ok; no provenance section → ok; a `route:` line that is declared or refused → not fallback; the refusal fires for any feature dir the run driver resolves (bug layout included) with zero subprocess spawns (O(1) reads) | FR-005, SC-4 | GREEN |
| U-1482-4 | the run command refuses before the first gen: prints `run: preflight failed — N unit behaviour(s) cannot pass make:`, one `  <id> — <name> (no declared contract trace, fallback to FR-00N)` line per offending row (suffix omitted when no criterion token), the `Suggested:` remedy line, journals preflight_red at gate with one violation per row, prints the all-zero `result=stopped` summary line, exits 1, spawns ZERO steps (fake zfa argv log empty) | FR-002, FR-004, SC-1 | GREEN |
| U-1482-5 | `--force` bypasses ONLY the routing preflight — the run proceeds into the engine lane (scripted fake zfa drives gen/verify-red/make and the honest vacuous-green stop stays byte-identical), while the #1303 dependency-overrides gate keeps refusing on its own condition | FR-003, SC-2 | GREEN |
| U-1482-REG1 | regression guard: existing run/preflight suites pass unchanged — run_command_test.dart, run_engine_command_test.dart, run_skin_command_test.dart, bug_1259_vacuous_green_test.dart (loop semantics untouched) | SC-3 | GREEN |

## Layer contracts

```yaml
# fr: FR-001, FR-005
routing_provenance_preflight.dart: RoutingProvenancePreflight.check reads the plan-produced provenance section + TestListReader rows; O(1) reads; fails open on missing artifacts
# fr: FR-002, FR-003, FR-004
run_command.dart: the routing preflight sits after the #1303 gate; --force bypasses only this gate; the refusal prints the structured block, journals preflight_red, exits 1 with zero steps
```

## Key entities

```yaml
RoutingProvenancePreflight: the gate; parses route: lines; applies the offending-row filter
RoutingProvenancePreflightReport: ok + offending findings (id, description, criterion tokens)
contentIsVacuousGreen: the sole assertion predicate (issue #1259 reuse — no logic duplication)
```

## External dependencies

(none — pure-Dart reads; the driver-tier scenarios use the scripted fake
zfa binary from TddFixture)

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted
— a declared marker/contract row, or the labeled legacy fallback to
migrate.

route: U-1482-1 -> unit lane [declared: contract row routing_provenance_preflight.dart, FR-001/FR-005 trace]
route: U-1482-2 -> unit lane [declared: contract row routing_provenance_preflight.dart, FR-001/FR-006 trace]
route: U-1482-3 -> unit lane [declared: contract row routing_provenance_preflight.dart, FR-005/SC-4 trace]
route: U-1482-4 -> unit lane [declared: contract row run_command.dart, FR-002/FR-004 trace]
route: U-1482-5 -> unit lane [declared: contract row run_command.dart, FR-003/SC-2 trace]
route: U-1482-REG1 -> unit lane [declared: contract row run_command.dart, SC-3 trace]
