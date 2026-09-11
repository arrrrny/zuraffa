# Bug #1419: tdd plan lane-split path silently drops spec-derived Layer Contract behaviors

- **Issue**: https://github.com/arrrrny/zuraffa/issues/1419
- **Fetched**: 2026-09-11 (spec-kit bug-fetch, session record)
- **State**: open
- **Labels**: severity high

## Summary (verbatim from the issue)

On a `zuraffa-1.0` spec that declares **both** a `## Layer Contracts` section
(spec 1007) and a `## Lanes` section (spec 1000), `zfa tdd plan` derives the
contract behaviors but never writes them into the lane-split plans. The legacy
(no-Lanes) path renders them (`_render(..., contractBehaviors, ...)`), so the
same spec loses contract behaviors the moment it declares lanes — silently,
exit 0, no refusal, and the FR/AC coverage gate does not complain.

## Repro

1. Author a zuraffa-1.0 spec with a Layer Contracts section, e.g.:

```markdown
## Layer Contracts

**Domain**:
- `MessageTransport`: `send(OutboundMessage) -> Message`, `acknowledge(String) -> bool`
```

2. Add a `## Lanes` section declaring the scenarios and FRs:

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1-A3, U1-U3]
    flutter_allowed: false
```

3. `zfa tdd plan <feature>` → exit 0, writes `04-ENGINE.md` / `04-SKIN.md` /
   `04-CONTRACT.md`.

**Observed**: `04-ENGINE.md` contains only the A/U rows. The 2 derived
contract behaviors (`contract:A1`, `contract:A2`) are gone — no refusal, no
coverage-gate failure, no trace in the verdict.

**Expected**: the derived contract rows land in the engine plan (CORE by
default) exactly as the legacy single-file path renders them — one row per
declared method, description
`MessageTransport.send(OutboundMessage) -> Message (entity method contract)`,
traces `MessageTransport.send`, contract kind/BLOCKED semantics per spec 1007.

## Secondary symptom

Declaring the contract ids in `## Lanes` does not recover them: a bare
`contract:A1` in `behaviors:` is treated as a **hand-declared lane row** — the
plan emits `| contract:A1 | core behavior declared in ## Lanes | LANE:CORE |`,
clobbering the derived description, the `Interface.method` trace, and the
contract kind. The derived contract behaviors and the lane declaration are
never joined.

## Root cause

In `plan_command.dart`, the split path builds rows from `expressible` +
`preservedFfi` + `laneResult.handRows` only; `contractBehaviors` (derived just
above via `_reconcileContractBehaviors(_deriveContractBehaviors(...))`) is
never added to `engineRows`/`skinRows`. The lane-coverage refusal ("every
spec-derived behavior must appear in a behaviors: list") also does not count
contract behaviors, so nothing catches the drop. In the hand-rows branch, ids
already derived as contract behaviors are not consulted, so the declaration
wins with the anonymous description.

## Impact

Silent coverage loss on the lane-split path — the worst failure class for an
honesty-first toolchain: a feature's declared method contracts vanish from the
plan, from gen, and from the verification audit with zero signal. Specs
authored against the latest template (Layer Contracts + Lanes are both
zuraffa-1.0 sections) hit this by the book.

## Environment

- zuraffa 6.2.2; Dart SDK ^3.11.0.
- origin/master `76992d03` shows the same code path (verified in this session).

## Workaround (from the issue, until fixed)

Declare the contract ids in `## Lanes` as annotated hand rows carrying the
derived description in the annotation. Known downgrade: they lose the contract
kind and BLOCKED-state semantics of spec 1007.
