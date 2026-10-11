# Bug Assessment: tdd visual-contract surface — golden-declarable in spec, adaptive_slots proposed for SKIN, no misleading scaffold comments

- **Slug**: tdd-visual-contract-no-surface
- **Created**: 2026-09-07
- **Source**: https://github.com/arrrrny/zuraffa/issues/1261
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The TDD pipeline has no surface for a visual contract, which makes "pixel-parity" skins unexpressible and leaves the strongest hand-skin seam unused by default. (1) `--golden` exists only as a per-invocation `zfa tdd gen --golden` flag — the `## Lanes` yaml / plan / split / test-list formats have no golden column or section, so a spec cannot declare "this behavior is golden-gated" and a regenerating agent has no way to know goldens were intended. (2) `run-skin`'s hand-written conformance cycle (spec 1005 — contract slots, red-before-green witness, `_XRaySkinHandEdit`) only engages when the spec declares `adaptive_slots` (plus `## Skin Contract`); `zfa tdd plan`/`split` never propose slots from widget scenarios and nothing warns when a SKIN lane has zero slots and zero goldens, so skins silently fall through to the generic gen→verify-red→make→refactor path, which dead-ends or certifies nothing visual. (3) The generated widget scaffold's comment claims "golden baselines are committed per platform under test/tdd/goldens/" even when `--golden` was not passed.

## Symptom

A SKIN lane of widget behaviors with no `adaptive_slots` and no golden declaration plans cleanly, splits cleanly, and drives run-skin down the generic path with no conformance cycle, no golden hook, and no warning that the skin has no visual contract. No artifact in the pipeline represents the visual target.

## Reproduction

1. Spec with a SKIN lane of widget behaviors and no `adaptive_slots`/`## Skin Contract` (the default `zfa tdd ingest`/`plan` output for a UI feature).
2. `zfa tdd split` → `zfa tdd run-skin`.
3. Observe: no conformance cycle, no golden hook, no warning; the lane proceeds down the generic path. Separately: `zfa tdd gen <widget>` without `--golden` emits a scaffold whose header claims golden baselines are committed.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/spec_parser.dart` — `parseLanes` has no `golden:` key in the lane grammar
- `lib/src/plugins/tdd/services/lane_split.dart` — `renderSkinPlan`/`renderMetaIndex` have no golden surface
- `lib/src/plugins/tdd/commands/plan_command.dart` / `split_command.dart` — never propose slots, never warn on a contract-less skin, never carry golden declarations
- `lib/src/plugins/tdd/services/test_list_reader.dart` — the row format has no golden marker
- `lib/src/plugins/tdd/commands/gen_command.dart` — golden comes from the `--golden` flag only
- `lib/src/plugins/tdd/services/behavior_test_writer.dart` — `_renderWidgetTest` header mentions goldens unconditionally

## Root Cause Hypothesis

High confidence: the visual contract was expressible only as a per-invocation CLI flag, never as a spec declaration. The lane grammar (#1000) grew `adaptive_slots` but no golden key; plan/split render no visual-contract surface; the reader's single format contract has no golden marker; and the widget scaffold's header comment was written unconditionally instead of being a function of the emitted hook. Nothing in the pipeline warns when a SKIN lane carries neither half of a visual contract.

## Proposed Remediation

**Preferred** (fix ONLY through the generation pipeline):
1. `plan`/`split` let a spec declare goldens per SKIN behavior — `golden: true` (every behavior the lane declares) or `golden: [W1, W2]` (the subset) in the `## Lanes` SKIN row — and mark the resolved rows with the ` [golden]` tag in `04-SKIN.md` (plus a `## Visual contract` section and a meta-index golden column); `gen` picks the gate up from the row WITHOUT the flag (the flag ORs in on top). Drift refuses at plan time: golden outside a SKIN lane, golden on a non-widget behavior, golden naming an id the lane does not declare.
2. `plan` proposes `adaptive_slots: [mobile, ios, android, macos]` for a SKIN lane with widget-kind behaviors and none declared, and warns "this skin has no visual contract" when the lane has neither slots nor goldens (guidance only — the spec stays the source of truth, exit stays 0).
3. The widget scaffold header mentions golden baselines ONLY when a `matchesGoldenFile` hook was actually emitted (`golden && !routeObserver`), so a hookless scaffold never promises a harness that does not exist. The gen staleness mirror renders the golden hook when the effective gate carries it, so a declared-golden pair re-gens idempotently instead of being stripped by the staleness rewrite.

**Alternatives** (optional):
- Warn-only grammar (no refusal on drift) — rejected: inert declarations are the silent-lie shape the lane contract refuses elsewhere.
- Auto-injecting slots at plan time — rejected: plan proposes, the spec declares; silent injection would break the declarations-win contract.

## Hard Constraints

- Fix ONLY through the generation pipeline; never hand-edit source the assessment says must stay pipeline-owned.
- One PR per bug.
