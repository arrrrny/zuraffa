# Quickstart: UI Coverage Ledger + XRay Gatekeeper (075)

```bash
# 1. Plan emits the ledger (texts, routes, affordances -> rows)
zfa tdd plan <feature>
# specs/<feature>/tdd/ui-ledger.md (+ .json twin)

# 2. Gate: exit 0 only when every row is proven green
zfa tdd coverage <feature> --json
# coverage: feature=login surfaces=12 proven=11 unproven=1 outcome=gaps
#   --> fix: write/land the proving behavior for "continueWithApple"

# 3. Live: the overlay paints ledger state
zfa xray enable          # proven = clean, unproven = highlighted
                         # no ledger = reported, never painted as proof

# 4. The deck drives certified mocks out of the box
zfa xray mock <Name>     # entries from 072 dependency mocks + fixtures
```

## CI / merge

- Standalone: `zfa tdd coverage <feature>` in CI (exit-coded verdict).
- Merge: composed as the `coverage` check of 074's conformance verdict —
  an incomplete ledger blocks the landing naming the gaps.
