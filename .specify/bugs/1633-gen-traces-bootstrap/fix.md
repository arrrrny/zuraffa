# Fix — 1633 (plan+gen bootstrap arms the fingerprint)

## Change surface

| File | Change |
|------|--------|
| `test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart` | Full rewrite of the fixture. `setUp` no longer hand-registers behavior A1 with a mangled registry (no `gen_fingerprint`, realigned `subject_path`, hand-written `test-list.md`); B1/B2 now mirror the sibling suite's `seedGuardOnlyPair` shape: write `spec.md` (FR-007 self-traced, `--allow-unit-fallback`) → real `tdd plan` → real `tdd gen U1` — the created record arms the fingerprint (asserted). The traces mutation goes through the DESIGNED hand-delta seam (the vacuous-guard remedy text names it): hand-edit `tdd/test-list.md`'s traces cell `FR-007` → `FR-007, adaptive_layouts`, then re-run gen. The `skip:` annotation is gone. |

## Why this shape (and not a contracts/*.md trace)

The first attempt migrated the routing via a `contracts/*.md` trace file
(`- **FR-007**: traces: adaptive_layouts`) + re-plan. That path REFUSES
by design: the seed spec carries an inline `traces: FR-007` self-trace,
and plan rejects an FR traced from BOTH spec.md and a contracts file
(#1480, `plan_command.dart` — "keep exactly one trace declaration").
The cell-ADD shape (`FR-007` → `FR-007, adaptive_layouts`) therefore
cannot ride the contracts seam without first un-declaring the inline
trace. The hand-delta seam is exactly the surface the original B1
modeled (it hand-wrote the cell), and gen's own vacuous-guard remedy
text names it as designed: "or hand-edit the test list … traces cell …
and re-run zfa tdd gen".

## Note discovered on the way

With the hand-edited cell, the forced re-render's drift note is the
**#1388** wording ("declared routing changed since the owned pair was
generated (traces cell or the spec's Layer Contracts)"), not the #1320
wording the original B1 asserted — `fingerprintDrift` wins the note
ternary even though the render bytes also changed (the group name now
echoes the mutated cell). B1 pins the actual shipped behavior.

## Behavior map

- **B1** — armed record + cell mutation → `verdict=regenerated`, the
  #1388 note, the regenerated test's group carries
  `U1 (FR-007, adaptive_layouts)`, and the stored fingerprint refreshes.
- **B2** — armed record, unchanged routing → `verdict=reused`,
  byte-identical pair, no drift note.
