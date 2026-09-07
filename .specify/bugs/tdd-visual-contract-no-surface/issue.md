# Bug Issue: tdd: no visual-contract surface — goldens are a gen-only flag, adaptive_slots never proposed, SKIN lanes fall through to a path that cannot express skins

- **Slug**: tdd-visual-contract-no-surface
- **Fetched**: 2026-09-07
- **Issue**: 1261
- **URL**: https://github.com/arrrrny/zuraffa/issues/1261
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

**Describe the bug**

The TDD pipeline has no surface for a **visual contract**, which makes "pixel-parity" skins unexpressible and leaves the strongest hand-skin seam unused by default:

1. `--golden` (bug #830) exists only as a per-invocation `zfa tdd gen --golden` flag. The `## Lanes` yaml / plan / split / test-list formats have no golden column or section, so a spec cannot *declare* "this behavior is golden-gated". A regenerating agent has no way to know goldens were intended.
2. `run-skin`'s hand-written conformance cycle (spec 1005 — contract slots, red-before-green witness, `_XRaySkinHandEdit`) — the one path designed for real, hand-authored skins — only engages when the spec declares `adaptive_slots` (plus `## Skin Contract`). `zfa tdd plan`/`split` never propose slots from widget scenarios, and nothing warns when a SKIN lane has zero slots and zero goldens. Result: skins silently fall through to the generic gen→verify-red→make→refactor path, which dead-ends (see the scaffolded-test refusal) or certifies nothing visual.
3. The generated widget scaffold's own comment says "golden baselines are committed per platform under test/tdd/goldens/" even when `--golden` was not passed — misleading the author into expecting a golden harness that does not exist.

Observed in a real login-skin migration: the SKIN lane (3 widget behaviors, a gradient/sign-in-button layout) declared no slots and no goldens; run-skin took the generic path and stopped; no artifact in the pipeline ever represented the actual visual target.

**To Reproduce**

1. Spec with a SKIN lane of widget behaviors and no `adaptive_slots`/`## Skin Contract` (the default `zfa tdd ingest`/`plan` output for a UI feature).
2. `zfa tdd split` → `zfa tdd run-skin`.
3. Observe: no conformance cycle, no golden hook, no warning that the skin has no visual contract; the lane proceeds down the generic path.

**Expected behavior**

- `plan`/`split` should let a spec declare goldens per SKIN behavior (e.g. `golden: true` in the lane row or `## Skin Contract`), and `gen` should pick that up without the flag.
- `plan` should propose `adaptive_slots` for widget-kind SKIN behaviors (or at minimum refuse/warn when a SKIN lane has neither slots nor goldens — "this skin has no visual contract").
- The widget scaffold comment should only mention goldens when a golden hook was actually emitted.

**Actual behavior**

Visual parity is not representable; the hand-skin conformance seam (spec 1005) is unreachable unless the author knows to hand-write `adaptive_slots` + `## Skin Contract` into the spec.

**Library (please complete the following information):**
 - Version: 6.1.0 (master)

## Comments

None.
