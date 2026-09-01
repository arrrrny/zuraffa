# Data Model: `zfa tdd compose` — phase-2 acceptance make composition

Feature: 052-acceptance-make-composition | Date: 2026-09-01 | Spec: [spec.md](./spec.md)

## New entities

### `ComposableUnitSubject` (discovery result)

One anchor a composition may wire against. Produced by
`composition_targets.dart`; consumed by `CompositionPlanner` and
`ComposeCommand`.

| Field         | Type     | Source                                            |
| ------------- | -------- | ------------------------------------------------- |
| `behaviorId`  | `String` | unit-kind `TestListReader` row id                 |
| `subjectPath` | `String` | registry record's `subject_path` (absolute-normalized against the project root) |

Invariants:

- The row's kind is `BehaviorKind.unit` (test list is the kind source of truth).
- The behavior id carries green evidence in the feature's cycle log
  (`CycleEvidence.greenEvidence()`).
- The subject file exists on disk at discovery time; a recorded-but-missing
  subject is a discovery failure (misfire), never a dropped anchor
  (US2.AC4).
- The anchor behavior is not the compose target itself (an acceptance
  behavior never anchors against its own subject).

### `CompositionPlan` (fallback plan)

The make command's fallback plan for an unexpressible acceptance behavior.
Reuses the existing `GenerationPlan` / `GenerationStepSpec` shapes — no new
plan type, so `PipelineRunner` consumes it unchanged.

| Field    | Value                                                                    |
| -------- | ------------------------------------------------------------------------ |
| steps    | `[{args: ['tdd', 'compose', '<id>'], purpose: 'compose subject of <id> against N green unit subject(s)'}, {args: ['build'], purpose: 'build composed code for behavior <id>'}]` |
| terminal | always a `build` step (047 FR-005 rule)                                  |

Invariants:

- Produced only when: the primary planner refused (unexpressible) AND the
  behavior's test-list row is acceptance-kind AND discovery found ≥ 1
  anchor. Otherwise no fallback plan exists at all (fail-closed to today's
  unexpressible outcome — FR-009).
- Pure: the fallback planner takes the behavior summary + the discovered
  anchor list and returns a plan; it never reads files or spawns processes
  (the planner-purity rule, applied to the new service — FR-008).

### `ComposeOutcome` (machine labels)

The compose command's summary-line labels (`compose: behavior=<id>
outcome=<label> feature=<f>`):

| Label               | Exit | Meaning                                                            |
| ------------------- | ---- | ------------------------------------------------------------------ |
| `composed`          | 0    | Subject stub replaced with the composed implementation             |
| `already-composed`  | 0    | Subject carries no `UnimplementedError` — idempotent re-run        |
| `not-certified-red` | 1    | No red evidence for the behavior in the cycle log (FR-002)         |
| `no-green-units`    | 1    | Discovery found zero composable anchors (FR-003)                   |
| `runner-error`      | 1    | Resolution failure / missing artifacts / unrecognized stub shape   |

Exit code 0 means exactly "composed (or already composed)" — the contract
the fallback plan's step and any resumed run consume.

## Existing entities consumed (unchanged)

- `GenerationPlan` / `GenerationStepSpec` / `GenerationStep`
  (`generation_plan.dart`) — the fallback plan's type and the executed-step
  audit records; `make_command.dart` already records executed steps into
  green evidence.
- `BehaviorSummary` (`generation_planner.dart`) — the summary the fallback
  planner receives; extended nowhere.
- `BehaviorRow` / `BehaviorKind` (`models/behavior.dart`, parsed by
  `TestListReader`) — kind source of truth; read, never written.
- `CycleEvidence` (`services/cycle_evidence.dart`) — green-evidence set;
  read, never written by composition (green entries are make's job).
- `ArtifactRecord` (`models/artifact_record.dart`) — registry record
  (`subject_path`, `runnableTestName`); read, never written.
- `MakeOutcome` — unchanged labels; the fallback changes WHICH outcome a
  phase-2 acceptance make reaches (`unexpressible` → `green`), not the
  label set.

## File contracts touched

| File                                    | Readers/Writers                        | Change                          |
| --------------------------------------- | -------------------------------------- | ------------------------------- |
| `specs/<f>/tdd/test-list.md`            | read by discovery                      | none                            |
| `specs/<f>/tdd/cycle-log.md`            | read by discovery; written by make only | none                           |
| `specs/<f>/tdd/artifacts.json`          | read by compose/make                   | none                            |
| `lib/<snake>_subject.dart` (target)     | written by compose                     | stub → composed implementation  |
| `lib/<snake>_subject.dart` (anchors)    | read (existence + import path)         | none                            |
| paired test files                       | nobody                                 | never touched (044 ownership)   |
| `tdd/run-state.json`                    | nobody                                 | never read by make/compose      |

## Composed subject file shape

```dart
// GENERATED IMPLEMENTATION — `zfa tdd compose <id>` (issue #642; spec 052:
// the acceptance subject is composed against the feature's green unit
// subjects by a generation-pipeline step, never by hand).
//
// behavior_id: <id>
// source_criterion: <criterion>
// composed against: <anchor behavior ids + subject paths>
// description: <description>
library;

import '<anchor subject package import 1>';
import '<anchor subject package import 2>';

/// Subject for behavior <id>, composed against the feature's green unit
/// subjects by the generation pipeline.
<int|void> <functionName>() {
  // Composition anchor: references the feature's green unit subjects this
  // behavior builds on.
  // ignore: unused_local_variable
  final List<Type> composedUnitAnchors = [<Anchor1>, <Anchor2>];
  return 0; // int subjects only
}
```

The stub signature parsed is wire's (`int|void <name>() => throw
UnimplementedError(`), so compose and wire stay interchangeable on the same
subject contract.
