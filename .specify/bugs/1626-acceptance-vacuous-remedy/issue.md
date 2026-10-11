# Bug Issue: acceptance vacuous-green refusal prescribes FR-traces remedy that cannot work — hand step unnamed

- **Slug**: 1626-acceptance-vacuous-remedy
- **Fetched**: 2026-09-14T00:00:00Z
- **Issue**: 1626
- **URL**: https://github.com/arrrrny/zuraffa/issues/1626
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug, tdd, track-tdd-loop

## Body

# bug: the acceptance vacuous-green refusal prescribes the FR-traces remedy, which cannot produce a real acceptance assertion — the author hand step goes unnamed

## Summary

On a fresh CORE spec, the run stops at the **first acceptance behavior** with a `vacuous-green` refusal (the #1488 gate, working as designed) — but the remedy it prints (add `traces:` → re-plan → re-gen) **cannot** make an acceptance test non-vacuous, because the acceptance lane deliberately ignores the contract shape (#1512). Following the printed instructions loops; the path that actually works (hand-write the outcome assertion + implement the scenario runner + `--born-green`) is never named.

## Repro (fresh `zfa tdd run calculator`)

```
[run] A1 verify-red -> certified
[run] A1 make -> vacuous-green
zfa tdd make: behavior "A1" test is VACUOUS-GREEN — its assertion set is only the UnimplementedError guard (issue #1488). …
   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd gen,
       re-run zfa tdd run — or hand-edit the lane plan (specs/calculator/tdd/04-ENGINE.md)
       traces cell to FR-00N, Row.method and re-run zfa tdd gen (the designed hand-delta seam).
run: … result=stopped … stopped_at=A1:make
```

The printed remedy was followed exactly: the lane plan's A1 traces cell was hand-edited to `FR-001, Calculator.add`, then

```
$ zfa tdd gen A1 --feature calculator
gen: behavior=A1 verdict=regenerated kind=acceptance
```

The regenerated test picked up the trace in its group label — and stayed **guard-only**:

```dart
group('A1 (FR-001, Calculator.add)', () {
  …
  // zfa:tdd: acceptance-guard (issue #1512): … the acceptance subject is a
  // parameterless `void` scenario runner and the declared outcome is asserted
  // through the composition lane … not in this test …
  expect(result, isNot(isA<UnimplementedError>()));
```

```
$ zfa tdd make A1 --feature calculator
zfa tdd make: behavior "A1" test is VACUOUS-GREEN … (same remedy)      # exit 1
```

The acceptance lane ignores the contract-derived shape by design (`behavior_test_writer.dart`: "the contract-derived shape rides ONLY the plain-function pair (unit lane)", #1512) — so traces/re-plan/re-gen can never satisfy the #1488 gate for an acceptance row.

## The path that works (measured)

Hand step, mirroring the source's own description ("the author completes the designed hand step (a real outcome assertion) before any green certifies"):

1. implement the scenario runner in the subject (e.g. record the sum: `int? scenarioResult; void subject_a1() { scenarioResult = _add(2, 3); }`);
2. add an assertion **outside the capture** in the test (`expect(subject.scenarioResult, 5);` — one non-guard `expect` flips `contentIsVacuousGreen`);
3. add the attestation header (`// zfa:tdd: A1:hand — hand step completed before first red certification (issue #1411)`);
4. `zfa tdd make A1 --born-green` → certified (7s; A2 6s) — the run then proceeds.

## Suggested fix

Branch the refusal remedy by row kind (the make side already branches its unit-vs-acceptance wording):

- **acceptance rows** → name the hand step: "write an assertion on the observable outcome **outside the capture** in `<test path>` (the guard-only test is the RED surface), implement the scenario runner in `<subject path>`, add the attestation header, then `zfa tdd make <id> --born-green`";
- keep the traces/re-plan/re-gen wording for **unit/fallback-routed** rows where it actually works.

Surfaces: `run_driver_core.dart`'s make-`vacuous-green` arm (~line 2464, currently calling `_vacuousFallbackRemedy`) and `vacuousGuardFallbackRemedyFor` / the make-side refusal at `make_command.dart` step 3c. The acceptance-lane fixture already documents the correct shape (`test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart`, helper `outcomeAssertedAcceptanceTest`) — the runtime message just never adopted it.

## Impact

The first acceptance behavior of any fresh spec stops the run with a remedy that provably cannot work; an author following it spins (re-plan → re-gen → refuse → same message). The real hand step is discoverable only from source comments and test fixtures.

## Comments

None.
