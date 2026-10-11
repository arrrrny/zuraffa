# Issue #1271 — zfa tdd run: widget-lane behaviors stall engine lane instead of being deferred to skin lane

- **Severity**: high
- **State**: open (GitHub issue #1271, filed by ahmettok during apps/login_demo spec 001-login-ui build)
- **Slug**: tdd-run-widget-lane-stalls-engine

## Bug Report

**Repro:**
```bash
cd apps/my_app
flutter pub add shadcn_ui   # needed for widget lane
zfa tdd run 001-my-feature
```

**Expected:** Engine lane runs through gen → verify-red → make → refactor for each behavior, then skin lane runs the widget behaviors.

**Actual:** The engine lane stops at the first widget-lane behavior (e.g. A1) because:
1. Engine lane processes CORE + BOTH behaviors (which is correct), but
2. The runner's "BOTH" bucket currently routes widget-kind behaviors through the engine lane when they should be deferred to the skin lane.
3. The verify-red step on the widget subjects sees them as already green (because the implementation was already in place), then refuses with `not-certified-red` because there's no red history.

```
[run] A1 gen -> ok
[run] A1 verify-red -> unexpected-green
[run] A1 verify-red -> skipped (already green)
[run] A1 make -> not-certified-red
```

**Root cause:** The runner is treating widget-kind behaviors as engine-lane work. Per spec 1008 (two-cycle runner), widget-lane behaviors should be routed to `run-skin` and only run after a green engine receipt.

**Suggested fix:** When `zfa tdd run` encounters a widget-kind behavior while driving the engine lane, it should mark the behavior `pending`, skip the engine steps, and queue it for the skin lane. Currently it stalls the whole run.

**Secondary observation:** Acceptance-lane behaviors that zfa considers `unexpressible` (e.g. A5 — "Apple+Google+divider+Anonymous buttons render on iOS/macOS") are skipped with `make -> skipped` / `refactor -> deferred (phase 2)`. That's fine in isolation, but it leaves 8 of 13 behaviors with `done=0` and the journal reads as a failure even though the tests are green.

**Workaround used:** Implemented the widget subjects directly in `lib/tdd/<feature>/a*_subject.dart` so the widget tests pass without needing the runner to drive them. Ran `flutter test test/tdd/<feature>/` to verify all 13 behaviors are green.

Filed by: ahmettok during apps/login_demo spec 001-login-ui build.
