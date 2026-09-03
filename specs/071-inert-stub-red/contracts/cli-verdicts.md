# Contracts: CLI Verdict Surfaces (071-inert-stub-red)

Date: 2026-09-03. The machine-parseable surfaces this feature touches. VISION §4:
the agent parses verdicts, never prose.

## 1. `zfa tdd verify-red` summary line (FR-009 contract — unchanged)

Final stdout line on every code path, byte-identical to the pre-#959
pinned format on EVERY path (certified and rejected):

```
verify-red: behavior=<id> classification=<class> certified=<bool> feature=<feature>
```

No evidence token is appended: the summary line is spec-046's published
contract and anchored consumers parse it exactly.

## 1b. `zfa tdd verify-red` failing-assertion identity (new surface)

On a certified red whose transcript names the failing authored assertion,
before the summary line:

```
   red-evidence: <identity>
```

- `<identity>`: single-line failing-test description extracted by
  `failingAssertionOf` (spaces allowed, no newlines). Omitted when the
  transcript carries no parseable identity — never fabricated.
- The identity is also persisted in the cycle-log red entry as the
  optional `- evidence:` line (see §3).
- Exit codes unchanged: 0 ⇔ honest red certified (assertion class).

## 2. Cycle-log red entries (`specs/<feature>/tdd/cycle-log.md`)

Red entries MAY carry one new optional field line, emitted when the red was
finder-certified:

```
- evidence: <identity>
```

Placement: after `- classification:`. Append-only log rules, prev-hash chain,
and all existing lines are unchanged. If the integrity contract (bug #828,
`evidenceSchemaVersion`) requires it for hash verification, bump the schema
version in the same change and update the integrity test fixtures; readers
treat unknown field lines as opaque.

## 3. Generated widget subject stub (target-project source contract)

```dart
/// Inert red surface ... replace this body with the real view builder.
Widget <target>() => const SizedBox.shrink();
```

- Compiles with only `package:flutter/material.dart` (no new imports).
- Header comments keep `behavior_id` / `source_criterion` traceability.
- Non-widget stubs (unit/acceptance/ffi/persistence) byte-identical to today.

## 4. Generated widget test harness (unchanged shape, re-anchored comments)

The emitted test keeps: capture guard (`isNot(isA<UnimplementedError>())`) →
`pumpWidget(<shell>(home: Scaffold(body: view)))` → `pumpAndSettle` → scenario
finders → `find.byWidget(view), findsOneWidget` tail → optional golden hook.
Only comments change (guard described as secondary). Scaffold marker emission
(`zfa:tdd: scaffolded`) unchanged for finder-less templates.
