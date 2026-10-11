# Test List — Spec 1345 (one behavior per line, traced to the spec's success criteria)

Feature: specs/1345-reset-rerun-acceptance-placeholder-deadlock

- B1: tombstoned acceptance-kind placeholder re-drive adopts via compose
  re-entry — make exits 0, `outcome=adopted-placeholder`, green evidence
  binds the CURRENT subject hash and records the compose step (SC-1).
    traces: SC-1
    state: PENDING
    kind: acceptance
- B2: the re-entry ran the REAL composition pipeline — the composed
  subject on disk references the feature's green unit anchors after the
  make (the placeholder was re-implemented by `zfa tdd compose`, not
  adopted vacuously) (SC-1).
    traces: SC-1
    state: PENDING
    kind: acceptance
- B3: the run driver grades `adopted-placeholder` a terminal make
  success — `zfa tdd run` advances green → refactor → done
  (`result=complete`) (SC-2).
    traces: SC-2
    state: PENDING
    kind: unit
- B4: doctor's `evidence-without-artifact` prescription names the
  placeholder re-entry (`adopted-placeholder`, issue #1345) and stays
  `resume` (SC-3).
    traces: SC-3
    state: PENDING
    kind: unit
- B5: a tombstoned NON-acceptance (unit-kind) placeholder re-drive still
  refuses `subject-drift` (SC-4).
    traces: SC-4
    state: PENDING
    kind: unit
- B6: a born-green placeholder with NO reset tombstone still refuses
  `subject-drift` — the #1036 guard stands outside the re-drive class
  (SC-4).
    traces: SC-4
    state: PENDING
    kind: unit
