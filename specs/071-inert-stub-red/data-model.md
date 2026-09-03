# Data Model: 071-inert-stub-red

Date: 2026-09-03. Domain: the TDD loop's red-certification artifacts.

## Entities

### Behavior (existing, unchanged)
A planned testable behavior (id, source criterion, kind, description, target).
Kinds: `unit`, `acceptance`, `widget`, `ffi`, plus persistence flag. Only the
`widget` kind's red surface changes in this feature.

### Widget Subject Stub (changed)
The emitted seam file a widget-lane behavior's test pumps through.

| Field | Old value (throwing stub) | New value (inert stub) |
|---|---|---|
| signature | `Widget <target>() => throw UnimplementedError(...)` | `Widget <target>() => const SizedBox.shrink()` |
| red mechanism | guard assertion aborts the test | authored finders fail against the empty view |
| doc comment | "Throws UnimplementedError until implemented" | "inert red surface — renders nothing; replace body with the real view builder" |

State transition (the loop): inert stub → RED certified on finders → implementer
replaces the body with the real view builder → GREEN (zero assertion edits).

### Widget Test Harness (existing, unchanged)
Emitted by `BehaviorTestWriter._renderWidgetTest`: capture guard → `pumpWidget`
in app shell → `pumpAndSettle` → scenario finders (`find.text` per quoted
literal) → `find.byWidget(view), findsOneWidget` tail → optional golden hook.

### RedClassification (existing, unchanged)
Seven-way enum: `assertion`, `compile-error`, `load-error`, `skipped`,
`unexpected-green`, `runner-error`, `channel-timeout`. `assertion` is the only
certifying class. Semantics shift slightly *in practice*: with the inert stub,
`assertion` reds are finder-level by construction; `unexpected-green` becomes
the mechanical scaffold refusal.

### Failing-Assertion Detail (new evidence field)
The identity of the authored assertion that certified red, extracted from the
runner transcript (test description line and/or `Expected:`/`Actual:` block
header). Nullable — present only on `assertion` reds. Rendered by verify-red as
a `red-evidence:` line and persisted in the append-only cycle-log entry.

Validation rules: extraction is best-effort (null when the transcript carries no
parseable identity); never fabricates a name; the machine-readable summary line
gains an optional `evidence=<quoted-identity>` token, keeping FR-009's
final-line contract.

### Scaffold Marker (existing, unchanged)
`zfa:tdd: scaffolded` — still emitted for finder-less widget templates; `make`'s
string gate unchanged (backstop). Primary enforcement is now the verdict.

## Relationships

- Behavior 1—1 Subject Stub (gen pair, registered in `tdd/artifacts.json`).
- Behavior 1—* CycleLogEntry (`tdd/cycle-log.md`, append-only; `kind: red`
  entries mark the behavior certified).
- RunRecord *→ 1 RedClassification (pure `classify`); assertion reds carry 0..1
  Failing-Assertion Detail.
