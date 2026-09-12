# TDD Verification — Spec 1513 — Verdict: PASS (2026-09-12)

- Test-first: red evidence precedes the fix commit (`WIP:
  sdd-artifacts-and-red` → `feat(1513)`). Red shape: load errors on the
  missing API surface (`flutterTest` param, `packageSubjectImportFor`) +
  an honest assertion red at command level (B7a reproduces #1513's
  `package:test` emission through `zfa tdd plan` + `zfa tdd gen
  contract:A1` on a flutter-dependency fixture).
- Suite: new suites `+10` and `+2` all passed; neighbor suites
  (`contract_kind_1007`, `bug_1443`, `bug_1363`, `bug_1458`, `gen_command`,
  `gen_namespacing_827`, `bug_912`) all green — 37 neighbor tests total.
  `dart analyze` clean on all touched files; `dart format` clean.
- Mutation sampling: M1 threading removal → B7a red (killed); M2 default
  drift → B8 byte-for-byte golden (guarded by construction).
- AC coverage: SC-1→B1/B2, SC-2→B4/B5/B6, SC-3→B7, SC-4→B3, SC-5→B8,
  SC-6→B1..B7 collectively.
- Constraint audit: touch surface = `contract_test_writer.dart` (imports),
  `behavior_test_writer.dart` (visibility promotion only — logic unchanged),
  `gen_command.dart` (one branch, flag threading). Unit/acceptance lanes,
  state machine, loop semantics: untouched (neighbor suites prove it).
- Note: a real-Flutter-host `flutter test` execution is out of scope for
  this environment (pure-Dart root, no Flutter SDK per
  `.specify/memory/tdd-profile.md`); the Flutter-host import surface is
  pinned at the emitted-source level (B1, B7a) — the same fast tier the
  #1351 fix used.
