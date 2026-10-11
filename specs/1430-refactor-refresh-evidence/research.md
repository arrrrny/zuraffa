# Research: 1430-refactor-refresh-evidence

## D1 — Fix shape: refresh the certified evidence vs exempt subjects from the passes

**Decision**: Refresh — the refactor command reconciles certified evidence
after its own rewrite; the `format`/`fix` passes keep covering all of
`lib/`.

**Rationale**:
- Exemption (spec FR-006's alternative shape) leaves registry-owned subjects
  permanently unformatted/unfixed — they drift from repo formatting standards
  and the next hand edit re-introduces surprise drift. It also changes pass
  semantics globally (every feature, even ones with no certified subjects).
- Refresh keeps the loop's post-refactor state self-consistent: the re-proof
  the pass already runs is the witness that the new shapes are green, so
  re-binding the certified hash to the post-rewrite shape adds no new trust
  assumptions.
- The issue text names both shapes as acceptable; refresh satisfies every FR
  with a smaller blast radius.

**Alternatives considered**:
- *Exempt `lib/tdd/<feature>/` from `dart format`/`dart fix`*: rejected
  above (stale formatting, global semantics change).
- *Edit the certified green entry's hash in place*: rejected — the cycle log
  is append-only and hash-chained (`- prev-hash:`/`- hash:`); editing
  history breaks the chain and the doctor's evidence verification.
- *Re-run `zfa tdd make` per touched behavior after the pass*: rejected —
  make's full pipeline (gen steps, suite runs) is far heavier than needed
  and re-enters the very skip transition being repaired.

## D2 — What kind does the refreshed evidence carry?

**Decision**: A new `CycleEntryKind.refresh`, one entry per touched
certified behavior, carrying the post-rewrite `subjectHash`.

**Rationale**:
- Precedent #1329 (the `error` kind): "red is CERTIFIED red evidence … and
  an entry must never satisfy it" — by the same token a refresh entry is
  NOT `green`: spec-049 certification contracts key on red+green via
  `CycleEvidence.greenEvidence()`, and an entry make never certified must
  not satisfy them.
- The parser (`parseEntries`) reads `- kind: (\S+)` generically and
  `lastEntryFor(kind:)` takes a plain string, so a new kind needs no parser
  change — only the enum, its label, and the two writers/readers.
- Per-behavior entries (not one pass-wide entry) fit the singular
  `subjectHash` field and let the guard's lookup stay
  `lastEntryFor(<id>, kind: 'refresh')`.

**Alternatives considered**:
- *Reuse kind `green` (a re-certification entry)*: rejected — pollutes the
  certification contract (see above); the #1329 doc comment warns exactly
  against this.
- *Extend the existing `refactor` entry with per-behavior hashes*: rejected
  — refactor entries are feature-level (`<feature>-refactor` behavior id)
  and carry no subjectHash; a map field would extend the evidence schema
  where per-behavior entries need none.

## D3 — The guard's accept rule (make `_subjectDriftRefusal`)

**Decision**: After the existing `currentHash == certified → null` check,
consult `lastEntryFor(record.behaviorId, kind: 'refresh')`. Accept (return
null) only when ALL hold:

1. the last refresh entry carries a non-null `subjectHash` equal to
   `currentHash`;
2. the refresh entry is NEWER than the certified basis entry (ISO-8601
   `at` comparison; unparseable/missing timestamps fail CLOSED — the
   refusal stands);
3. the subject file is readable (it must be — its hash was just computed).

The acceptance prints a one-line provenance note
(`subject drift accepted (issue #1430): … the loop's refactor pass
re-proved green …`) mirroring the #1162 acceptance note style.

**Rationale**: The freshness check keeps the rule airtight for the
re-drive sequencing (green → refresh → newer green → out-of-band edit back
to the refreshed shape must still refuse: the refresh predates the live
green certification). Fail-closed on unparseable timestamps keeps every
today-refusal refusing.

## D4 — The honesty gate: when may the refactor refresh?

**Decision**: The refactor command refreshes a behavior's evidence only
when (a) its pass rewrite changed that behavior's subject file, (b) the
behavior has certified green evidence, (c) the recorded hash differs from
the post-rewrite hash, and (d) the re-proof ran GREEN over a scope that
covers the touched behavior's test. When any certified subject file was
touched, the command forces the FULL re-proof (the existing `--full-reproof`
semantics) instead of a scoped one — the full suite trivially covers every
behavior's test, satisfying (d) without new scope arithmetic.

**Rationale**: FR-002 forbids refreshing past an unproved shape. A scoped
`coveringTestsFor` re-proof could exclude a touched subject's test; widening
per-test is more code for the same guarantee the full suite already gives.
Refactor passes that touch no certified subject keep today's scoped/full
decision untouched (FR-005).

## D5 — Writer seam and lookup plumbing

**Decision**: `refactor_command.dart` already computes per-pass
`filesChanged` (TreeSnapshot diff) and runs the re-proof; the refresh
reconciliation appends after a green re-proof verdict and before/alongside
the existing `RefactorReceiptRefresh` (#1311 receipts reconciliation — the
direct precedent for "the pass reconciles downstream evidence"). Subject
path → behavior mapping reuses the feature's behavior records (the same
`ArtifactRecord.subjectPath` source make uses), so `zfa tdd refactor` run
standalone reconciles identically (spec assumption).

**Rationale**: One writer seam serves both entry points (run driver phase-2b
and standalone command); the receipts-refresh precedent fixes the shape.

## D6 — Dogfooding hazard

The loop this feature fixes is the loop that will build this feature. If a
mid-feature resume strands on the pre-fix behavior, the issue's sanctioned
workaround (`zfa tdd verify-red <id> --re-certify` per drifted behavior) is
the bridge — recorded here so the run driver's operator (this agent) applies
it without treating it as a new misfire.
