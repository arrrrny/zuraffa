# Contract: RoutingResolver (internal service)

The single owner of the declaration ladder (research D7). Pure: consumes parsed
declarations, never reads files, never spawns.

## API shape

```dart
class RoutingResolver {
  /// Resolve routing for one behavior from parsed declarations.
  RoutingResult resolve({
    required BehaviorRow row,                  // id, description, traces, existing kind cell
    required SpecDeclarations declarations,    // markers, contract rows, persistence tags (parsed once per spec)
    required bool strict,                      // strict mode flag
  });
}

sealed class RoutingResult {}

class RoutingDecision extends RoutingResult {
  BehaviorKind kind;                 // lane
  GenerationSurface surface;         // entityPipeline | dependencyMake | viewGeneration | plainFunction | none
  String? entityName;                // declared entity reference (null unless declared)
  Signature? signature;              // declared signature (null unless declared)
  bool persistence;                  // declared persistence marking
  List<ProvenanceLine> provenance;   // >= 1 entry; every aspect accounted for
}

class RoutingFailure extends RoutingResult {
  RoutingFailureCode code;           // declarationConflict | danglingReference | malformedDeclaration | undeclaredStrict
  String message;                    // names the spec line(s) and the `--> fix:` declaration
}
```

## Ladder semantics (normative)

1. If `row.declaredType` (marker) applies → kind decided. Conflicts with a
   contract-row trace of a different lane → `declarationConflict` naming both lines.
2. Else if `row.contractRefs` resolve to rows → kind + surface + entity/signature
   from the row kind (D2 table). Unresolvable name → `danglingReference`.
   Rows of different kinds → `declarationConflict`.
3. Else if the test list declares kind (section header / kind cell) → kind decided;
   surface/entity/signature remain undeclared (fall to 4 per aspect).
4. Else (fallback window, `strict == false`): the legacy classifiers decide the
   remaining aspects, each decision labeled `fallback` with the fix hint and spec
   line. If `strict == true` → `undeclaredStrict`.

Per-aspect resolution: kind, surface, entity, signature, and persistence are
decided independently through the ladder — a declared function row yields a declared
signature even when the kind came from a section header. Provenance records one line
per aspect, mixed declared/fallback as appropriate.

## Error message shape

Every failure message contains: the behavior id, the offending spec line number(s),
and a `--> fix:` line naming the exact declaration to add or remove.

## Consumers

| Consumer | Reads |
|---|---|
| `zfa tdd plan` (plan_command) | everything: renders `route:` provenance lines, persistence mark, strict refusals |
| `GenerationPlanner` (make path) | kind + surface + entityName + provenance reason (replaces branch 0b/1/2/3 prose dispatch; branches become surface-keyed) |
| `tdd func` / `tdd wire` | signature (declared) with the prose deriver as rung-4 fallback |
| `TestListReader` side | persistence declaration replaces keyword matching for the mark trigger |

## Invariants

- Determinism: identical inputs → identical decision (no wall-clock, no locale).
- Purity: no filesystem/subprocess access; callers pass parsed declarations.
- Totality: every behavior yields exactly one `RoutingResult`; guessing never
  happens outside a labeled fallback.
- Under `strict`, no code path returns a fallback-labeled decision — the ladder
  ends at rung 3 or fails `undeclaredStrict`.
