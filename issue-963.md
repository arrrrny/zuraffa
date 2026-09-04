## Summary

"100% UI test coverage" needs a **ledger that measures it and a gate that enforces it**. Today coverage is implied by green behaviors — nothing enumerates the UI surface (static texts, routes, interactive affordances) against the behaviors that prove them, and nothing shows the gaps. The **XRay plugin** (overlay + control deck + `@XRayMock` scaffolder + mock scenario YAML — implemented, never used in ZikZak) is the natural runtime half of this.

## The ledger (static, machine-owned)

Per feature, plan already knows the declared literals (quoted-string contract) and routes (Layer Contracts Presentation row). Extend the traceability matrix (#846) with a **UI surface table**:

```
| surface        | kind    | proven by | state |
| "Sign In"      | text    | A1        | DONE  |
| /login         | route   | FR-001/U1 | DONE  |
| continueWithApple | affordance | A2  | DONE  |
```

- Every declared literal, route, and button affordance must trace to a green behavior.
- `zfa tdd plan` (or verify) computes UI-surface coverage: **untraced surface = exit 2 with the surface named** — the coverage-gate discipline (#846) extended from requirements to pixels.
- The ledger is committed (VISION §6 — institutional memory).

## The x-ray (runtime, human-facing)

- `zfa xray enable` + the overlay on the running app paints surfaces by ledger state: proven = clean, unproven = highlighted; shake to open the deck.
- The deck drives the certified mocks (`@XRayMock` + scenario YAML already parse) — a demo on mocked touchpoints that shows what's proven live.
- Wire the existing `zfa xray mock <Entity>` scaffolder to the new dependency mocks (issue: dependency-table mocks) so the deck has real entries out of the box.

## Acceptance (ZikZak-narrow)

1. Login feature: ledger shows every static text (the 8 production strings), `/login` route, and 3 button affordances traced to green behaviors — 100% or the gate names the gap.
2. `flutter run` with xray enabled shows unproven surfaces highlighted (start: none).
3. Coverage verdict is JSON + exit-coded; CI-able.

## Why

Coverage that isn't enumerated is a vibe. The ledger makes "everything is traced" a checkable claim; the overlay makes it visible; the gate makes it non-negotiable.

VISION: §2 (referee), §5 (5 lines that decide the next action), §6 (ledger as memory).

