# Contract: zuraffa-1.1 template declarations

New declared structures the spec template offers. All are line-addressable
(provenance and errors cite them). Structural parsing of everything that exists
today is unchanged.

## 1. Scenario type marker (rung 1)

Inside a scenario body, after its Then clause:

```markdown
**Given** the cart holds two items, **When** the checkout completes, **Then** the widget renders "Order placed".
**Type**: widget
```

- Grammar: a line matching `^\*\*Type\*\*: <kind>$` where `<kind>` ∈
  `acceptance | unit | widget | theme | ffi | platform` (the existing BehaviorKind set).
- Exactly one marker per scenario; a second marker for the same scenario is a
  `declaration-conflict`.
- The marker line number is the declaration's `spec line`.

## 2. Contract-row traces (rung 2)

A scenario/FR declares the row it exercises by naming it in the existing trace
syntax, extended to accept contract-row names alongside FR/AC ids:

```markdown
**FR-004**: The checkout totals the cart and returns the payable amount.
            traces: ProductRepository, `format(Template) -> String`
```

- A trace token resolves, in order: Key Entities row name → Layer Contracts
  interface/component name → External Dependencies row name.
- `traces:` entries are contract ROW NAMES. A backticked inline signature such
  as `` `format(Template) -> String` `` documents the expected signature for
  reviewers — it is NOT a row reference: the tokenizer keeps the span intact
  (never comma-split mid-signature) and drops it, so it neither resolves nor
  dangles.
- Row kind follows the declaring section (research D2 table):
  `**Presentation**` → presentation; `**Domain**`/`**Data**` → domain/data;
  Key Entities → entity; Dependencies type `storage:…` → storage;
  type `channel:…` → channel; a `**Function**` contracts bullet → function.
- A trace to a name that resolves to nothing is a `dangling-reference`.
- Traces to rows of different kinds are a `declaration-conflict` naming the
  rows.

## 3. Function contracts bullet (new, inside Layer Contracts)

```markdown
### Layer Contracts

**Function**:
- `format`: `format(Template) -> String`, `formatSummary(List<OrderLine>) -> String`
```

- Same bullet grammar as the existing `**Domain**`/`**Presentation**` bullets
  (#919 grammar, unchanged parser); only the layer label is new.
- Signatures are `name(Params) -> Return`; a bullet without `->` is a
  `malformed-declaration` (names the row).

## 4. Persistence declarations

Either form marks the FR's behavior persistent:

```markdown
**FR-007**: [persistent] The cart survives an app restart.
**FR-008**: The cart syncs with the backend offline queue.
            traces: CartStorage
```

- Form (a): a `[persistent]` tag on the FR line.
- Form (b): a trace to an External Dependencies row whose type cell starts with
  `storage:` (e.g. `storage:hive`).
- The generated test-list mark is the existing ` [persistence]` cell suffix —
  its harness contract is unchanged; only the trigger becomes declarative.

## 5. Unchanged declared structures

Given/When/Then scenario headers, `##` section structure, the Key Entities and
External Dependencies tables, Layer Contracts bullets, `**Template Version**` pin,
`(manual:)` markers, behavior id prefixes, and the test-list section headers/kind
cells — all parse exactly as today (FR-012).

## Migration

Template v1.1 documents the markers above; v1.0 specs remain valid through the
fallback window. Legacy keyword classifiers stay reachable only as the labeled
fallback (rung 4) and only while strict mode is off.
