# Test List: 1432-platform-lane-skin-plan

Derived from spec.md + plan.md (speckit.tdd.plan fallback — the repo has no
`.zfa.json`, so the LLM-guided derivation applies). Every behavior gets a
failing test BEFORE its implementation lands (red-green-refactor).

## Outer loop: acceptance behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A-1432-1 | a zuraffa-1.0 spec whose SKIN lane declares acceptance- and platform-typed acceptance scenarios plans exit 0 with the platform row rendered in `04-SKIN.md`'s outer-loop table with the same columns as the acceptance rows | FR-001, FR-002 | PENDING |
| A-1432-2 | for every `route: <id> -> <lane>` line the plan prints, the named lane plan carries `<id>` as a row — zero routed-but-absent ids | FR-001 | PENDING |
| A-1432-3 | a routed behavior kind no lane section renders refuses exit 2 naming id/kind/criterion with the `--> fix:` remedy and writes NO lane artifacts | FR-003 | PENDING |
| A-1432-4 | each lane's rendered declared count equals its artifact's behavior data-row count and the platform row is counted | FR-004 | PENDING |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1432-1 | `renderSkinPlan` places a platform-kind `LaneRow` in the `## Outer loop: acceptance behaviors` section with the canonical 4-column shape | FR-002 | PENDING |
| U-1432-2 | `renderEnginePlan` places a platform-kind `LaneRow` in the acceptance section (the BOTH-lane engine copy) with the canonical 4-column shape | FR-002 | PENDING |
| U-1432-3 | the split refusal guard refuses a theme-kind row (today's reachable no-home kind) with the marker remedy and EXCLUDES contract-kind rows (open #1419) | FR-003 | PENDING |
| U-1432-4 | regression guard: plans without platform rows render acceptance/widget/unit/ffi sections byte-shape-identical to the pre-fix tree (single-file path untouched) | FR-005 | PENDING |

## Layer contracts

```yaml
# fr: FR-001, FR-002
lane_split.dart: renderSkinPlan, renderEnginePlan (acceptance section filters)
# fr: FR-003
plan_command.dart: split refusal loop (kind-without-home guard)
```

## Key entities

```yaml
LaneRow: the rendered unit (kind axis of the defect)
BehaviorKind: acceptance, unit, widget, theme, ffi, platform, contract
```
