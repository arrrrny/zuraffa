# Bug Assessment: `zfa tdd verify` reports every non-widget behavior as "not traced"

- **Slug**: 1996-verify-not-traced-header
- **Created**: 2026-10-22
- **Source**: https://github.com/arrrrny/zuraffa/issues/1996
- **Verdict**: valid — reproduced against `master` (see `red-evidence.txt`)
- **Severity**: medium — the referee does not fail, but it reports a
  false negative on every behavior of every non-widget feature, and the
  message names a header the generator cannot emit on those lanes (so the
  finding was unfixable in the consumer repo)

## Report (summarized)

`zfa tdd verify --feature <id>` lists EVERY unit / contract / acceptance
behavior as

```
- `U1` — not traced: no scenario-assertions header in test/tdd/<feature>/u1_test.dart
```

although the generated test carries the generator's own machine-readable
header block and real assertions:

```dart
// GENERATED TEST — `zfa tdd gen U1` (spec 044-test-tdd-generation).
//
// behavior_id: U1
// source_criterion: FR-001
// kind: unit
```

## Symptom

Every behavior of a feature without widget behaviors lands in the
not-traced bucket (22 of 22 in the reporter's
`zuraffa_purchase` feature `002-subscription-error-vocabulary` — U1–U7,
contract:A1–A4, A1–A11).

## Reproduction

Committed as the RED test
`test/plugins/tdd/bug_1996_verify_not_traced_header_test.dart`:

```sh
dart test test/plugins/tdd/bug_1996_verify_not_traced_header_test.dart
```

Against the unfixed tree the report renders
`- `U1` — not traced: no scenario-assertions header in …` — the exact
string from the issue.

## Root Cause (verified against source)

The finder-kind taxonomy (issue #964) is a **widget-lane vocabulary**:
`ScenarioAssertionClass` (presence / absence / route-outcome /
enabled-state / sequence) describes what a WIDGET finder asserts.

1. `lib/src/plugins/tdd/services/behavior_test_writer.dart:870` — the
   WIDGET template is the only test template that emits the
   `// scenario-assertions:` header (`FinderTaxonomy.headerLine`).
2. Every other lane's template emits the generator's own header block
   instead — `behavior_test_writer.dart:328-333` (unit),
   `contract_test_writer.dart:713-716` (contract),
   `theme_harness_test_writer.dart:86-89` (theme),
   `platform_harness_test_writer.dart:171-174` (platform),
   `behavior_test_writer.dart:1167-1169` and
   `golden_harness_writer.dart:219-222` (ffi).
3. `lib/src/plugins/tdd/services/behavior_kind_trace.dart:120-128` — the
   trace reads ONLY the `// scenario-assertions:` header. A behavior
   whose test has none lands in `notTraced` with the reason
   `no scenario-assertions header in <path>`.
4. `lib/src/plugins/tdd/services/mutation_auditor.dart:265-275` — the
   report renders that bucket verbatim, one `not traced` line per
   behavior.

So the referee demanded a header that only the widget lane emits, and
every other lane's behavior was reported as untraced — with a message
the reader could not act on, because generated tests must not be
hand-edited.

## Remediation

The referee accepts the header block the generator DOES emit, and its
message names the header it wants:

1. **`behavior_kind_trace.dart`** — parse the generator's own `// kind:`
   line (`parseDeclaredKind`) next to the taxonomy header. A test that
   carries it is TRACED by that declared kind (`unit`, `contract`, …) and
   never lands in the not-traced bucket. A test with NO machine-readable
   header at all stays not-traced, and its reason now names both
   acceptable headers (`// scenario-assertions:` OR the generated
   `// behavior_id:` / `// source_criterion:` / `// kind:` block).
2. **`behavior_kind_trace.dart`** — `BehaviorKindTraceResult` carries
   `declaredKindByBehavior`; `declaredKindCounts` aggregates it;
   `detailsObject` ships it in the verdict envelope as
   `declared_kind_by_behavior`.
3. **`mutation_auditor.dart`** — the report's `## Behavior kinds` section
   lists a behavior traced by its declared kind as
   `- `U1` — unit (behavior kind)` and adds a
   `- traced by behavior kind: unit=7, contract=4` count line, so a
   feature without a widget behavior does not read as "nothing was
   traced".
4. **`verify_command.dart`** — the stdout summary adds the
   `declared kinds: …` line; the envelope's `behavior_kinds` object
   carries `declared_kind_by_behavior`.

## Spec impact (spec 1376-verify-kind-trace)

The fix narrows ONE clause of the spec's kind-trace contract and leaves
everything else untouched:

- **FR-001 / FR-003** — the kinds still come from the machine-certified
  `// scenario-assertions:` header; the trace additionally accepts the
  generator's own `// kind:` header for the lanes that carry no taxonomy
  header at all.
- **SC-2** — still holds for a test file with NO machine-readable header
  at all: it lands in the not-traced bucket with the behavior id named.
  What changes is that the reason now names BOTH acceptable headers
  instead of demanding the widget-lane one.
- **FR-002 / FR-006** — unchanged: an unknown taxonomy token still
  degrades to not-traced with the raw token preserved, and the gate
  semantics, exit classes, mutation buckets and restoration scope are
  untouched (the change is additive reporting).

## Hard constraints

- Gate semantics, exit classes, mutation buckets and the restoration
  scope are untouched — the change is ADDITIVE reporting, exactly as
  spec 1376 requires (FR-006).
- The finder-kind taxonomy, its canonical order and the widget lane's
  `// scenario-assertions:` header format are unchanged: a widget test
  with the taxonomy header still traces through the taxonomy.
- No writer change: the generator keeps emitting the same headers; the
  referee simply learns to read the block it already emits.
- An unknown taxonomy token still degrades to the not-traced bucket with
  the raw token preserved (spec 1376 FR-002).
