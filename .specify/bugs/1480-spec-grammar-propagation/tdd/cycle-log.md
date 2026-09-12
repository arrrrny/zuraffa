# TDD Cycle Log: 1480-spec-grammar-propagation

**Engine**: raw (LLM-guided fallback loop — ZFA_MISSING in this environment)
**Started**: 2026-09-10T22:53:00Z
**Completed**: 2026-09-11T00:30:00Z (UTC+8 session time)

---

## Baseline

- date: 2026-09-10T22:53:00Z
- command: targeted suites (`test/cli/writers/tdd/`, `test/plugins/tdd/commands/`, `test/plugins/tdd/services/`)
- result: baseline suites green before any fix code; the ONLY failures in the RED run were the new #1480 tests

---

## U1+A1 — plan reads the mapping from contracts/*.md (declared routing)

### RED

- date: 2026-09-10T23:0x
- test: `test/plugins/tdd/commands/plan_contracts_decoupled_1480_test.dart` (4 tests)
- observed: 4 failures — `contracts/*.md` rows and criterion traces were not consulted; U1 fallback-routed (`[fallback: legacy description classifier matched — trace FR to a declared contract row]`) and U5a/U5b double declarations were silently ignored
- evidence: RED run transcript, "00:00 +0 -4: Some tests failed."

### GREEN

- change: `plan_command.dart` globs `contracts/*.md` (sorted), merges parsed rows (duplicate name across sources → StateError → exit 2), merges criterion-keyed traces (`SpecParser.parseCriterionContractTraces`) into the unit-id-keyed map; double-declared traces refuse; unknown-FR criterion traces warn (parity with #1319)
- result: 4/4 pass — `00:00 +4: All tests passed!` (final state, after fixture correction: the test's own fixture had an untraced FR-002; the gate was RIGHT to refuse it)

---

## U2+A2 — plan fails fast on unit-lane fallback

### RED

- test: `test/plugins/tdd/commands/plan_unit_fallback_fail_fast_1480_test.dart`
- observed: 4 failures — all-fallback spec planned exit 0 (the bug), the `--allow-unit-fallback` flag did not exist, partial-trace refusal did not exist
- evidence: RED run transcript, "00:00 +1 -4"

### GREEN

- change: `plan_command.dart` — after the strict gate, unit-kind entries in `provenance.fallbackKinds` (minus persistence-marked behaviors, which take the harness-backed #833 path) refuse with exit 1, exitClass `unit-fallback-refused`, per-behavior `route:` lines naming `U<n>` + FR, the three-outs fix line, no artifacts, no spec mutation; new `--allow-unit-fallback` flag
- result: 5/5 pass (U2c — fully-traced spec green — passed in both phases, pinning the unaffected contract)

---

## U3+A3 — template propagation at wiring time

### RED

- test: `test/cli/writers/tdd/spec_template_writer_test.dart`
- observed: COMPILE failure — `SpecTemplateWriter` / `SpecTemplateWriteAction` / `kZuraffaSpecTemplate` did not exist ("Couldn't find constructor 'SpecTemplateWriter'"). A missing symbol is the honest red for a missing module.
- evidence: RED run transcript

### GREEN

- change: new `lib/src/cli/writers/tdd/spec_template_writer.dart` (embedded byte-exact zuraffa-1.0 template; absent → created; grammarless → replaced; pinned → untouched) + `init_command.dart` wiring with loud created/REPLACED/already-current output lines
- result: 5/5 pass including the end-to-end `zfa tdd init` check

---

## U4/U5 — refusal/warning edges

- tests: inside the two plan files above (unknown-FR warning U1b; duplicate-row U5a; double-trace U5b)
- result: pass (part of the 4/4 and 5/5 above)

---

## Final suite state (targeted, this session)

| Suite | Result |
|-------|--------|
| test/cli/writers/tdd/spec_template_writer_test.dart | 5/5 |
| test/plugins/tdd/commands/plan_contracts_decoupled_1480_test.dart | 4/4 |
| test/plugins/tdd/commands/plan_unit_fallback_fail_fast_1480_test.dart | 5/5 |
| test/plugins/tdd/services/ | 804/804 |
| test/plugins/tdd/commands/ (64 files, triaged) | all pass (legacy fixtures updated to the #1480 contract or the escape hatch where the fallback itself is the subject) |
| root-level plan-adjacent files (846/919/993/1183/1140/1320/1308/1141/func/gen/wire/runner/suites) | all pass in chunked runs |

- post-run kernel cache cleaned between chunks (`rm -rf .dart_tool/test/` + `$TMPDIR/dart_test.kernel.*`); disk stayed ≥ 13% free after the two full-disk incidents (100% → cleaned → 13%).
- `dart analyze` on all changed files: No issues found.
- `dart format`: 0 remaining diffs on all changed files (two pre-existing unformatted files on master — `tool/generate_openwiki_cli_docs.dart`, `example/test/tdd/004-login-ui/u1_test.dart` — reverted out of scope).
