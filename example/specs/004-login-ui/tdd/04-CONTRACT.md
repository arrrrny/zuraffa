# Engine/Skin Contract: 004-login-ui

The seam between `tdd/04-ENGINE.md` and `tdd/04-SKIN.md` (issue #1000).

## Boundary

- CORE (engine): pure Dart — zero Flutter references, plan-enforced.
- SKIN (skin): Flutter allowed.
- BOTH (seam): Flutter conditionally — one behavior, asserted on both sides of the seam.

## Adaptive view slots

| slot | declared lane |
| ---- | ------------- |
| mobile | SKIN |
| ios | SKIN |
| android | SKIN |
| macos | SKIN |

## Shared seam behaviors (BOTH lane)

Behaviors asserted on BOTH sides of the seam — their engine copy lives in `tdd/04-ENGINE.md`, their skin copy in `tdd/04-SKIN.md`.

| id | behavior | traces |
| -- | -------- | ------ |
| (none) | | |

