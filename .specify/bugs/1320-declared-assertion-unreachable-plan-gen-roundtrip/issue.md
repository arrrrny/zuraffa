## Summary
Three interlocking gaps make the #1259 declared-assertion surface (and therefore the fix for the #1308 vacuous-green dead-end) unreachable through zfa commands alone. Verified end-to-end by re-running a real spec (forklift 009-conversation-streaming, 9 FRs + 9 declared Layer Contract rows) through the spec-1000 lane format with zfa v6.2.0 (binary 37c38f25):

1. **plan never surfaces the bound contract row.** With `traces: RouteContentType` on the FR and `- `RouteContentType`: `contentType() -> String`` declared under `## Layer Contracts`, `zfa tdd plan` binds the trace in Routing provenance (`route: U1 -> unit lane [declared: contract row: RouteContentType, spec line 213]`) but writes the unit row's traces cell as bare `FR-001` — both the legacy writer and the lane writer (`_derivedLaneRows`) emit `b.sourceCriterion` verbatim; `frTraces` is consumed only by provenance. `gen` resolves the contract shape from the ROW's traces cell (`DeclaredRouting.declaredSignatureFor`), sees only the criterion token, and emits the bare guard → `make` refuses `vacuous-green` → the #1308 dead-end, *even though the spec declares everything correctly*.

2. **The only unlock is an undocumented hand-edit.** Writing `FR-001, RouteContentType.contentType` BY HAND into `04-ENGINE.md` makes `zfa tdd gen U1` emit `expect(result, isA<String>())` immediately (verified). Nothing in the run-driver stop message, the plan output, or the docs names this as the designed hand-delta seam — #1308 suggested-fix #3 calls it 'the designed hand-delta seam' but no command surfaces it. (The todo_planner green run's enriched traces cells were hand-edits for the same reason.)

3. **The hand-delta does not round-trip.** `zfa tdd plan`'s prior-row reader uses `RegExp(r'^\|\s*([A|U]\d+)\s*\|.*?\|\s*([A-Z0-9\-, ]+)\s*\|')` — the traces cell class is UPPERCASE/digit/dash/comma/space only. A method-qualified cell (`FR-001, RouteContentType.contentType`) contains lowercase and dots, does not match, and the next plan run silently reverts the row to bare `FR-001`, re-locking the dead-end. So the author must re-hand-edit after every plan.

4. **gen refuses to regenerate once artifacts exist.** After fixing the spec, `zfa tdd gen U1` reports `verdict=reused` (registry owns the stale guard-only pair) — the '#1308 remedy: re-gen' step does not exist as a command. Only `zfa tdd reset` (drops the whole feature's artifacts and evidence) or the hand-edit path moves forward.

## Suggested fix
- `plan` (both writers): when an FR's `traces:` binds to a contract row, write the method-qualified cell (`FR-001, RouteContentType.contentType`) into the unit row — single-method rows resolve directly; multi-method rows resolve by FR-prose verb match or refuse with the exact `--> fix:`.
- Prior-row regex: accept `[A-Za-z0-9_,.\- ]+` (or tokenize with the shared `traceTokens`) so method-qualified cells round-trip.
- `gen`: when the row's traces cell gained a contract token since the owned artifact was generated, REGENERATE the test (verdict=regenerated) instead of `reused` — or add `zfa tdd gen --force`.
- run-driver stop message for `vacuous-green` should name the seam: 'hand-edit 04-ENGINE.md traces cell to FR-00N, Row.method, then re-run' (until fix #1 lands).

## Environment
zfa v6.2.0, macOS, pure-Dart package, spec with `## Lanes` (all CORE). Found alongside #1318 and #1319 in the same re-run.
