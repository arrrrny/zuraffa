# Plan: 1537-dead-end-machinery-coverage

- **Spec ID**: 1537-dead-end-machinery-coverage
- **Created**: 2026-09-13

## Technical Context

- **Subject**: `PlanCommand._provenanceLines` / `_printDeadEndTally` /
  the two `dead_end_behaviors` verdict writes in
  `lib/src/plugins/tdd/commands/plan_command.dart` (single-file machinery;
  both the lane-split and legacy single-file render paths).
- **Routing ladder** (`lib/src/plugins/tdd/services/routing_resolver.dart`):
  `resolve()` returns `RoutingDecision` when any kind source declares a
  lane (`**Type**` marker → contract-row lane → test-list kind), a
  `RoutingFailure` on dangling references / conflicts / malformed
  signatures, and `RoutingUndeclared` only when `kind == null` and
  `strict == false`.
- **The criterion-token skip**: `_criterionToken = ^(FR|AC|SC)[-]?\d+` —
  trace tokens shaped like criterion ids "never dangle" and are skipped
  (`continue`) instead of failing. This exists for the test-list CELL
  shape (`FR-001, Formatter.format`) that make/gen tokenize; at plan time
  the same skip lets an author-authored criterion-only `traces:` line bind
  nothing while still deriving a unit row.
- **Behavior derivation** (`lib/src/plugins/tdd/services/spec_parser.dart`):
  `_extractUnit` keeps an FR only when `!routesManual` — i.e. the inline
  `traces:` tokens survive `traceTokens` (only `(`-shaped tokens drop) —
  or when a contracts/*.md criterion trace fills the gap (#1480). The
  derived row is always `BehaviorKind.unit`. `parseFrContractTraces` and
  `parseFrRoutings` share the filter, so `frTraces[U-id]` is non-empty for
  every surviving row.
- **The `!repairable` branch**: in `_provenanceLines`, a `RoutingUndeclared`
  result falls through to the labeled legacy fallback where
  `repairable = decision == acceptance || widget`. Every surviving
  FR-derived row has `decision == unit` → NOT repairable → `deadEnds.add`,
  the fatal prefix renders, and (past the #1480 gate) the tally prints and
  the verdict key records the count.
- **The #1480 gate** (plan_command, after `_provenanceLines`): refuses
  unit-kind fallbacks with exit 1 on the default path — but exempts
  persistence-marked behaviors (`[persistent]` tag / storage trace) and is
  skipped entirely under `--allow-unit-fallback`. These two exemptions are
  the two live routes the tally is reachable through.
- **Language/SDK**: Dart 3.13.3 stable, pure-Dart surface. Tests:
  `package:test` via `CliRunner(exitOnCompletion: false).runCapturing`,
  patterned on `test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
  (`Directory.systemTemp` fixtures, `addTearDown` deletion) and the
  envelope pattern from `plan_command_bug_1182_test.dart` (`--json` → last
  `{`-prefixed stdout line → `jsonDecode` → `details`).

## Architecture

```
 spec.md: - **FR-001**: [persistent] prose
                      traces: FR-001      ← criterion-only binding
        │
        ▼
 _extractUnit: traceTokens('FR-001') = ['FR-001'] (survives filter)
        → traced → routesManual false → unit row U1 (kind: unit)
        │
        ▼
 _provenanceLines → RoutingResolver.resolve(U1, traces: ['FR-001'])
        → _resolveToken miss → _criterionToken skip (never dangles)
        → kindSources empty, row.kind null → RoutingUndeclared
        │
        ▼
 fallback lane: decision = unit → repairable false
        → deadEnds.add(U1) + '[fallback: no declared trace — make will
           dead-end]' prefix            ← THE MACHINERY (live)
        │
        ▼
 #1480 gate: persistenceMarked contains U1 → exempt (or
        --allow-unit-fallback skips the gate)
        │
        ▼
 artifacts written → _printDeadEndTally([U1]) prints the tally
        → verdict details['dead_end_behaviors'] = 1   (both render paths)
```

Deletion mutant (the Option-A mistake, used for red evidence): remove the
`deadEnds.add` / fatal prefix / `_printDeadEndTally` calls / verdict keys
→ the pinning tests must FAIL (tally absent) → restore → green.

## Risks

- The `[persistent]` route renders through the marker-emission re-derive
  too (`postProvenance.deadEnds` re-computed) — the fixture asserts the
  final stdout, so both derivations must agree; they do (criterion skip is
  marker-independent), and SC-1's assertion covers the end state.
- Comment-only `plan_command.dart` edits must not drift into behavior:
  verified by `dart analyze` clean + the full #1481 suite green.
- `dart format` may reflow the touched comment blocks — run it before
  commit.
