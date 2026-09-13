# TDD Verification — Spec 1388 — Verdict: PASS (2026-09-13)

- Test-first: red commit (`ca7b4aaf` — SDD artifacts + regression suite)
  precedes the fix. Red evidence (pre-fix run of
  `issue_1388_gen_reuse_fingerprint_test.dart`): **+3 −3** —
  - U2 red: `verdict=reused` with the `zfa:tdd: guard-only` warning on
    the no-signature traces migration (the issue's exact transcript);
  - U3 red: exit 0 / no refusal for the drifted progressed pair;
  - U4 red: `gen_fingerprint` absent from the created record;
  U1/U5/U6 green pre-fix by design (they pin the #1320 signature path
  and the FR-006 reuse idempotency the fix must not break).
- Post-fix suite: **+6 All tests passed!** (`dart test
  test/plugins/tdd/commands/issue_1388_gen_reuse_fingerprint_test.dart`).
- Touched-area suites (fast tier): artifact_record (+10), artifact_registry
  (+15), bug_912 migrate-paths (+4), bug_1320 / bug_1377 / issue_1309 /
  bug_1518 gen-neighbourhood (+50 combined), tdd services folder (+968).
- Slow tier (tier `slow`, run explicitly): bug_1397 (+10), bug_1380 (+3),
  gen_command_test **+17 −1** — the −1 (`bug #871` pure-description echo)
  fails IDENTICALLY on unpatched master (verified via stash) — a
  pre-existing master failure, not a regression of this change.
- Analyze: `dart analyze` on every changed file — no issues; whole
  package 112 info-level findings == master baseline, **0 warnings,
  0 errors** (no new warnings).
- Format: `dart format` applied to the 3 files the formatter wanted;
  all 6 touched files format-clean.
- AC coverage: AS-1→U1, AS-2→U2, AS-3→U3, AS-4→U5, AS-5→U6; FR-1→U4;
  SC-001→U1+U2, SC-002→the analyze/suite results above.
- Honest scope note: the no-signature migration's regenerated pair stays
  the guard-only SHAPE (no declared signature resolves — the #1420
  class, out of scope per the hard constraints); what #1388 fixes is the
  reuse VERDICT + fingerprint invalidation + the named escape hatch, not
  the rendered assertion surface. The progressed-subject guard keys on
  the subject carrying no `UnimplementedError` at all (pre-existing #683
  semantics, unchanged).
