# Bug Issue: scalar vacuous-green refusal prints the void/entity explanation (#1651 shape misdescribed by the #1308 template)

- **Slug**: 1677-scalar-vacuous-green-message
- **Fetched**: 2026-09-18
- **Issue**: 1677
- **URL**: https://github.com/arrrrny/zuraffa/issues/1677
- **State**: open
- **Severity**: medium
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

### Summary

The #1651 vacuous-green refusal for a **scalar** contract-row unit behavior
(e.g. `add(int a, int b) -> int`) prints the **void/entity** branch's
explanation. The middle paragraph of the `zfa tdd run` stop is the #1308
hand-delta-seam template; for scalar contracts the correct explanation is
the #1651 one (the scalar-type-only `isA<int>()` assertion is satisfiable
by a `return 0;` dummy). Both paragraphs contradict each other on the same
screen — the make refusal excerpt above says the subject is a scalar dummy
whose test is type-only (issue #1651 wording), while the run driver's
paragraph below claims the return is void/an entity and the assertion set
is the UnimplementedError guard only.

### Observed output

```
zfa tdd run: step failed — behavior=U1 step=make outcome=vacuous-green
...
   the traced contract's return is void/an entity — the zfa:tdd: vacuous-guard marker IS the designed hand-delta seam (issue #1308): the assertion set is the UnimplementedError guard only, which make refuses vacuous-green (issue #1259).
```

U1's declared contract is `add(int a, int b) -> int` — not void, not an
entity. The #1651 writer comment in the generated test on the same screen
says the opposite of the driver's paragraph: "the assertion below checks
the declared return TYPE only — a func-scaffolded dummy (`return 0;`)
satisfies it".

### Root cause

The #1651 vacuous-green refusal for a scalar contract-row unit behavior
prints the void/entity branch's explanation. The run driver's make
vacuous-green marker-present arm keys only on the
`zfa:tdd: vacuous-guard` marker; since #1651 the scalar type-only shape's
generated test ALSO carries that marker, so the arm fires and prints the
#1308 void/entity template regardless of the contract shape. The writer's
emission already discriminates the branch (`_declaredAssertion`'s scalar
branch emits the marker WITH the typed type-only assertion); the refusal
message does not use the same discriminator.

### Expected behavior

Emit the scalar-branch explanation for scalar-declared contracts:

> the traced contract's return is scalar (`int`) — the `zfa:tdd:
> vacuous-guard` marker's assertion set checks the declared return TYPE
> only; a func-scaffolded dummy (`return 0;`) satisfies it (issue #1651)

The #1308 explanation is kept for void/entity contracts. The `--> fix:`
and `hand step:` lines are unchanged, as are the #1651 gate semantics and
the #1308 hand-delta-seam handling (`stopped_at=<id>:hand`).

### Environment

- zuraffa `master` a9329746 (2026-09-18)
- Dart SDK 3.13.4
