# TDD Verification — Spec 1393 — Verdict: PASS (2026-09-11)

- **Test-first**: the red commit order holds — the pin suite ran red
  (`+1 -3`) against the shipped fixture BEFORE the re-split, and the issue's
  engine stop was reproduced verbatim (`A1/A2 make -> unexpressible`,
  `U1 make -> vacuous-green`, `stopped_at=U1:make`) before any edit.
- **Suite (green)**:
  - Pin suite `bug_1393_fixture_lane_pin_test.dart`: **+4 All tests passed!**
  - New fixture gen pairs (a1/a2/u2): **+3 All tests passed!** (flutter test,
    example package)
  - Skin conformance W1 view test: **+1 All tests passed!** (unaffected)
- **Engine half green unattended (the epic deliverable)**:
  `example/specs/004-login-ui/tdd/04-engine-receipt.json` —
  `verdict: "green"`, `result: "complete"`, `stopped_at: null`,
  `counts: {total: 3, pending: 0, red: 0, green: 0, done: 3}`.
  No hand edits to any subject or test: U2 implemented by the `tdd func`
  scaffold from its declared scalar-return contract; A1/A2 implemented by
  `zfa tdd compose` against the green U2 anchor (spec 052); refactor passes
  `applied=1` per behavior with the issue #922 baseline-tolerant re-proof.
- **Routing proof**: the regenerated engine plan's provenance names
  `route: U2 -> unit lane (func surface) [declared: contract row:
  LoginValidation]`; U1 no longer appears in `04-ENGINE.md` — the fallback /
  legacy-classifier path is gone for the engine lane.
- **Honest scope notes**:
  - The malformed Skin Contract yaml named in #1393 was **already repaired
    on master** (spec 1377 recorded the repair); this fix's B3 pin guards it
    with the strict production parser. PROVED by the pin.
  - The skin lane of the meta run stops at `U1:make` — the DESIGNED
    vacuous-green hand-delta seam for a view-presentation behavior (issues
    #1259/#1308; spec 1377 locked decision 4). The engine half is the epic's
    exit criterion 4 and is green; the skin half's hand seam is the #1005
    hand-written-seam contract, unchanged by this fix.
  - Transient `resource-limit` kills (sandbox RAM ceiling) interrupted some
    make/refactor children during verification; each was recovered through
    the tool's own classified outcomes and the resumable write-ahead journal
    (bug #828) — zero hand edits, zero state forgery; the final drive
    completed cleanly under a native zfa binary.
  - Pre-existing (unrelated, flagged, not touched): `dart format .` reports a
    formatting diff in `tool/generate_openwiki_cli_docs.dart` on master;
    `flutter analyze example` reports 8 pre-existing infos in committed
    fixture files (a7_test, u1_test import style). Neither is caused by this
    fix; this fix's files analyze clean and are format-clean.
- **AC coverage**: AS-1→B1/B4, AS-2→B2, AS-3→B5/receipt, AS-5(US2)→B3;
  SC-001 pins 4/4, SC-002 receipt green done 3/3, SC-003 analyze+format
  clean on all changed files.
