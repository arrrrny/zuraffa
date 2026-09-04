# Contracts: UI Coverage Ledger + XRay Gatekeeper (075)

## ui-ledger.md — ledger artifact contract

- Emitted by `zfa tdd plan` next to the traceability matrix
  (`specs/<feature>/tdd/ui-ledger.md` + `.json`).
- Sources: presence literals (finder-taxonomy scenario assertions),
  Presentation route row, declared affordances.
- One row per declared surface: `| surface | kind | proven by | state |`.
- A surface with no provers appears as `NOT-DONE` with an empty
  proven-by cell (visible at plan time).
- State is recomputed at every read from the registry/cycle evidence;
  the artifact's stored state is a cache, not the truth.

## coverage-gate.md — `zfa tdd coverage` verdict contract

```text
zfa tdd coverage <feature> [--json] [--project <dir>]
```

- Summary line (final stdout): `coverage: feature=<f> surfaces=<n>
  proven=<n> unproven=<m> outcome=<complete|gaps>`.
- `--json`: CoverageVerdict shape (data-model) with per-row lines.
- Exit 0 iff `unproven == 0`; else exit 1 with each gap named:
  `--> fix: write/land the proving behavior for "continueWithApple"
  (affordance) — no behavior traces it.`
- A feature with zero declared surfaces exits 0 with an empty verdict.
- Merge composition: 074's conformance verdict calls this gate as its
  `coverage` check; standalone operation is unchanged.

## xray-overlay-binding.md — overlay/deck contract

- `zfa xray enable` reads the ledger: proven surfaces paint clean,
  `NOT-DONE` highlight; **no ledger** ⇒ overlay reports "no ledger"
  (absence is never painted as proof).
- The deck lists ledger rows with states and drives 072 dependency-mock
  fixture scenarios as entries (via the `xray mock` scaffolder); a
  touchpoint without a generated mock names
  `--> fix: zfa mock dependency <Name>`.
- Overlay/deck state refreshes from the ledger artifact (single
  inventory behind both surfaces).
