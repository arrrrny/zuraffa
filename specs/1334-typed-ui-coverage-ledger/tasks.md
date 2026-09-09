# Tasks: 1334-typed-ui-coverage-ledger (issue #1143, extends #963 + #966)

**Input**: GitHub issue #1143 (sole input) · **Cycle**: red → green → refactor → verify
**Constraint**: only the ledger data model, the XRay overlay rendering, and the gate logic change; the 0966/075 legacy contracts and the finder taxonomy stay.

## Phase 1: Data model (MVP — the five-kind vocabulary)

- [x] T001 **RED** — Five kinds exactly + golden is a flag: `LedgerRowKind.values` ==
      5 with no `golden` value; a golden scenario yields `kind: presence` +
      `advisory: true` + per-platform tolerance; goldens never block the gate;
      the deck reports them ADVISORY (AC-1, AC-5 → FR-001, FR-002).
      Red: the shipped model has a sixth `golden` kind — the pin fails.
- [x] T001b **GREEN** — remove `LedgerRowKind.golden`; add `isGoldenScenario`;
      `fromScenario` auto-advisory; update 0966 subjects t6/t7/t8 to the
      five-kind contract (their 0966 FR-007 semantics — advisory, tolerance,
      never blocking — are preserved verbatim).

## Phase 2: Per-screen kind report + gate (the anti-gaming slice)

- [x] T002 **RED** — All five kinds per screen, zero-traced kinds are gaps: the
      gaming `/login` fixture (9 presence rows green, nothing else) renders
      `presence 9/9` + `absence 0/0` + `navigation 0/0` + `state 0/0` +
      `sequence 0/0`, every zero-traced kind is a gap, status
      `partially-traced` — not 100% (AC-2 → FR-003).
- [x] T002b **GREEN** — `screen` field, `kindCoverageAllKinds`,
      `groupByScreen`, `ScreenKindReport` (+ `status` — the planned
      `screenStatus` overlay member landed model-side as this getter).
- [x] T003 **RED** — The per-screen gate: the gaming ledger FAILS naming the
      four zero-traced kinds with fix hints; the honest five-kind `/login`
      PASSES `fully-traced`; `/deal_list` (fully traced) next to `/login`
      (gaming) distinguishes them (AC-2 → FR-004).
- [x] T003b **GREEN** — `TypedCoverageGate.evaluateScreens` +
      `TypedScreensVerdict` (aggregate, failure lines, encode, summary).

## Phase 3: XRay per-kind overlay

- [x] T004 **RED** — The overlay renders kind coverage per screen: status line
      + per-kind traced/total lines; zero-traced kinds HIGHLIGHT; the rendered
      view is per-kind, not a surface count (AC-3 → FR-005).
- [x] T004b **GREEN** — `XrayLedgerOverlay.renderScreen` / `renderByScreen`;
      doc-comment `paint`/`highlights` as the legacy surface-count view
      (kept for kindless ledgers only).

## Phase 4: Plan-time assignment + legacy mode (compatibility slice)

- [x] T005 **RED** — Plan-time kind assignment consumed verbatim: the verb
      matrix (hidden → absence, navigates → navigation, disabled → state,
      chain → sequence, render → presence) and an explicitly-kindled row
      survive derivation verbatim — never re-inferred (AC-4 → FR-006).
- [x] T005b **GREEN** — no production change expected (0966 seam holds); pin
      only.
- [x] T006 **RED** — Legacy mode: a 075-shaped ledger JSON (kind labels
      text/route/affordance/key, no typed kind) reads as presence rows +
      `legacy`; the gate is rows-only (all-green passes, one-red fails on the
      row gap only); a 0966-written ledger with `golden` rows reads as TYPED
      (reclassified presence + advisory) (AC-1, AC-6 → FR-007).
- [x] T006b **GREEN** — `TypedLedgerBuilder.fromLedgerJson` +
      `LedgerParseResult` (rows, legacy); `TypedCoverageVerdict.legacy` +
      rows-only `passed`; `evaluateScreens` legacy exemption.

## Phase 5: Strength pins + verification

- [x] T007 **RED→GREEN** — Strength pins (the T7/T8 remediation precedent):
      five-kind enumeration pin; per-screen report shape pins (status labels,
      0/0 entries, HIGHLIGHT polarity); legacy/typed classification pins;
      round-trip JSON pins (screen + advisory survive toJson → fromLedgerJson);
      `zeroTraced` vs `untraced` polarity pins.
- [x] T008 **REFRACTOR + VERIFY** — `dart format .` zero-diff; `dart analyze`
      (changed files) no new issues; run the 1334 + 0966 + 075 ledger test
      files (NOT the full suite — cloud budget); record ACTUAL pass/fail
      counts; mutation-style audit of the report/gate/overlay seams (deliberate
      mutation of the zero-traced predicate, the legacy classifier, the status
      polarity — each must be killed by a pin); `/speckit.tdd.verify` →
      `tdd/verification.md` from the real runs.

## Acceptance targets (from the issue)

- [x] AC-1: typed rows carry one of exactly five kinds; presence-only rows
      reclassified presence — T001.
- [x] AC-2: zero-traced kinds are per-screen gaps; presence-only screen =
      partially traced, not 100%; gate fails the gaming ledger — T002, T003.
- [x] AC-3: XRay overlay renders per-kind coverage per screen; surface-count
      view legacy-only — T004.
- [x] AC-4: plan-time kind assignment consumed verbatim — T005.
- [x] AC-5: golden advisory (presence + advisory:true + tolerance), out of the
      merge gate — T001.
- [x] AC-6: legacy ledgers rows-only, gate does not break existing projects —
      T006.
