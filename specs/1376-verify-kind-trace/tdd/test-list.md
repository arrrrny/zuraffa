# Test List: 1376-verify-kind-trace

Derived from spec.md + plan.md (speckit.tdd.plan). Every behavior gets a
failing test BEFORE its implementation lands (red-green-refactor).

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1376-1 | the header parser extracts the canonical kind labels from a `// scenario-assertions:` header — `kind("literal")` cells, `enabled-state("lit")(disabled|enabled)` polarity cells, and the bare `sequence` token — returning them in canonical order, deduped | FR-001 | GREEN |
| U-1376-2 | unknown or malformed header tokens degrade to `not-traced` with the raw token preserved — never a throw, never an inferred kind | FR-002 | GREEN |
| U-1376-3 | `BehaviorKindTrace.trace()` maps each registered behavior id to the kinds parsed from its generated test file (registry test paths resolved against the audit working directory); a missing test file or a header-less test lands the behavior in `not-traced` | FR-001, FR-002, SC-2 | GREEN |
| U-1376-4 | the audit report carries `behaviorKindsByBehavior` + `notTracedBehaviors` populated from the trace on full-run reports, and `toMarkdown()` renders the additive `## Behavior kinds` section (per-kind counts in canonical order + per-behavior list + `not-traced` bucket), omitted when the scope was empty | FR-003, FR-006 | GREEN |
| U-1376-5 | the verify stdout summary line carries the per-kind counts and the `verdict.v1` envelope `details` carries the `behavior_kinds` object (counts + per-behavior + not-traced) | FR-004, FR-005 | GREEN |
| U-1376-REG1 | regression guard: the existing mutation-auditor suites keep byte-compatible gate decisions, exit classes, and pre-#1376 markdown sections on NOT_ASSESSED paths (no new section, no kind fields emitted when the scope was empty) | FR-006, SC-3 | GREEN |

## Layer contracts

```yaml
# fr: FR-001, FR-002
behavior_kind_trace.dart: parseScenarioAssertionHeader, BehaviorKindTrace.trace, canonical kind order constant
# fr: FR-003, FR-006
mutation_auditor.dart: MutationAuditReport.behaviorKindsByBehavior / .notTracedBehaviors / toMarkdown Behavior kinds section
# fr: FR-004, FR-005
verify_command.dart: stdout kind-count summary line, verdict.v1 details.behavior_kinds
```

## Key entities

```yaml
BehaviorKindTrace: the kind-trace reader (parse + resolve + aggregate)
MutationAuditReport: carries the trace; renders the markdown section
VerifyCommand: prints the kind summary; extends the verdict envelope
```
