# Data Model: UI Coverage Ledger + XRay Gatekeeper (075)

## Entities

### UISurface

| Field | Type | Notes |
| --- | --- | --- |
| surface | String | literal text, route path, or affordance name |
| kind | `text` / `route` / `affordance` | declared kind |
| source | String | declaring location (scenario line / contract row) |

### LedgerRow

| Field | Type |
| --- | --- |
| surface | UISurface |
| provenBy | `List<String>` behavior ids asserting this surface |
| state | `DONE` (≥1 prover green at read time) / `NOT-DONE` |

### UI Ledger artifact

`specs/<feature>/tdd/ui-ledger.md` (human) + `ui-ledger.json` (twin):

| surface | kind | proven by | state |
| --- | --- | --- | --- |
| "Sign In" | text | A1 | DONE |
| /login | route | FR-001/U1 | DONE |
| continueWithApple | affordance | A2 | NOT-DONE |

### CoverageVerdict (JSON, gate stdout)

```json
{
  "check": "ui-coverage",
  "feature": "<feature>",
  "surfaces": [
    {"surface": "\"Sign In\"", "kind": "text", "provenBy": ["A1"], "state": "DONE"},
    {"surface": "continueWithApple", "kind": "affordance", "provenBy": [], "state": "NOT-DONE"}
  ],
  "proven": 2, "unproven": 1, "passed": false
}
```

Exit: 0 complete · 1 gaps (each named).

### XRayBinding

| Field | Type |
| --- | --- |
| ledgerSource | String (ui-ledger path) |
| overlayMode | paint-by-state (proven clean / unproven highlighted / no-ledger reported) |
| deckEntries | per ledger row + per dependency-mock scenario (072 rail) |

## Invariants

1. I1: rows come from declarations only (quoted-literal contract,
   Presentation route row, declared affordances).
2. I2: state derives from CURRENT green evidence at read time.
3. I3: absence of a ledger is reported as absence — never proof.
4. I4: every gap message names the surface + the behavior to write or
   the declaration to add (`--> fix:`).
