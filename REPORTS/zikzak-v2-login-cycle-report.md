# zik_zak_v2 Login — Full zfa TDD Cycle Report (2026-09-09)

Real-world validation of the zfa TDD two-lane runner by rebuilding the ZikZak
login screen from scratch (`~/Developer/zik_zak_v2`, fresh `zfa setup
--platforms=ios,android,macos` + `zfa tdd init`). zfa v6.2.2 @ 27644a49
(latest master, rebuilt via `scripts/rebuild.sh`).

## Result

```text
status: feature=login engine=green skin=green
login | engine ✅ 9/9 | skin ✅ 9/9 (macOS) | mocks 0/0 certified
```

- 9 CORE behaviors (A1–A3 acceptance, U1–U6 unit) — green, receipts written.
- 9 SKIN behaviors (W1–W9) — green, receipts written.
- `zfa tdd run login` → `result=complete pending=0 red=0 done=18`.
- Live macOS app running in herdr pane `wD:p5` (`flutter run -d macos`,
  VM service `http://127.0.0.1:65308/...`); window screenshot verified against
  the reference design (gradient, centered 450-wide card, brand, Sign In
  block, Apple/Google buttons, or divider, Guest outline, theme colors).

## Misfires filed this cycle

| Issue | What happened | Workaround used |
| ----- | ------------- | --------------- |
| [#1405](https://github.com/arrrrny/zuraffa/issues/1405) | Skin-plan author emitted a malformed outer-loop table: 9 behavior rows whose `id` column held sentence fragments (`W1 (renders the login screen pixel-perfect on macOS with the brand gradient`, `a full-width guest outline button`, `an or divider`); only one row kept a valid `W2` id → 8 of 9 skin behaviors machine-unreachable, `status` silently reported `skin ❌ 0/1` | Hand-rewrote the `## Outer loop` table with clean `W1..W9` ids (prose moved to the behavior column); also fixed the platform-contract row to `W1, W2, ..., W9`; re-ran `zfa tdd gen` per behavior |
| [#1407](https://github.com/arrrrny/zuraffa/issues/1407) | `make` refuses with `generation-error` on `dart analyze` **0 errors + 1 warning**; the warning was a pre-existing engine-lane unused import that the engine lane's green receipt had accepted — cross-lane coupling. W4–W8 `make`d fine because the skip transition skips the analyze gate (inconsistent strictness within one run) | Removed the two unused imports (`w2_subject.dart`, `u1_test.dart`), re-made W3/W9 |
| [#1408](https://github.com/arrrrny/zuraffa/pull/1408) (docs PR) | Guide §8 extended with items 7–12 from this cycle | — |

## Hand-step gotchas (beyond #1373's placeholder swap — all now in guide §8)

1. **Clean assertion before first interaction.** Against the inert stub,
   `tester.tap` / `tester.widget` throw runner-errors and verify-red refuses
   (`classification: runner-error`). Open interaction tests with presence
   `expect`s so red certifies as `assertion`. Hit on W2 and W6.
2. **Decoration wrapper.** Assert
   `decoration is BoxDecoration && decoration.gradient is LinearGradient` —
   a bare `decoration is LinearGradient` predicate finds nothing (W3).
3. **pumpWidget State reuse.** Pumping a stub view then pumping
   `LoginView(controller:)` with same runtimeType + no key reuses the State —
   `initState` never re-runs, injected controller ignored, the tap drives the
   subject's simulated chain (W9: `hasError=false` after settle).
4. **Zero-delay throws race the first frame.** Delay the throw ~50 ms for
   deterministic mid-flight overlay/disabled assertions (W9).
5. **Test viewport vs card size.** The error box overflows the card by 20 px
   on the default 800×600 test surface — set
   `tester.view.physicalSize = Size(800, 900)` in the W9 test.

## Key files (zik_zak_v2)

- `specs/login/spec.md` — 18 behaviors, skin contract (`adaptive_slots:
  [macos]`, states idle/loading/error, route home → `HomeScreen` `/home`).
- `lib/src/presentation/views/login/login_view.dart` — pixel-for-pixel port
  of the reference `login_macos_layout.dart` (ZfaButton for Apple/Google,
  ShadButton.outline for Guest, loading overlay keyed
  `login_loading_overlay`, destructive error box).
- `lib/src/presentation/theme/app_theme.dart` — ZikZak light theme (kGreen
  0xFF00d52f primary, kBlueberry 0xFF3e3276 foreground, Axiforma family) —
  verbatim from zik_zak `lib/main.dart`.
- `lib/main.dart` — `ZuraffaApp` + `zuraffa_ui` mounting `LoginView`.
- `test/tdd/login/w1..w9_test.dart` + `lib/tdd/login/w1..w9_subject.dart` —
  scenario assertions hand-authored; subjects return the real view.

## Repo state

- `zik_zak_v2` had no git repo (fresh `zfa setup` doesn't init one) —
  initialized locally and committed everything (237 files). **No GitHub
  remote exists yet** (`arrrrny/zik_zak_v2` not found) — create it and push
  when ready.
- zuraffa: branch `docs/guide-skin-cycle-gotchas-2` → PR #1408 (guide §8
  items 7–12).

## How to continue (next layers)

1. Merge PR #1408; fix #1405/#1407 upstream so the next skin cycle runs
   without hand rewrites.
2. Build the next spec on top of login the same way (home/deal-list): declare
   `adaptive_slots`, author the skin plan, check the outer-loop ids against
   `^W\d+$` immediately after `zfa tdd plan`, then run the cycle.
3. When the app grows a real auth provider, replace `SimulatedAuthDataSource`
   and wire DI (`lib/src/di/index.dart` is still the empty bootstrap).
4. Re-verify visually after each layer: herdr pane `wD:p5` (hot restart `R`,
   not `r`, after `main()` changes), `screencapture -l <windowid>` via the
   swift CoreGraphics window-list snippet (System Events accessibility is
   denied for osascript on this box).
