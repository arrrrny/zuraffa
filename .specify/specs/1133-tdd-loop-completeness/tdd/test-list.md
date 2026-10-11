# TDD test list — EPIC 1133 (epic-closing lane: re-verify the four exit criteria on current master)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| E-1133-1 | example/test/tdd/004-login-ui/a4_test.dart | widget | AC-4 asserts a REAL route outcome — regenerated this session via `zfa tdd gen A4 --widget-shell materialapp` (hermetic copy): `scenario-assertions: route-outcome("deal_list")`, `expect(observer.pushedNames, contains('deal_list'))` via the recording NavigatorObserver, never `find.text` | exit criterion 1 | GREEN (re-proved) |
| E-1133-2 | example/test/tdd/004-login-ui/a5_test.dart | widget | the hides scenario carries a `findsNothing` — regenerated this session: `scenario-assertions: absence("t.auth.error")`, `expect(find.text(t.auth.error), findsNothing)` + the `find.byWidget(view)` mount guard | exit criterion 2 | GREEN (re-proved) |
| E-1133-3 | example/specs/004-login-ui/tdd/verification.md | audit | `zfa tdd verify --feature 004-login-ui` — full real run (preflight over the registry's 10 behaviors + mutation audit + restoration); fresh verification.md reports all 5 behavior kinds: presence=2 absence=1 route-outcome=2 enabled-state=1 sequence=1 | exit criterion 3 | RAN (gate fail_survived, 58/9/0, score 0.8657) |
| E-1133-4 | example/test/tdd/004-login-ui/a3_test.dart (+a7) | widget | LocaleTests resolve keys (slang shell `LocaleSettings.setLocaleRaw`, `find.text(t.auth.signIn)` on RESOLVED keys) and the German expansion pump passes — de strings at 318–364% of the EN anchors (≥130% bar), layout holds | exit criterion 4 | GREEN (re-proved) |
| U-1133-5 | example/test/tdd/004-login-ui/u1_test.dart | unit | U1 (FR-001, adaptive_layouts) — the #1393 re-split left the SKIN lane's preflight red (`gate: preflight_red` on current master); this lane greens the subject (the Skin Contract's declared `adaptive_slots`, in declared order) so the verify preflight passes | #1393 debt / epic unblock | RED → GREEN (this session) |

## Red evidence (this session, pre-fix)

`zfa tdd verify --feature 004-login-ui` on pristine master:

```
gate: preflight_red
killed: 0 survived: 0 mutation_was_run: false
```

Per-behavior preflight stopped at `test/tdd/004-login-ui/u1_test.dart`:
`Expected: not <Instance of 'UnimplementedError'>` /
`Actual: UnimplementedError: subject_u1 not implemented` — the U1 red
(cycle-log entry `Cycle: U1 (red)`, 2026-09-11).

## Green evidence (this session)

```
flutter test test/tdd/004-login-ui/u1_test.dart --plain-name "U1 — …"
00:00 +1: All tests passed!
```

Hash-chained as `Cycle: U1 (green)` in
`example/specs/004-login-ui/tdd/cycle-log.md` (prev-hash =
4d5b2725c7d8cffe3e884d33c20ec154404fb346ae280c0cd7dc512c2061c1d3, the
U1 red link; subject-hash
7fec953024346518ac18e36f21e03145bb3a33c3ccbab7f7ca198aaa179c88e2).

## Full-suite green (this session, real run)

```
flutter test <the 10 registered 004-login-ui test files>
00:05 +12: All tests passed!
```
