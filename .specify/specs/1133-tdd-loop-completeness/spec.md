# 1133-tdd-loop-completeness

- **Spec ID**: 1133-tdd-loop-completeness
- **Created**: 2026-09-18 (epic record consolidated; the lanes merged 2026-09-05..2026-09-09)
- **Source**: GitHub issue #1133 — EPIC 2: TDD Loop Completeness — The Referee Knows What It's Watching (priority high)
- **Type**: epic certification (4 sub-issue lanes, one PR per lane, epic closes only when all four exit criteria pass)
- **Branch**: feat/1133-tdd-loop-completeness (epic-closing lane)
- **Related**: #964 (finder-kind taxonomy, closed via #1216), #965 (i18n-keyed widget contracts, closed via #1047/#1209), #966 (typed ledger rows, closed via #1048/#1362), #1376 (verify kind trace, closed via #1396), #1219 (the epic corpus PR), #959 (honest red), #1393 (the U1 re-split that this lane re-greens), #1140/#1141/#1143 (the issue-tracker views of lanes 1–3)

## Problem

The TDD loop's referee certified scenarios it did not actually watch:

- The widget lane derived only `find.text` from quoted literals — a
  scenario asserting *"navigates to the route `deal_list`"* was certified
  green by `expect(find.text('deal_list'), findsOneWidget)`: a static
  `Column` of `Text` widgets satisfied it while navigating nowhere.
- Production views rendered through slang keys (`t.auth.signIn`) while
  generated tests pinned EN literals — a copy edit broke green for the
  wrong reason, and a missing key could not fail red.
- The coverage ledger counted presence only — absence ("the banner is
  not shown"), widget state ("the button is disabled"), and sequences
  ("while in flight … then navigates") were inexpressible as ledger rows.
- `verify-red` certified honest reds but never checked whether the KIND
  of red matched the scenario's verb — a presence red certified a
  navigation scenario.

## Sub-issue lanes (the deliverables)

1. **Finder-kind taxonomy** — #964: scenario verbs map to
  machine-certified assertion kinds
  (`shows`→presence, `hides/not shown`→absence, `navigates`→route-outcome,
  `disables`→enabled-state, `while/sequence`→interaction-chain). Landed in
  `lib/src/plugins/tdd/services/finder_taxonomy.dart`
  (`ScenarioAssertionClass`, `LiteralKind`, `ScenarioAssertion`) — PR #1216.
2. **i18n-keyed widget contracts** — #965: spec rows declare
  `key: auth.signIn` with the EN literal as anchor; the generated view
  emits `t.auth.signIn`; the generated test boots the slang shell
  (`LocaleSettings.setLocaleRaw`) and asserts RESOLVED keys. Landed in
  `lib/src/plugins/tdd/services/i18n_key_contract.dart` +
  `ui_ledger_projection.dart` (the `UiViewAudit` localization gate) —
  PRs #1047/#1209.
3. **Typed ledger rows** — #966: `absent:` first-class, `state:` for
  enabled/disabled/loading, sequences as act→assert→resolve→assert
  chains; every ledger row carries a kind, not just a presence flag
  (`ui-ledger.json` / `ui-ledger.md`) — PRs #1048/#1362.
4. **verify-red kind-match** — the red classifier refuses to certify a
  finder whose assertion kind does not match the scenario verb
  (`RedClassification.kindMismatch`, `_certifyFinderKinds` in
  `verify_red_command.dart`, composing with #959's honest-red gate) —
  PR #1219.

## Exit criteria (issue #1133)

1. 004-login-ui regenerated: AC-4 (`navigates to deal_list`) asserts a
   real route outcome, not a Text widget.
2. A `findsNothing` assertion appears for `hides` scenarios.
3. `zfa tdd verify` on 004-login-ui shows all 5 behavior kinds traced.
4. LocaleTests resolve keys, and a German-pump shows layout holds at
   130% string length.

## Hard constraints

- One PR per sub-issue lane; the epic advances via incremental merges
  and closes only when ALL four exit criteria pass.
- Do NOT change existing `tdd run` semantics.
- `tdd/verification.md` must be produced from the REAL run in the
  closing session — never copied, stubbed, or back-dated.
- The audit's mutation scope is the registry's honest scope (all
  registered subjects); survivors are reported with remediation hints,
  never silenced.

## Session findings (2026-09-18, the epic-closing lane)

- The four lanes were already merged (sub-issues closed); the epic
  remained open because no closing PR re-proved the criteria on current
  master.
- **Regression found and fixed**: `zfa tdd verify --feature 004-login-ui`
  died at `gate: preflight_red` — the #1393 re-split moved U1
  (FR-001, adaptive_layouts) to the SKIN lane but its green never
  landed, so the registry's 10-behavior preflight failed at
  `test/tdd/004-login-ui/u1_test.dart`. This lane greens U1 (the Skin
  Contract's declared `adaptive_slots`, in declared order) with the
  honest red→green cycle hash-chained in
  `example/specs/004-login-ui/tdd/cycle-log.md`.
- With U1 green, the full real audit ran to completion (this session)
  and all four exit criteria pass — see `tdd/verification.md` in this
  directory and `example/specs/004-login-ui/tdd/verification.md`
  (generated fresh by the run).
