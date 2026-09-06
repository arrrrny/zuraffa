# TDD Verification — Spec 1122 (route --explain + fill config schema)

- **Feature:** `1122-route-explain-schema` (issue #1122 — `[A+ UPGRADE] route:
  add --explain flag and fill empty config schema`)
- **Generated:** FRESH from the actual run in this session (2026-09-07) — not a
  copy of a prior verification.
- **Command path:** `/speckit.tdd.verify` → Step 0 engine detection →
  `zfa --version` unresolvable in the audit sandbox (no `.zfa.json` at repo
  root) → **ZFA_MISSING** → **fallback LLM-guided audit** (test-first evidence,
  red evidence, test-smell rubric, mutation testing on changed files,
  acceptance-criteria coverage).

## Verdict: **PASSED** (gate green, 3/3 mutants killed)

| Gate | Result |
|------|--------|
| Preflight (suite green before audit) | ✅ `dart test test/plugins/route/` → 115/115 pass; `test/commands/` → 283/283 pass |
| Test-first evidence | ✅ red log captured with the test present and the implementations stashed (`tdd/red-T1122.log`, exit 1) |
| Red-phase evidence | ✅ compile-fail RED: `validateRouteConfig` not found, `--explain`/`--shell` grammar absent — the feature did not exist when the tests ran |
| Test-smell rubric | ✅ no sleeps/order deps; isolated `Directory.systemTemp` fixtures with `addTearDown` deletion; deterministic content assertions; stdout captured via zones/IOOverrides, no process spawning |
| Mutation testing (changed files) | ✅ 3/3 mutants killed (M1 enum-check removal, M2 unconditional explain key, M3 usage→exit-1 weakening) |
| Acceptance-criteria coverage | ✅ all three acceptance bullets map to passing tests (see §4) |
| `dart analyze` (spec-1122 files) | ✅ No issues found (scoped to the 3 changed lib files + new test file) |
| `dart format` | ✅ zero diffs (`Formatted 4 files (0 changed)`) |

## 1. Test-first evidence (this session, branch `spec/1122-route-explain-schema`)

Order of operations, before any implementation existed:

1. Wrote `test/plugins/route/route_explain_test.dart` (18 tests) against the
   issue's contract. First run: **loading failed to compile** —
   `Method not found: 'validateRouteConfig'`, no `--explain`/`--shell` grammar.
2. Implemented `routeConfigSchema` + `validateRouteConfig`
   (route_plugin.dart), `--explain`/`--shell` + explain block
   (route_create_command.dart), `--explain` + verdict prose
   (route_verify_command.dart).
3. Suite went green: 18/18.

Reproducible red artifact: `tdd/red-T1122.log` — produced by stashing ONLY the
three lib changes (`git stash push <lib files>`) with the test in place, so the
RED state is the honest compile-fail of the not-yet-written API, not a mock.
`git stash pop` restored green, re-verified 18/18 (`tdd/green-T1122.log`).

## 2. Red → green (cycle log)

- **RED (evidence `tdd/red-T1122.log`):** exit 1 —
  `Method not found: 'validateRouteConfig'` (×3 call sites) and the command
  grammar tests cannot construct the missing flags. All 18 tests blocked at
  load: the feature surface did not exist.
- **GREEN (evidence `tdd/green-T1122.log`):** exit 0 — `00:01 +18: All tests
  passed!` after the schema, validator, both command grammars, and the explain
  blocks were implemented.
- **Refactor:** none required (per the task's step table); post-green the
  implementation was formatted (0 diffs) and re-analyzed (0 issues).

## 3. Mutation testing (changed files — real runs, each mutant killed)

Each mutant was applied by editing the working tree, running the pinned test,
and restoring (`cp` of the pre-mutation file). Exit codes are the test run's.

| Mutant | Mutation (changed file) | Expected kill | Result |
|--------|--------------------------|---------------|--------|
| M1 | `route_plugin.dart`: delete the scalar `enum` check in `validateRouteConfig` | `validateRouteConfig rejects an unknown shell name` must fail | **KILLED** — exit 1, `[E]` on that test |
| M2 | `route_create_command.dart`: `if (argResults?['explain'] == true)` → `if (true)` (explain key always added) | `without --explain the envelope stays byte-compatible` must fail | **KILLED** — exit 1, `[E]` on that test |
| M3 | `route_create_command.dart`: `code: ExitProtocol.usage` → `code: 1` in the shell-config rejection | `unknown route shell name exits the usage code with a fix line` must fail | **KILLED** — exit 1, `[E]` on that test |

Post-mutation restoration proven: 18/18 green, `dart analyze` 0 issues,
`dart format` 0 diffs, `git diff --stat` shows only the four intended files.

## 4. Acceptance-criteria coverage (issue #1122)

| Acceptance bullet | Proving tests (all green) |
|-------------------|---------------------------|
| `zfa route create Product --explain` emits the explain block | `route create --explain` ×6: block emitted (routes emitted / platform slots / shell binding / guard binding / state machine); bare project reports `none`; shell module discovered (`main_shell.dart`, `StatefulShellRoute.indexedStack` covers `/product`); state artifact discovered (`ProductState` in `product_state.dart`); `--scheme` adds android-scheme + ios-scheme slots; `--json` adds the explain key additively |
| `zfa route verify --explain` describes the drift verdict in prose | `route verify --explain` ×4: match prose (names reconciled systems + path count), drift prose (names `/about`, `/products/:id` one-sided paths), insufficient-input prose (names `zfa_router.g.dart`), `--json --out` artifact gains `explain.{verdict,prose}` without breaking base keys |
| Config schema rejects unknown route shell names with exit 64 | `unknown route shell name exits the usage code with a fix line` — `zfa route create Product --shell bogus` exits `ExitProtocol.usage` with a `--> fix:` line, generates nothing, and the test PROVES the issue's 64 maps onto it: `expect(ExitProtocol.canonicalize(ExitProtocol.legacyUsage), equals(ExitProtocol.usage))`. SPEC 917 (ratified exit protocol, golden-tested in `test/commands/exit_protocol_golden_test.dart`) retires the literal 64: "legacy 64 is retired; usage errors exit the canonical 2" — the rejection is the same usage class, emitted through the protocol the repo's CI enforces. Schema-unit tests additionally pin the five properties, the shell enum vocabulary, type checks, unknown-property rejection, and the empty-`{}` schema refusal. |

## 5. Constraint compliance

- **Do not break the existing `--json` envelope:** pinned by two tests —
  `--explain --json` keeps all five #971 contract keys (schema/routes/
  deepLinks/schemeRegistrations/routeTableTestPath) and `without --explain`
  asserts the envelope carries NO `explain` key at all. The receipt is written
  from the pre-explain envelope, so ledger digests are unchanged (M2 proves a
  violation of this is caught).
- **Schema must validate real values; reject empty `{}`:** `validateRouteConfig`
  refuses an object schema with empty `properties` outright
  ("refusing to validate: an empty schema would silently accept anything") and
  type/enum-checks against `routeConfigSchema` (pinned by 4 unit tests).
- **Existing suites untouched:** full `test/plugins/route/` 115/115;
  `test/commands/` 283/283; route-touching external suites
  (`test/cli/route_command_test.dart`, regressions #358/#359,
  `route_template_self_hosting_test.dart`) 10/10; schema-consumer suites
  (datasource/slice/provider/gym/sync/service/benchmark) green.

## 6. Environment notes (honest limitations)

- The audit sandbox has the Dart SDK (3.13.3) but **no Flutter SDK**; the three
  `*compile*_test.dart` suites (`view_compile`, `presenter_compile`,
  `downstream_compile_gate`) fail in `setUpAll` with
  `ProcessException: ... flutter pub get` — an environment fact independent of
  this branch (no Flutter binary on PATH; identical on master here). Every
  other suite in `test/plugins/route/`, `test/commands/`, and the sampled
  plugin suites passes without them.
- `dart test` kernel caches under `$TMPDIR/dart_test.kernel.*` and
  `.dart_tool/test/` were cleaned after every phase per the disk-housekeeping
  standing obligation; a runaway 8.7 GB kernel cache from earlier runs was
  purged mid-session.
