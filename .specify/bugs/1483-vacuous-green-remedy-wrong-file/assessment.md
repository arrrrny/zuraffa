# Bug Assessment: `zfa tdd run` vacuous-green remedy names a nonexistent file for legacy single-file features

- **Slug**: 1483-vacuous-green-remedy-wrong-file
- **Created**: 2026-09-10
- **Source**: https://github.com/arrrrny/zuraffa/issues/1483
- **Verdict**: valid, reproduced at the driver level
- **Severity**: low (messaging-only, but it dead-ends the designed hand-delta seam for every non-laned feature)

## Report

The vacuous-green make stop (`stopped_at=<id>:make`, the issue #1308
fallback arm) prescribes `hand-edit the lane plan (04-ENGINE.md) traces
cell …` unconditionally. For a legacy single-file feature — a spec with no
`## Lanes` section, the shape `zfa tdd plan` produces when no lane split is
declared — the lane plan pair (`04-ENGINE.md` / `04-SKIN.md`) does not
exist and never will. The real seam is the traces cell of the feature's
`tdd/test-list.md`.

## Symptom

`zfa tdd run <feature>` stops honest (`result=stopped …
stopped_at=<id>:make`) but the `--> fix:` line sends the author to a
nonexistent file. Following the advice dead-ends: there is nothing to edit
at the named path, while the actual one-cell fix sits in the artifact the
same message told the author to re-plan.

## Reproduction (driver-level, in this repo's test harness)

Reproduced with the real `RunDriverCore` over the scripted fake zfa binary
(`test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart`,
U-1483-2, RED evidence): a legacy single-file feature (plain 4-column
`test-list.md`, no `tdd/04-ENGINE.md` on disk) driven into a vacuous-green
make stop prints exactly:

```
   the generated test is GUARD-ONLY [zfa:tdd: guard-only] — the behavior is fallback-routed ...
   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd gen, re-run zfa tdd run — or hand-edit the lane plan (04-ENGINE.md) traces cell to FR-00N, Row.method and re-run zfa tdd gen (the designed hand-delta seam)
run: feature=1483-single-file-seam result=stopped pending=0 red=1 green=0 done=0 stopped_at=U1:make
```

`04-ENGINE.md` does not exist in that feature's `tdd/` directory — the
prescribed seam is fictional.

## Root cause (confirmed against the tree)

1. Issue #1320 extended the issue #1308 remedy with the hand-delta seam and
   baked it into ONE shared constant,
   `vacuousGuardFallbackRemedy`
   (`lib/src/plugins/tdd/services/vacuous_guard.dart`) — from the
   lane-split perspective, with the lane plan named as a BARE filename.
2. The run driver's fallback vacuous-green arm prints it verbatim
   (`run_driver_core.dart`, the `step == 'make' && result.outcome ==
   'vacuous-green'` arm, the marker-absent branch): no feature-shape
   branch exists anywhere between the test list read and the stop.
3. The same constant is also printed by the gen-time writer warning
   (`behavior_test_writer.dart`) and matched by the run transcript
   forwarding scan (`_forwardGuardOnlyWarning`) — all consumers of the
   single shared wording.
4. The lane-split shape's OWN remedy is correct — a lane-split feature
   really does carry `tdd/04-ENGINE.md` — but a legacy single-file feature
   resolves its rows (and their traces cells) straight from
   `tdd/test-list.md` (`TestListReader.read`, the non-meta-index path), so
   for that shape the test list IS the hand-delta seam.

## Proposed remediation

Messaging-only, per the issue's hard constraints:

- Keep `vacuousGuardFallbackRemedy` byte-identical (the writer, the
  forwarding scan and the #1320 suite pin it).
- Add `vacuousGuardFallbackRemedyFor({lanePlanPath, testListPath})` in
  `vacuous_guard.dart`: same wording family, but the seam noun + path
  branch — `lane plan (<full path>)` when the lane plan pair is on disk,
  `test list (<full path>)` when it is not.
- In the run driver's fallback arm, detect the seam from disk (`tdd/04-ENGINE.md`,
  else `tdd/04-SKIN.md`, else the test list) and print the branched remedy
  with paths relative to the project root (full path, feature dir
  included).

## Risks & considerations

- Detection, stop result, `stopped_at=<id>:make` machine contract, journal
  semantics and loop behaviour stay untouched — the change is the string
  the driver prints.
- The gen-time writer warning (a different surface, out of the issue's
  scoped locations) keeps the shared constant; its lines are forwarded
  into the run transcript by the existing scan, which still matches.
- A stale `split-receipt.json` without plan files is intentionally NOT
  treated as lane-split: with no plan pair, `TestListReader` resolves rows
  from the test list itself, so the test list is the real seam.
