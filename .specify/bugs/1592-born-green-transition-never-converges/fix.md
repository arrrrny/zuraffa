# Bug Fix: born-green transition never converges — the green-evidence guard extends to blocked state

- **Slug**: 1592-born-green-transition-never-converges
- **Fixed**: 2026-09-13
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/verification.md

## Summary

The run driver's `_stepsFor` green-evidence guard (issue #1324) fired only
when the computed window started at `gen` (`start == 0`), but the #1007
BLOCKED contract arm re-enters at index 1 (`verify-red`). A
born-green-certified blocked behavior therefore re-drove
`verify-red → make` on every run: verify-red unexpected-greens the
already-passing test, the flagless make refuses `not-certified-red` (no
certified red can exist for the lane — BLOCKED-never-RED, issue #1007 — or
for the born-green class — green-WITHOUT-red, issue #1411), and the #1411
stop arm re-prescribes the `--born-green` command that already ran. The
guard's scope now includes the blocked state for the born-green-CERTIFIED
class (the behavior whose LAST green entry carries the #1411 journal
marker): such a behavior re-enters at the phase-2 refactor window, where
the #1542 evidence check already accepts the green-only born-green
certification. The run converges to `result=complete` without manual
re-entry, and the next run re-enters at refactor only.

"Converges" here means the run stops stopping: a born-green behavior has
green but no red, so `_reconcile`'s #682 rule maps the post-refactor `done`
back to `green` — the class never reaches a terminal `done`, and every
future `zfa tdd run` re-executes refactor for it. That is the steady state
the pre-existing `green` class already has (pinned by U-1542-4), and the
endless re-entry is safe while refactor stays idempotent.

Review #1608 (CodeRabbit): the certification must BIND the current subject
to take the window — the certifying entry's `- subject-hash:` (a 64-hex
sha256) must equal the registered subject file's current sha256. A
hashless or mismatched certification keeps the pre-#1592 window: the run
re-drives the honest ladder and the #1411 arm re-prescribes
`--born-green`, whose re-run re-certifies against the current subject.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | modified | `_stepsFor` gains the `bornGreenCertified` input and the guard's scope extends: `start == 0 \|\| (state == blocked && bornGreenCertified)`; the caller computes the born-green-certified id set once (`_bornGreenCertifiedBehaviors`, on the `bornGreenCertifiedEntries` batch) and requires the certification to BIND the current subject (review #1608: the entry's `- subject-hash:` must equal the registered subject file's sha256; hashless or mismatched entries refuse the short-cut) |
| `lib/src/plugins/tdd/services/cycle_evidence.dart` | modified | `bornGreenCertifiedEntries()` (review #1608): the batch form of `bornGreenCertified` — one append-order pass, the last-green + anchored-marker rule kept in one home, with the per-behavior probe delegating to it |
| `test/plugins/tdd/commands/bug_1592_born_green_blocked_convergence_test.dart` | added (merged suite) | U-1592-1..5 — the convergence proof + the regression guards (reconciles the earlier B-draft suites on this branch; see Deviations) — plus U-1592-6/7 (review #1608: the hashless and the edited-subject certifications refuse the short-cut) |

## Diff Highlights

```dart
// run_driver_core.dart — _stepsFor
if (hasGreenEvidence &&
    greenTestBacked &&
    (start == 0 ||
        (state == BehaviorState.blocked && bornGreenCertified))) {
  start = state == BehaviorState.pending ? 2 : 3;
}
```

For a blocked claim the guard now fires ONLY for the born-green-certified
class (`bornGreenCertified`), and the window lands at `refactor` (index 3)
— the same landing a green/mocked claim gets — never at `make` (index 2):
the flagless make the driver spawns has no certified red to pass the
precondition gate, so a make-resume would re-stop at `not-certified-red`
forever.

Review #1608 adds the binding behind that flag: `_bornGreenCertifiedBehaviors`
builds the set from `CycleEvidence.bornGreenCertifiedEntries()` and keeps
only the certifications whose recorded `- subject-hash:` equals the
registered subject file's current sha256 — a hashless or stale
certification never reaches the flag, so the short-cut cannot complete on
a subject the certification never exercised.

## Tests Added or Updated

- `.../bug_1592_born_green_blocked_convergence_test.dart::U-1592-1` — the
  loop: born-green-certified blocked contract converges through refactor
  ONLY; the NEXT run re-enters at refactor only (the #1542 steady state).
- `::U-1592-2` — normal blocked resume (no green evidence) keeps the
  verify-red re-entry; the #1007 verdict parks with `result=blocked`.
- `::U-1592-3` — green evidence without its certified test file on disk
  (unbacked) keeps the exact pre-#1324 windows.
- `::U-1592-4` (ported from the earlier B3 draft) — normal blocked resume
  whose re-drive certifies red-first completes the full ladder.
- `::U-1592-5` (ported from the earlier B4 draft) — unbacked green evidence
  against a drifting subject keeps the #1324 stale-artifacts stop and
  prescription byte-for-byte.
- `::U-1592-6` (review #1608) — a hashless born-green certification does
  not take the refactor short-cut: the pre-#1592 window stands and the
  #1411 arm re-prescribes the re-certification command.
- `::U-1592-7` (review #1608) — a certification whose subject was edited
  after `make --born-green` (the recorded hash no longer binds) refuses
  the short-cut the same way.
- `::U-1592-1` (review #1608) — the fixture now writes the subject and
  seeds the transition's real `- subject-hash:` shape, so the convergence
  proof exercises the subject binding.

## Local Verification

- Commands run (all real, outputs captured in ./tdd/verification.md):
  `dart test --preset=all <merged suite + pinned born-green suites>` → 24/24
  pass; chunked fast-suite blast radius (`test/plugins/tdd/**`,
  `test/commands`) → 1180 pass / 0 fail; pre/post `make_command_test.dart`
  failure-set diff → byte-identical (no new failures); `dart analyze` (changed
  files + tdd subtree) → no issues; `dart format --set-exit-if-changed
  lib/ test/` → 0 changed.
- Manual checks: a real-CLI end-to-end A/B on a real temp project (no fake):
  PRE-FIX the driver stops at `contract:A1:hand` prescribing the already-run
  `--born-green`; POST-FIX it drives the REAL refactor child (build / format
  / fix passes + real `dart test` preflight and re-proof) to
  `result=complete`.

## Deviations from Assessment

- The assessment's remediation option 1 wording ("born-green-certified
  blocked behaviors resume at `make`") cannot converge: the flagless make
  the driver spawns refuses `not-certified-red` before any skip transition
  (the certified-red gate, `make_command.dart` step 2; contract-lane reds
  are BLOCKED-never-RED per #1007 and born-green certifications are
  green-WITHOUT-red per #1411). The fix implements the window that actually
  converges — refactor, where the #1542 evidence check accepts the
  green-only born-green certification — and keys the blocked extension on
  the born-green CERTIFICATION (the #1411 journal marker), which option 2's
  "recognize `kind: green` evidence" pointed at. Marker-less blocked shapes
  keep their pinned windows (U-1542-1 stays green; an earlier draft guard
  that resumed ALL backed-green blocked claims at make broke that pinned
  contract and was reconciled away).
- The assessment's option 2 ("advance directly in the phase-1 blocked arm")
  was not used: the hard constraint scopes the fix to the green-evidence
  guard in `_stepsFor`, and the guard (not the loop arm) is where the #1324
  window logic already lives.

## Follow-ups

- `zfa tdd doctor` could surface the born-green-certified blocked shape in
  its drift report (the operator currently discovers it only through the
  run stop).
- The `make_command_test.dart` real-pipeline suites (U-829g/h, A11/U17,
  A15) fail identically before and after this fix in a cold,
  Flutter-less environment; they pass in the maintainer's environment and
  are unrelated to this change (failure lists diffed byte-identical).
