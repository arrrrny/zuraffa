# TDD Declared Routing

> How `zfa tdd` decides what a behavior is and how it generates — by
> **declarations in the spec**, not by keyword matching over prose
> (feature 071, issue #951; the #936/#950/#920/#696/#833 defect class).

## The declaration ladder

Routing consults these in order; the first that applies decides, and
every decision is reported with its provenance:

1. **Scenario type marker** — `**Type**: widget` (or `unit`, `acceptance`,
   `ffi`, `platform`, `theme`) on its own line inside a numbered
   scenario block. One marker per scenario; duplicates are refused.
2. **Contract-row trace** — a `traces:` continuation on an FR line
   naming a declared row: Layer Contracts interfaces
   (`**Presentation**` / `**Domain**` / `**Data**` / `**Function**`
   bullets), Key Entities rows, or External Dependencies rows whose
   type starts with `storage:` or `channel:`.
3. **Test-list kind declaration** — the section headers
   (`## Outer loop: widget behaviors`, `## Native loop`, …) and kind
   cells the plan writes.
4. **Labeled fallback** (migration window only) — the legacy keyword
   classifiers, still consulted for undeclared behaviors, but every
   plan prints the route with a `[fallback: …]` label and the
   declaration to add.

## What routes from what

| Declaration | Decides |
|---|---|
| `**Type**` marker | the lane (widget / unit / ffi / …) |
| Layer Contracts row kind | lane + generation surface (presentation → view, domain/data → entity pipeline, function → `zfa tdd func`) |
| Function row signature (`format(Template) -> String`) | the generated subject's return type (no prose inference) |
| Key Entities row | the entity an entity-pipeline behavior generates |
| `[persistent]` tag or `storage:` dependency trace | the `[persistence]` harness mark |

Structural grammar (scenario headers, section tables, `**Template
Version**`, `(manual:)`, id prefixes) is unchanged — only semantic
keyword matching is eliminated.

## Provenance and strict mode

`zfa tdd plan` prints one `route:` line per behavior, e.g.:

```
   route: A1 -> widget lane [declared: type marker, spec line 17]
   route: U1 -> unit lane (func surface) [declared: contract row: Formatter, spec line 30]
   route: U2 -> widget lane [fallback: legacy description classifier matched — add `**Type**: widget` to the scenario]
```

The same lines are persisted under `## Routing provenance` in the test
list. `--strict-routing` (on `zfa tdd plan` and `zfa tdd make`) removes
the fallback: an undeclared behavior exits 1 with the spec line and the
`--> fix:` declaration to add, and no artifacts are written.

## For spec authors

- Mark each scenario's type when it is not the default acceptance lane.
- Name contract rows in FR `traces:` continuations instead of relying
  on wording.
- Tag persistence explicitly with `[persistent]` (or trace to a
  `storage:` dependency) — mentioning "cache" no longer marks anything.
- Run `--strict-routing` to check a spec is fully declared.
