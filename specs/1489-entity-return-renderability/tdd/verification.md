# TDD Verification — SPEC 1489 (entity-return renderability)

**Feature:** 1489-entity-return-renderability
**Date:** 2026-09-10
**Environment:** Dart SDK 3.13.3 (stable), linux x64, cloud-agent fast tier

## Verdict: PASS — all success criteria verified, red→green recorded

## Verification log

### 1. dart analyze (changed files only — cloud-agent protocol)

```
$ dart analyze lib/src/plugins/tdd/commands/gen_command.dart \
    lib/src/plugins/tdd/commands/plan_command.dart \
    lib/src/plugins/tdd/commands/run_driver_core.dart \
    lib/src/plugins/tdd/services/behavior_test_writer.dart \
    lib/src/plugins/tdd/services/subject_writer.dart \
    lib/src/plugins/tdd/services/unit_contract_shape.dart \
    test/plugins/tdd/services/unit_contract_shape_1489_test.dart
Analyzing gen_command.dart, plan_command.dart, run_driver_core.dart,
    behavior_test_writer.dart, subject_writer.dart,
    unit_contract_shape.dart, unit_contract_shape_1489_test.dart...
No issues found!
```

Also analyzed the whole `lib/src/plugins/tdd/` tree: no issues.

### 2. dart test (targeted suites — only what the change touches)

```
$ dart test test/plugins/tdd/services/unit_contract_shape_1489_test.dart
00:00 +20: All tests passed!
```

Combined no-regression run (10 suites, fast tier, after `dart format`):

```
00:09 +60: All tests passed!
```

Slow-tier suites tagged `slow` (e.g. `test/plugins/tdd/services/subject_writer_test.dart`)
are excluded by `dart_test.yaml` on cloud agents by design; the fast-tier
siblings cover the same writer contracts.

### 3. dart format

```
$ dart format <7 changed/new files>
Formatted 7 files (3 changed) in 0.10 seconds.
```

### 4. Kernel-cache hygiene (the repo's cloud-agent protocol)

```
$ rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*
```

Run before and after the verification passes.

## Acceptance-criteria coverage

| SC | Requirement | Evidence | Verdict |
| -- | ----------- | -------- | ------- |
| SC-1 | Predicate/caller gains entity registry via `locateEntityFile`; existing entity → declared type in the subject | U-1489-1/4/8/9/10; `ofResolved` uses `locateEntityFile` under the gen cwd — the same fact phase-0 consults | PASS |
| SC-2 | Generated subject includes the entity's import — directly implementable | U-1489-8/9/10/13; `package:` URI baked into the shape (deterministic across the staleness re-render), emitted after `library;` | PASS |
| SC-3 | `scalarOutcome` reflects corrected renderability — existing entity-returns leave the hand-step seam | U-1489-4/7/9/16; the paired test emits `expect(result, isA<Task>());` + the return-entity import, no vacuous-guard marker | PASS |
| SC-4 | `zfa tdd plan` surfaces `N of M unit behaviors will hand-step because return is an entity` | U-1489-12/18/19; the line renders in the test list after the unit table AND in the plan summary stdout; the run driver announces the same forecast when N > 0 | PASS |
| SC-5 | Missing entities still degrade to `Object?`; doc comments state the degradation is unconditional for non-existent entities | U-1489-2/3/5/6/11/14/15/17; every new parameter is optional — registry-less callers get today's shapes byte-for-byte; both writers' docs reworded | PASS |

## Hard-constraint audit

- **Fix surface:** the renderability logic is confined to
  `unit_contract_shape.dart` (predicate + shape + registry resolution),
  `subject_writer.dart` (import block + corrected docs) and
  `run_driver_core.dart` (the announce-only forecast). Two consumer
  call-sites thread the new shape data mechanically:
  `gen_command.dart` passes the registry at the single existing call-site;
  `behavior_test_writer.dart` emits the return-entity import its assertion
  references. `plan_command.dart` carries the SC-4 surface (the file where
  `zfa tdd plan` renders). No other file changed — `git diff --stat`
  confirms 6 files.
- **No state-machine change:** `BehaviorState`, all state transitions, the
  two-phase loop, and the run driver's step semantics are untouched; the
  driver change is an output-only announce line gated on N > 0.
- **Generics/nullable:** `List<Entity>`, `Set<Entity>`, `Iterable<Entity>`,
  `Entity?`, `Map<K, Entity>` all lift (U-1489-1/9) and degrade (U-1489-2).
- **Backwards compat:** every new shape field has a const default; `of()`
  with no registry reproduces the legacy shapes exactly (U-1489-3/6/15);
  the #1308 marker path is byte-identical (U-1489-17 + the #1308 suite).

## Cross-artifact consistency (/speckit.analyze)

- spec.md FR-1..FR-5 ↔ tasks.md T1–T12 ↔ test-list.md U-1489-1..19: every FR
  maps to at least one test id; every test id maps to a task; no orphan
  requirements, no orphan tests.
- The plan's design decisions (baked URIs, optional predicate, conditional
  `scalarOutcome`) match the implemented code — audited line-by-line during
  verification.
- Drift found and fixed during the cycle: the test-side import was refined
  from `returnEntityImport` (single) to `returnEntityImports` (list) so a
  multi-entity return (`Map<Task, User>`) imports every referenced entity;
  the degradation paragraph became conditional so a fully-renderable shape
  carries no `replace it with the declared type` instruction (the exact
  #1489 complaint).

## Remediation tasks

None open. Known limitation (documented, out of scope per spec): the contract
lane's `ContractSubjectWriter` keeps its own `Object?` degradation — its
paired contract test stays BLOCKED by design, not RED.
