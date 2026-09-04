# Bug Issue: fix: zfa tdd run mis-classifies make=skipped as generation-error (issue #694 skip transition blocks run)

- **Slug**: 986-tdd-run-make-skipped-misclass
- **Fetched**: 2026-09-05
- **Issue**: 986
- **URL**: https://github.com/arrrrny/zuraffa/issues/986
- **State**: open
- **Severity**: high
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd run` reports `outcome=generation-error` for `make` steps even when
`zfa tdd make` itself returns `outcome=skipped` (issue #694 skip transition —
the target test already passes). The driver's parser does not treat `skipped`
as a terminal `make` outcome, so the entire run halts at the first acceptance
behavior even though there is nothing to fix.

## Repro

```bash
cd /Users/ahmettok/Developer/forklift
zfa tdd run 001-forklift-zuraffa-rewrite --timeout 15
```

Output (after fix for #984 — empty separator rows):

```
zfa tdd run: feature 001-forklift-zuraffa-rewrite — 72 behavior(s)
   suite baseline: corpus-wide reuse (fingerprint match; spec 069 T004) — 24 pre-existing failure(s) captured 2026-09-03T22:01:40.732815Z
[run] A1 make -> skipped
[run] A1 refactor -> deferred (phase 2)
[run] A2 make -> generation-error
zfa tdd run: step failed — behavior=A2 step=make outcome=generation-error
run: feature=001-forklift-zuraffa-rewrite result=stopped pending=39 red=32 green=1 done=0 stopped_at=A2:make
```

Direct `zfa tdd make A2 --feature ...`:

```
zfa tdd make: behavior A2
   feature: 001-forklift-zuraffa-rewrite
   test: /Users/ahmettok/Developer/forklift/test/tdd/001-forklift-zuraffa-rewrite/a2_test.dart
   target test already passes — skipping generation (issue #694 skip transition); the suite is not re-run (issue #741)
   green evidence appended to specs/001-forklift-zuraffa-rewrite/tdd/cycle-log.md
make: behavior=A2 outcome=skipped feature=001-forklift-zuraffa-rewrite
```

The target test file:

```bash
dart test test/tdd/001-forklift-zuraffa-rewrite/a2_test.dart
# All tests passed!
```

## Expected

`zfa tdd run` should treat `make` outcome `skipped` as a success path that
advances to `refactor` (or to the next behavior if refactor is also a no-op).
The skip transition (issue #694) is by design — committed tests that already
pass should not block the run. Currently the run halts with
`generation-error`, which is wrong.

## Environment

- zfa v6.1.0 (rebuilt 2026-09-03)
- Spec: 001-forklift-zuraffa-rewrite, 21 acceptance + 8 unit behaviors (A1,
  A2 are pre-existing green)

## Workaround

Run `zfa tdd make <id>` directly per behavior, or skip the run on features
where all tests are pre-existing green and just call `zfa tdd verify` instead.
The run should NOT be a prerequisite for green evidence on already-passing
behaviors.

## Related

- Issue #984 (already filed): empty separator rows abort the parser — fixed
  manually by deleting the bare ` |` line.
- Issue #694: skip transition (intentional — test already passes).
