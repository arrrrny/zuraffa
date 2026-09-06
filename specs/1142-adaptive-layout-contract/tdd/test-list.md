# Test List: 1142-adaptive-layout-contract (issue #1142)

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the Presentation table's `adaptive_layouts` bullet emits the AdaptiveViewState skeleton with per-platform layout stubs (mobile, macos) | FR-002 | PENDING |
| U2 | each layout stub composes the declared surfaces AND the adaptive_layout_scaffold_builder TODO placeholder; slot tokens never leak as stand-ins | FR-002 | PENDING |
| U3 | the adaptive skeleton is deterministic (byte-identical re-runs) and keeps the view-builder function name | FR-002 | PENDING |
| U4 | a feature with no slot declaration keeps the single-layout skeleton (zero drift) | FR-002 | PENDING |
| U5 | an unknown slot name refuses BEFORE any write with a `--> fix:` line | FR-001 | PENDING |
| U6 | per-platform ledger tracing — mobile-only evidence leaves macos rows NOT-DONE while the aggregate is green | FR-003 | PENDING |
| U7 | the heatmap renders per-platform kind-coverage (kind × slot traced/total cells) | FR-003 | PENDING |
| U8 | the ledger artifacts render the platform section and the JSON carries the per-platform rows | FR-003 | PENDING |
| U9 | the contract parser reads the Presentation declaration and refuses unknown slots by name | FR-001 | PENDING |

## Layer contracts

### Presentation

- `PlatformLayoutContract`: `fromContracts`, `classSuffix`, `knownSlots`
- `PlatformCoverageLedger`: `derive`, `slotsFromTrace`, `kindCoverageHeatmap`, `toMarkdown`, `toJson`

### Domain

- `ViewCommand`: `_renderAdaptiveView`, `_composedChildren`, `_platformLayoutContract`, `_todoMarkers`
- `UiLedgerProjection`: `componentTokensOf` (slot-declaration bullets excluded)
