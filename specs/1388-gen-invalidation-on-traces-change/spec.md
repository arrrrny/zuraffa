**Template Version**: `zuraffa-1.0`

# Spec: 1388-gen-invalidation-on-traces-change

GitHub issue: arrrrny/zuraffa#1388 (verify-misfire, EPIC #1012 Phase A,
follow-up of #1377 / #1259 / #1308 / #1320 / #1309)

## Summary

`zfa tdd gen` reuses stale guard-only artifacts even after a `traces:`
migration. The guard-only stop (#1259/#1308) prescribes the recovery
loop `add traces → re-run plan → re-run gen → re-run run`, but the
gen half of that loop is a no-op: the registry reuse decision
(`ArtifactRegistry.preflight`) reuses a prior record purely on
behavior-id + path + file-existence, and the #1320 staleness re-render
only rewrites the pair when the CURRENT render differs byte-wise from
the owned pair — which happens only when a declared SIGNATURE now
resolves and changes the rendered assertion. A declared-routing change
that does not alter the rendered bytes (the exact #1377/#1388 shape:
U1's traces cell gained `adaptive_layouts`, a layout-surface
Presentation row with no signature) leaves the bytes identical, gen
reports `verdict=reused`, the stale guard-only pair survives, and the
prescribed remedy dead-ends through the front door. The same hole
covers progressed pairs: a subject that left the stub stage exits the
#1320 staleness path early (never clobber real work), so gen silently
reuses a pair that predates the routing change. The only working
escapes (`zfa tdd reset <feature>`, hand-delete + `--adopt`) are
undocumented in gen's output.

## Locked decisions

1. Gen's reuse decision gains a FINGERPRINT: sha256 over the resolved
   lane-plan traces cell (the row `TestListReader` resolves for the
   behavior — `04-ENGINE.md`/`04-SKIN.md` when the list is a lane
   meta-index, else `tdd/test-list.md`) plus the feature's `spec.md`
   content. Persisted per record as `gen_fingerprint`.
2. Fingerprint drift on a reused pair is invalidated through the front
   door: gen regenerates the pair (`verdict=regenerated`) when the pair
   is still at the stub stage, and refreshes the stored fingerprint so
   the drift fires once per routing change.
3. When regeneration is declined by the existing machinery (progressed
   subject past the stub stage, ffi harness never auto-regenerated),
   gen refuses reuse with exit 1 and an actionable
   `--> fix: zfa tdd reset <feature>` naming the actual escape hatch.
4. Records generated before this change carry no fingerprint: the gate
   stays open for them (reuse preserved — no mass invalidation of
   shipped registries). The fingerprint arms on the next
   created/regenerated record.
5. SCOPE HARD CONSTRAINT: only the gen REUSE decision changes. The
   writers (generation logic), plan routing, and the run state machine
   are untouched.

## Functional requirements

- **FR-1**: every gen-created or gen-regenerated record persists
  `gen_fingerprint` = sha256(version ‖ traces cell ‖ spec.md content).
- **FR-2**: a reused pair whose stored fingerprint differs from the
  current one is NOT reported `reused`: it is regenerated (stub-stage
  pair) or reuse is refused (progressed/ffi pair).
- **FR-3**: the refusal path prints `--> fix: zfa tdd reset <feature>`
  — the escape hatch named with the feature reference.
- **FR-4**: genuinely unchanged routing keeps `verdict=reused`
  byte-identical reuse (FR-006 idempotency preserved).
- **FR-5**: legacy records without `gen_fingerprint` keep reusing.

## Acceptance scenarios

1. **Given** a guard-only pair generated untraced **When** the spec
   gains `traces:` bound to a SIGNATURE row and plan re-runs **Then**
   gen regenerates (`verdict=regenerated`) and the test carries the
   declared outcome assertion — no guard-only marker, no guard-only
   warning.
2. **Given** a guard-only pair generated untraced **When** the spec
   gains `traces:` bound to a NO-SIGNATURE row (the #1388 shape) and
   plan re-runs **Then** gen regenerates (`verdict=regenerated`) even
   though the rendered bytes are identical, and a following gen
   (unchanged routing) is `reused` again.
3. **Given** a fingerprint-drifted pair whose subject progressed past
   the stub **When** gen runs **Then** exit 1, verdict refused, and
   the output names `--> fix: zfa tdd reset <feature>`.
4. **Given** a pair regenerated after drift **When** gen runs again
   with no further routing change **Then** `verdict=reused` (the drift
   fires once per change).
5. **Given** two consecutive gens with zero routing change **When**
   the second gen runs **Then** `verdict=reused` and the pair is
   byte-identical.

## Success criteria

- **SC-001**: the issue's exact recovery loop
  (guard-only gen → add traces → plan → gen) no longer reports
  `verdict=reused` for the stale guard-only pair.
- **SC-002**: `dart analyze` introduces no new warnings;
  the full gen/registry test suites stay green.

## Assumptions

- The spec hash covers `spec.md` only (the file the #1388 migration
  edits and the primary declared-row source); `contracts/*.md`
  (#1485) edits ride the traces cell when plan re-renders it.
- The #1320 binary-drift staleness path keeps its semantics
  byte-for-byte; the fingerprint gate composes with it (drift forces
  the re-render, equality no longer short-circuits a drifted pair).
