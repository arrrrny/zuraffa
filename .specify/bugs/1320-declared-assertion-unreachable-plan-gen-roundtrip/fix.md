# Bug Fix — #1320 (declared-assertion path reachable end-to-end)

## Root cause

Four interlocking gaps kept the spec + Layer Contracts → declared unit
assertion path unreachable through zfa commands alone:

1. plan surfaced the bound contract ROW in the traces cell (post-#1310)
   but never the bound METHOD — `traces: RouteContentType` kept the cell
   row-only, so a multi-method row's declared signature stayed ambiguous
   (gen's resolver fell back to the row's first declared signature — the
   #920 wrong-signature class — and the method-qualified shape the
   declared-signature path documents was unreachable without a hand-edit).
2. The hand-delta unlock (hand-editing the traces cell to
   `FR-00N, Row.method`) was named nowhere.
3. The old prior-row reader's uppercase-only traces-cell class silently
   reverted method-qualified cells on re-plan (obsolete at HEAD — the
   positional cell read replaces it — but the round-trip guarantee still
   needed pinning by test).
4. gen reused the stale guard-only pair once artifacts existed
   (`verdict=reused`) even when the traces cell had since gained a
   contract token — the re-gen remedy had no command surfacing.

## Changes

- `plan_command.dart` (`_qualifiedTraces` + refusal): the shared
  `contractTraces` map now carries method-qualified tokens before either
  writer renders the cell. Single-method rows resolve directly;
  multi-method rows resolve by FR-prose verb match; ambiguity refuses
  (exit 2, `--> fix:` names the exact `traces: Row.<method>` remedy and
  the hand-edit alternative, zero artifacts).
- `gen_command.dart` (`_regenerateStaleStub` cause + verdict): when the
  traces cell gained a contract token since the owned artifact was
  generated (declared shape resolves + owned test still vacuous-green),
  the pair is rewritten and reported `verdict=regenerated` with an
  honest note; binary drift keeps the #683 note and `reused` semantics.
- `vacuous_guard.dart` (`vacuousGuardFallbackRemedy`): the shared remedy
  names the designed hand-delta seam — hand-edit the lane plan traces
  cell to `FR-00N, Row.method`, re-run gen.

## Round-trip

The cell is now DERIVED deterministically from the spec
(`FR-001, RouteContentType.contentType`), so re-plan reproduces it —
the hand-delta survives; where plan cannot derive it, plan REFUSES
instead of silently reverting.

## Evidence

See `tdd/verification.md` in this directory (red 0+/8-, green 8/8,
regression chunks +399/+773/+449/+81, focused re-runs +39/+37, analyze
clean, format clean).
