# Plan: 1133-tdd-loop-completeness

- **Spec ID**: 1133-tdd-loop-completeness
- **Created**: 2026-09-18

## Technical Context

- **Lane 1 — the taxonomy** (`lib/src/plugins/tdd/services/finder_taxonomy.dart`):
  `ScenarioAssertionClass` enumerates the five assertion semantics
  (presence / absence / routeOutcome / enabledState / sequence), each with
  its kebab-case `label` — the token the generated test's machine-readable
  `// scenario-assertions:` header carries. `LiteralKind` classifies a
  quoted literal (text / route / key / label): route literals are asserted
  through a recording `NavigatorObserver` (`pushedNames`), never as
  on-screen text; key literals resolve through the slang shell. Sequence
  scenarios are marked scaffolded rather than silently flattened to
  presence — the single-pump template cannot honestly assert a state
  machine.
- **Lane 2 — the i18n contract**
  (`lib/src/plugins/tdd/services/i18n_key_contract.dart`,
  `ui_ledger_projection.dart`): spec Presentation rows declare
  `key: auth.signIn -> 'Sign in'`; the view-side audit
  (`UiViewAudit`, run by `zfa tdd view` BEFORE any write) refuses a
  declared anchor rendered as a quoted literal on a keyed host — the key
  is the contract, the accessor `t.<key>` is code identity. The generated
  widget tests boot the slang shell (`LocaleSettings.setLocaleRaw('en')`)
  and assert `find.text(t.auth.signIn)`; the optional
  `--i18n-expansion de` tier re-asserts every keyed surface under the
  expansion locale.
- **Lane 3 — the typed ledger** (`ui-ledger.json` / `ui-ledger.md`
  projection): every row carries a kind (presence / absence / route
  outcome / enabled-state / sequence), `absent:` and `state:` are
  first-class row shapes, and sequence rows are act→assert→resolve→assert
  chains. The ledger is PARSED, never re-derived from prose — the gaming
  view cannot re-label a row to dodge a kind gap.
- **Lane 4 — the verify-red kind gate** (`verify_red_command.dart`,
  `_certifyFinderKinds`): BEFORE evidence is accepted, the test's
  assertion kinds must match the scenario's required kinds; a mismatch is
  classified `RedClassification.kindMismatch` and refused (no evidence
  appended), composing with #959's honest-red classification.
- **The kind trace** (`behavior_kind_trace.dart`, #1376): `zfa tdd verify`
  parses the `// scenario-assertions:` headers of the registered tests
  and reports the per-behavior kind trace — additive reporting, no gate
  semantics, unknown tokens degrade to `not-traced` with the raw token
  preserved.
- **The registry** (`specs/<feature>/tdd/artifacts.json`): gen/compose
  register every behavior pair; `MutationScope.derive` reads it for the
  verify's preflight + mutation scope; `CycleLog` chains the red/green
  evidence per behavior (sha256 over the canonical 9-field payload,
  prev-hash per behavior chain).
- **The #1393 re-split**: U1 (FR-001, adaptive_layouts) moved from CORE to
  SKIN; the engine half (A1/A2/U2) completed green unattended, U1's green
  was deferred to the skin work — leaving the registry's preflight red at
  `u1_test.dart` (found this session; the re-green is this lane's code
  change).

## Remediation (this lane — the epic close)

- `example/lib/tdd/004-login-ui/u1_subject.dart`: replace the
  unimplemented stub with the declared platform slots
  (`List<String> subject_u1() => const ['mobile','ios','android','macos']`
  — the Skin Contract's `adaptive_slots` in declared order; the W1
  hand-written seam renders the same declaration as the live view, U1 is
  its unit-side declaration surface).
- `example/specs/004-login-ui/tdd/cycle-log.md`: append the U1 green
  cycle through the repo's own `CycleLog` machinery (per-behavior hash
  chain onto the #1393 red entry).
- `example/specs/004-login-ui/tdd/verification.md`: regenerated fresh by
  `zfa tdd verify --feature 004-login-ui` in this session (real mutation
  audit).
- `.specify/specs/1133-tdd-loop-completeness/{spec,plan}.md` + `tdd/`:
  the epic record the issue's workflow requires, committed with this
  lane's evidence.
- Root `tdd/{test-list,verification}.md`: this lane's session artifacts
  (the repo's per-lane working directory convention).

## Verification plan (all four exit criteria, REAL runs)

1. **AC-4 route outcome, regenerated**: re-run `zfa tdd gen A4` (hermetic
   temp copy, `--widget-shell materialapp`) and confirm the emitted test
   carries `// scenario-assertions: route-outcome("deal_list")` and
   asserts `observer.pushedNames contains 'deal_list'` via the recording
   `NavigatorObserver` — never `find.text('deal_list')`. Committed test
   diff is cosmetic only (dart format + a template comment rename).
2. **findsNothing for hides, regenerated**: same hermetic re-gen of A5 —
   `scenario-assertions: absence("t.auth.error")`,
   `expect(find.text(t.auth.error), findsNothing)`, plus the
   `find.byWidget(view)` mount guard that keeps the absence honest.
3. **All 5 kinds traced**: `zfa tdd verify --feature 004-login-ui` runs
   the full audit (preflight over the registry's 10 behaviors + the
   mutation audit + restoration) and the fresh verification.md reports
   `presence=2 absence=1 route-outcome=2 enabled-state=1 sequence=1`.
4. **LocaleTests + German pump**: A3/A5/A7 run green under
   `flutter test` — the tests resolve keys through the slang shell
   (`t.auth.signIn`, `t.auth.error`, `t.auth.working`), and the `de`
   expansion pumps pass with German strings at 318–364% of the EN anchor
   length (comfortably over the 130% bar), layout holding (pumpAndSettle
   clean).

## Honest evidence policy

- The mutation gate is `fail_survived`: 58 killed / 9 survived
  (score 0.8657). The 8 baseline survivors are the previously documented
  W1 view gaps + A-lane equivalent-class mutants (unchanged since the
  Sep-9 evidence); the 9th (`u1_subject.dart:31`) is this lane's
  slot-literal content mutant — unobservable by the type-level U1 test,
  reported with its remediation hint, never silenced.
- `dart run mutation_test` exit 0, restoration_verified: true over all
  10 registered subjects (FR-021), spec/subject hashes bound (FR-020).
