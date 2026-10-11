# Verification Audit: zfa-tdd-init-missing-flutter-app-deps (bug #1349)

Audit target: `.specify/bugs/zfa-tdd-init-missing-flutter-app-deps/`.
Full evidence (front-matter verdict, per-behavior table, gaps) lives in
`tdd/verification.md` — produced from this session's REAL runs; no
copied or back-dated evidence.

## Summary

- Verdict: **PASS_WITH_GAPS** (7/7 behaviors PROVEN; environmental gap
  documented)
- Red-first: 2 passed / 5 failed pre-fix → 7/7 post-fix
- Regression (changed-file protocol): 35/35 across the four init-flow
  neighbor suites
- `dart analyze` (changed files): No issues found!
- `dart format`: changed files clean; repo-wide dry-run 0 changed
- Gaps: no Flutter SDK in sandbox → no literal `flutter create` /
  `flutter test` repro; full suite deferred to CI per cloud protocol;
  single-session audit.

## Success criteria: PROVED vs NOT PROVED

PROVED (this session):

- init self-heals `zuraffa_flutter: ^6.0.0` + `get_it: ^9.2.1` under
  `dependencies:` on Flutter projects (green run + observed stdout)
- day-zero surface self-consistency (app.dart ↔ pubspec contract)
- idempotency and hand-edit preservation
- non-Flutter flow untouched (invariant green pre- and post-fix)
- loud failure on malformed pubspec (exit != 0, misfire naming)
- analysis + format gates clean

NOT PROVED (declared, not hidden):

- literal `flutter test` green run inside a real `flutter create`
  project (no Flutter SDK in this environment)
- full test suite (changed-file protocol; CI covers the remainder)
