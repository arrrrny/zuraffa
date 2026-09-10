# Verification: 1485-tdd-plan-read-contracts-directory

**Verdict**: PASS

**Date**: 2026-09-11 | **Auditor**: spec-whole tdd-verify (cloud agent — only
tests for code changed in this feature were run, per the cloud-agent scope
rule)

## Phase 1 — Test-first evidence

| Behavior | Red evidence | Green evidence |
| -------- | ------------ | -------------- |
| A-1485-1 | RED pre-fix: plan emits no `declared rows:` lines for a populated `contracts/` directory (the directory is never read — `corpus_catalog.dart:183` recognizes the name only) | GREEN: `declared rows: 4 from contracts/task-store.md` + `declared rows: 3 from contracts/data-layer.md` printed; exit 0 |
| A-1485-2 | RED pre-fix: the route provenance shows `route: U1 -> refused [danglingReference: behavior "U1" traces to "task-store.Create", which names no declared contract row]` — the exact issue repro | GREEN: `route: U1 -> unit lane` (declared through the contract-file row), no refusal; the traces cell carries `task-store.Create` into the test list |
| A-1485-3 | green-first characterization pin (a feature with no `contracts/` directory must not grow new output) | GREEN pre- and post-fix: no `declared rows:` / no `contracts` mention; byte-equivalent output contract |
| A-1485-4 | RED pre-fix: an empty or prose-only `contracts/` directory plans silently | GREEN: `WARNING — specs/1485-todo/contracts exists but no declared rows were extracted (…)` printed; plan still exits 0 |
| U-1485-1 | RED pre-fix: `SpecParser.parseContractFileRows` did not exist (compile-level red: member-not-found on the new API) | GREEN: operations/method tables yield one row per data row (kind function, 1-based in-file spec lines); `| Method |` header shape equivalent |
| U-1485-2 | RED pre-fix: same compile-level red | GREEN: Signature column binds parsed signatures; signature-first tables name rows by method; prose cells dropped; malformed signature-shaped cells carried raw |
| U-1485-3 | RED pre-fix: same compile-level red | GREEN: interface bullets, pure signature bullets, scoped prose-tolerant bullets, fenced blocks declare nothing, prose-only documents yield nothing |
| U-1485-4 | RED pre-fix: same compile-level red | GREEN: merge supplements spec.md rows; contract-file version wins the collision (bare + alias keys); spec.md-only input matches the legacy map |
| U-1485-5 | RED pre-fix: `DeclaredRouting.contractFiles` did not exist (compile-level red) | GREEN: `contracts/*.md` enumerated sorted; non-md ignored; missing directory → empty list |
| U-1485-6 | RED pre-fix: same compile-level red | GREEN: `declaredSignatureFor` resolves a `task-store.getAll` trace to `getAll() -> List<Task>` from the contract file; without the file the same trace dangles (null) |
| U-1485-7 | RED pre-fix: mutation-sensitive by construction (no merge existed) | GREEN: two files declaring the same name resolve deterministically (last file in enumeration order wins; per-file aliases stay distinct) |

Final suite state (targeted, cloud-agent scope):

- `dart test test/plugins/tdd/services/spec_parser_contract_files_1485_test.dart
  test/plugins/tdd/services/declared_routing_contracts_1485_test.dart
  test/plugins/tdd/commands/plan_command_contracts_1485_test.dart` → **24/24
  passed**
- Adjacent fast suites for the touched seams (spec parser, routing resolver,
  contract gate, plan command 1182/835/1401) → **56/56 passed** in the final
  combined run
- Make-side declared-routing suites (`make_command_declared_071_test.dart`,
  `make_command_strict_071_test.dart` — slow tier, run individually via
  `--preset=all`) → **passed**; `make_command_1036_test.dart` → **6/6 passed**
- `dart analyze` on the 4 changed lib files + 3 new test files → **no issues**

## Phase 2 — Mutation evidence (test strength)

Two deliberate mutants were introduced in `declaredContractRows` and the
suite re-run:

1. **Alias registration dropped** (`<file-stem>.<row>` keys not written) —
   the supplement/alias test U-1485-4 FAILED (`task-store.Create` missing
   from the map) — the suite catches the silent trace-dangle regression.
2. **Collision order flipped** (spec.md rows re-asserted after the merge, so
   spec.md wins) — U-1485-4 (collision) and U-1485-7 (deterministic
   last-wins) FAILED — the SC-004 contract is load-bearing in the suite.

Both mutants were reverted; the full new-feature suite re-ran green
(15/15 in the parser file, 24/24 across the three files). The tests are
strong enough to kill the mutants they exist for.

## Phase 3 — Test smells

- No test interdependence: every test seeds its own hermetic temp fixture
  (`Directory.systemTemp.createTempSync` + recursive teardown).
- No assertion-free tests: every behavior asserts an observable output
  (stdout contract lines, exit code, test-list cell content, parsed row
  fields, resolved signature text).
- No time bombs: no wall-clock dependencies; fixture ordering is
  deterministic (sorted enumeration asserted directly).
- The green-first pins (A-1485-3) are characterization pins of the
  unchanged-behaviour contract (FR-007), not vacuous greens — they fail if
  the no-directory path ever grows output.

## Scope note

Per the cloud-agent verify rule, only suites covering the changed code ran
(plus the adjacent parser/resolver/plan/make suites guarding the touched
seams). The slow `@Tags(['slow'])` make suites relevant to the wiring were
run individually via `--preset=all`; the full `--preset=all` tier (build_
runner-based regression/integration fleets) is CI territory and was not run.
No unrelated pre-existing failures were observed in any executed suite.

Unrelated pre-existing formatting drift (NOT from this branch — flagged, not
fixed, to keep the diff scoped): `tool/generate_openwiki_cli_docs.dart` and
`example/test/tdd/004-login-ui/u1_test.dart` were committed unformatted on
master; `dart format .` reflows them. Every file this branch touches is
format-clean (`dart format` on the 7 files: 0 changed).

## Success criteria roll-up

- SC-001 PROVED (A-1485-1: exact report lines asserted)
- SC-002 PROVED (A-1485-2 plan-side declared routing + U-1485-6 gen-side
  signature resolution)
- SC-003 PROVED (A-1485-4 warning; A-1485-3 byte-identical no-directory
  output)
- SC-004 PROVED (U-1485-4 collision + mutation check 2)
- SC-005 PROVED (all executed adjacent suites green; no regressions
  observed)
