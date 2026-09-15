# Bug Issue: blocked-contract stop names the TEST file as the hand surface and suggests `zfa tdd wire … --entity <X>` — which fails when no such entity exists

- **Slug**: 1625-blocked-contract-hand-surface
- **Fetched**: 2026-09-15T11:07:37Z
- **Issue**: 1625
- **URL**: https://github.com/arrrrny/zuraffa/issues/1625
- **State**: open
- **Severity**: unknown (labels: bug, tdd, track-tdd-loop)
- **Author**: arrrrny
- **Labels**: bug, tdd, track-tdd-loop

## Body

# bug: the blocked-contract stop names the TEST file as the hand surface and suggests `zfa tdd wire … --entity <X>` — which fails when no such entity exists

## Summary

With the #1589 fix merged, the blocked-contract stop now names a hand surface — but it names the wrong file, and its suggested command cannot run in a project whose contract row has no entity.

## Repro (fresh `zfa tdd run calculator`, zfa built from `cbb9bed2`)

```
[run] contract:A1 verify-red -> blocked
   the declared contract Calculator.add is not satisfied — the cycle is BLOCKED and cannot proceed to GREEN (issue #1007)
   hand surface: seam test/tdd/calculator/contract_a1_test.dart — implement the declared contract Calculator.add there (e.g. `zfa tdd wire contract:A1 --entity Calculator`)
   parked — the run continues with the remaining behaviors (issue #1544)
…
zfa tdd run: blocked for contract:A1, contract:A2, contract:A3, contract:A4 — the declared contract(s) are not satisfied (issue #1007)
   hand surface: seam test/tdd/calculator/contract_a1_test.dart — implement the declared contract Calculator.add there …
```

Two problems:

1. **The named file is the contract TEST**, not the seam. The test is the generated contract test; the implementation seam it imports and that throws is `lib/tdd/calculator/contract_a1_subject.dart`:

   ```dart
   // lib/tdd/calculator/contract_a1_subject.dart
   int add(int a, int b) =>
       throw UnimplementedError('Calculator.add(int, int) -> int is not implemented');
   ```

   The test's Case-2 assertion goes BLOCKED on exactly that throw. Implementing the declared contract "in the test file" is not the design (and the test is a generated, registry-owned artifact).

2. **The suggested `wire` command fails** in this project — there is no `Calculator` entity:

   ```
   $ zfa tdd wire contract:A1 --entity Calculator --feature calculator
   zfa tdd wire: behavior contract:A1
      feature: calculator
      entity: Calculator
   zfa tdd wire: no generated entity "Calculator" found under …/lib/src/domain/entities.
                 Run `zfa entity create -n Calculator` first (the plan orders the wire step after entity create).
   wire: behavior=contract:A1 outcome=runner-error        # exit 1
   ```

## Root cause

`lib/src/plugins/tdd/services/hand_surface.dart` → `seamPathFor` builds candidate paths **only under `test/tdd/…`** and returns the first that exists:

```dart
final candidates = [
  p.join(projectRoot, 'test', 'tdd', feature, '${snakeId}_test.dart'),
  p.join(projectRoot, 'test', 'tdd', '${snakeId}_test.dart'),
];
```

There is no candidate for the subject (`lib/tdd/<feature>/<id>_subject.dart`) — the file that actually carries the throwing stub for a contract behavior. And `hintLine`'s `wireCommandFor(...)` is synthesized from the contract's declared name (`Calculator`) without checking that any such entity exists, so it emits a command that immediately errors with a different remedy (`zfa entity create`), pointing the operator at yet another path.

## Suggested fix

- `seamPathFor`: prefer the **subject** path for contract behaviors (`lib/tdd/<feature>/<id>_subject.dart`, existence-first, falling back to the current test candidates) — that is the hand surface the make command itself names ("the CONTRACT SEAM … this file is where the declared contract gets its implementation").
- The `wire` hint should be printed only when an entity of that name actually exists (`lib/src/domain/entities/<snake>/`); otherwise print the hand-implement instruction (or the `zfa entity create` prerequisite).

## Workaround used

Implementing the four subject seams by hand (`add`/`subtract`/`multiply`/`divide` — 4 one-liners) made the contract tests pass, and `zfa tdd make contract:<n> --born-green` certified each (16s/13s/14s/13s). That path works and the run then converged to `result=complete` — but nothing at the stop points there.

**Related:** #1589 (the fix that added the hint), #1411 (born-green), #1007 (contract lane).

## Comments

None.
