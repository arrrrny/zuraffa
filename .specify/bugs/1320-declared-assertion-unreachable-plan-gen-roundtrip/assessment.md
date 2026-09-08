# Bug Assessment — #1320

**Issue:** Declared-assertion path unreachable — plan never writes contract row into unit traces cell; hand-delta destroyed by re-plan; gen refuses to re-generate
**Severity:** critical (capstone bug) — #1308/#1310/#1318/#1319 all feed into this
**Source:** https://github.com/arrrrny/zuraffa/issues/1320

## Root cause — three (four) interlocking gaps

1. **plan never surfaces the bound contract row.** With `traces: RouteContentType`
   on the FR and `- \`RouteContentType\`: \`contentType() -> String\`` declared under
   `## Layer Contracts`, `zfa tdd plan` binds the trace in Routing provenance
   (`route: U1 -> unit lane [declared: contract row: RouteContentType, spec line N]`)
   but writes the unit row's traces cell as bare `FR-001` — BOTH the legacy writer
   and the lane writer (`_derivedLaneRows`) emit `b.sourceCriterion` verbatim;
   `frTraces` is consumed only by provenance. `gen` resolves the contract shape
   from the ROW's traces cell (`DeclaredRouting.declaredSignatureFor`), sees only
   the criterion token, and emits the bare guard → `make` refuses
   `vacuous-green` (#1308 dead-end) even though the spec declares everything correctly.

2. **The only unlock is an undocumented hand-edit.** Writing
   `FR-001, RouteContentType.contentType` BY HAND into `04-ENGINE.md` makes
   `zfa tdd gen U1` emit a real assertion. Nothing names this as the designed
   hand-delta seam.

3. **The hand-delta does not round-trip.** plan's prior-row reader uses
   `RegExp(r'^\|\s*([A|U]\d+)\s*\|.*?\|\s*([A-Z0-9\-, ]+)\s*\|')` — traces cell
   class is UPPERCASE/digit/dash/comma/space only. A method-qualified cell
   (`FR-001, RouteContentType.contentType`) has lowercase + dots, does not match,
   and the next plan run silently reverts the row to bare `FR-001`.

4. **gen refuses to regenerate once artifacts exist.** After fixing the spec,
   `zfa tdd gen U1` reports `verdict=reused` (registry owns the stale guard-only
   pair) — the re-gen remedy does not exist as a command behavior.

## Remediation (hard constraints)

Fix ONLY:
- `plan_command.dart` — both writers (write method-qualified cell
  `FR-001, RouteContentType.contentType` when traces binds to a contract row)
  + prior-row regex (accept `[A-Za-z0-9_,.\- ]+` for method-qualified cells)
- gen reuse/regen logic — re-generate when traces cell gained a contract token
  since the owned artifact was generated (`verdict=regenerated`)
- run-driver stop message — name the hand-delta seam explicitly (until fix #1 lands)

Do NOT change: core engine, verify gate, contract scanner, Lane Contract format.
One PR per bug.

## Repro (from issue)

```
traces: RouteContentType on FR-001, declared contract
RouteContentType: contentType() -> String
→ zfa tdd plan → provenance confirms route: U1 [declared: RouteContentType]
→ traces cell: bare FR-001 (contract name LOST)
→ zfa tdd gen → guard-only test (no real assertion)
→ zfa tdd make → vacuous-green → dead-end
```
