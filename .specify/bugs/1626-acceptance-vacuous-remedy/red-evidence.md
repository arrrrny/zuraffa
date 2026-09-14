# Red evidence — Bug #1626 acceptance vacuous-green refusal names the hand step

Captured 2026-09-14, this session, on `fix/1626-acceptance-vacuous-remedy`
(pre-fix working tree), Dart 3.13.3 (stable) on linux_x64.

## Suite 1 — `test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart` (new)

```
dart test test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart
→ 00:00 +0 -1: Some tests failed.
  Failed to load "test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart":
  Error: Method not found: 'acceptanceVacuousHandStepRemedyFor'.
```

The shared hand-step wording builder does not exist — the vocabulary the
refusals must render has no source (U-1626-w1 RED; U-1626-a1/a2 blocked behind
the same missing symbol).

## Suite 2 — `test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart` (pins re-pointed)

```
dart test --preset=all test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart
→ 00:14 +3 -2: Some tests failed.

Failing tests:
  ... A1: an acceptance test whose only assertion is the UnimplementedError
      guard cannot certify green — even when it passes
  ... A4: the remedy proves out against the artifact `gen` emits ...
```

Both failures are the bug itself: the refusal the make side actually prints is
still the looping traces remedy —

```
--> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa
    tdd gen, re-run zfa tdd run — or hand-edit the test list
    (specs/090-tdd-fixture/tdd/test-list.md) traces cell to FR-00N, Row.method
    and re-run zfa tdd gen (the designed hand-delta seam).
```

— and none of it names the hand step (`OUTSIDE the capture`, the scenario
runner, the attestation header, `--born-green`) or the two file paths. The
pre-fix contract pins that must NOT change passed: A2, A3, U1 (+3).

## Suite 3 — `test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart` (new)

```
dart test --preset=all test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart
→ 00:14 +1 -1: Some tests failed.

Failing tests:
  ... U-1626-d1: an ACCEPTANCE row's stop names the hand step with both paths;
      stopped_at=A1:make preserved
```

The REAL RunDriverCore stop transcript for an acceptance row prints the
fallback traces remedy verbatim (the loop the issue reports) and no hand-step
vocabulary:

```
[run] A1 make -> vacuous-green
zfa tdd run: step failed — behavior=A1 step=make outcome=vacuous-green
   the generated test is GUARD-ONLY [zfa:tdd: guard-only] — the behavior is
   fallback-routed (no traces: to a declared contract row), so gen could not
   derive a real outcome assertion and make refuses it vacuous-green
   (issue #1259, #1308).
   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, ...
run: feature=1626-acceptance-stop result=stopped pending=0 red=1 green=0
     done=0 stopped_at=A1:make
```

The contract-preservation pin passed pre-fix: U-1626-d2 (a UNIT row's stop
keeps the #1483 traces wording) was already GREEN (+1).
