# Contract: Loop Priority Ordering (dependency mocks)

## Ordering rule

Dependency mocks materialize in the loop ordered by
`(tier, declarationIndex)`:

| tier | priority cell |
| --- | --- |
| 0 | P1 |
| 1 | P2 |
| 2 | P3 |
| 3 | (empty / unprioritized) |

`declarationIndex` is the row's order in the spec's dependency table
(stable tie-break). The order is a pure function of the declared rows —
no timestamps, no hash iteration.

## Visibility

The plan artifact's dependency section renders each row with its
priority and resulting order position:

```text
| # | dependency | kind | priority | mock |
| 0 | FirebaseAuth | service | P1 | dependency:FirebaseAuth |
| 1 | Hive | storage | P2 | dependency:Hive |
```

## Loop behavior

- The make path materializes mocks in this order before (or with, per
  the generation gate) the behaviors that trace to them.
- A behavior tracing to a row whose mock is absent refuses with
  `--> fix: zfa mock dependency <Name>` unless the loop's generation
  gate auto-materializes it (then the materialization is surfaced in
  output and the registry).
- The batch red lane and single lane apply the same refusal (a missing
  dependency mock is a named error, never a silently absent test
  double).
