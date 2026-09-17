# TDD test list — Spec 1692: the tdd make path consults the 016 id-gate — upfront refusal for id-less entities

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1692-b1 | test/plugins/tdd/spec_1692_make_id_gate_test.dart | unit/e2e | an id-less traced entity (`token` + `email`, no id-like field, no autoId, not a value object) whose unit pipeline plans `mock create --name <Traced>` refuses BEFORE generation with the #307 diagnostic + remediation text, exits non-zero as `unexpressible`, spawns zero pipeline steps (the fake zfa invocation log stays empty), and appends no green entry | spec 1692 FR-1, FR-2, FR-3 | RED → GREEN |
| U-1692-b2 | test/plugins/tdd/spec_1692_make_id_gate_test.dart | unit/e2e | an id-bearing traced entity (literal `id: String`) keeps the entity pipeline: `mock create`/`wire`/`build` run, the target test certifies green, green evidence is appended — the no-regression direction of the gate | spec 1692 FR-4, SC-2 | GREEN (guard) |
| U-1692-b3 | e2e repro (idless_probe, feature f) | e2e | `zfa tdd make U1 --feature f` on the pre-fix binary: id-assuming CRUD mock emitted (`item.id == params.id`), mock certification catches it downstream — `make: behavior=U1 outcome=generation-error` (the bug, red evidence) | spec 1692 repro | RED (pre-fix) |
| U-1692-b4 | e2e repro (idless_probe, feature f) | e2e | same make on the post-fix binary: refusal BEFORE the first pipeline step with the #307 text verbatim, `make: behavior=U1 outcome=unexpressible feature=f`, no mock datasource written by the make | spec 1692 SC-1 | GREEN |
| U-1692-b5 | e2e control (idless_probe, feature g) | e2e | an id-bearing Key Entity (`PriceAlert | id: String, price: double`) drives the full pipeline to `make: behavior=U1 outcome=green feature=g` on the post-fix binary — generation unchanged | spec 1692 SC-2 | GREEN |

Guard pins (pre-existing, unchanged and green against the fix):

| id | suite | description |
| -- | ----- | ----------- |
| #829 unit-entity pipeline | test/plugins/tdd/make_command_test.dart | the entity-pipeline routing (`entity create` → `mock create`/`make` → `wire` → `build`) the gate consults — 30 pass, 10 failures byte-identical to base `a9329746` (pre-existing, unrelated: #737/#1530/#942 fixture shapes + composition-fallback counts) |
| #1587 build skip | test/plugins/tdd/make_command_1587_build_skip_test.dart | the terminal-build skip the gate must precede — failures identical to base |
| #1330 subject-edit fallback | test/plugins/tdd/issue_1330_make_subject_edit_fallback_test.dart | plan shaping before the gate — failures identical to base |
| #1407 errors-only gate | test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart | the build-verdict grading the gate does not touch — failures identical to base |
| 071 strict/declared routing | test/plugins/tdd/make_command_strict_071_test.dart, make_command_declared_071_test.dart | declared entity routing — green |

## Red evidence (pre-fix, this session)

- Unit level: `dart test test/plugins/tdd/spec_1692_make_id_gate_test.dart`
  → `00:18 +0 -2: Some tests failed.` — U-1692-b1 failed on the missing
  `Cannot generate architecture for "UserSession": the entity has no id field.`
  diagnostic (the gate did not exist); U-1692-b2 (the id-bearing guard)
  passed pre-fix, pinning today's correct behavior.
- E2E level (U-1692-b3, idless_probe):
  `zfa tdd make U1 --feature f` →
  `command: /home/z/tools/zfa mock create --name UserSession --certify` exit 1,
  `mock certification failed for UserSession: dart analyze: 2 issue(s), 2 error(s)`
  (`The getter 'id' isn't defined for the type 'UserSession'` at
  `user_session_mock_datasource.dart:36:22` and `:53:22` — the
  `item.id == params.id` lookups), terminal line
  `make: behavior=U1 outcome=generation-error feature=f`.

## Green evidence (post-fix, this session)

- `dart test test/plugins/tdd/spec_1692_make_id_gate_test.dart`
  → `00:19 +2: All tests passed!`
- `zfa tdd make U1 --feature f` (U-1692-b4) → refusal BEFORE generation:
  plan announced (`3 step(s): mock create, wire, build`), then
  `zfa tdd make: refusing BEFORE generation — the traced entity "UserSession" has no id field (spec 016 id-gate on the tdd make path, issue #307).`,
  the #307 diagnostic + three hints + `--> fix: add `id: String` to UserSession, or narrow the traced contract to id-neutral methods, then re-run.`,
  terminal line `make: behavior=U1 outcome=unexpressible feature=f`,
  non-zero exit, no step spawned, no green entry.
- `zfa tdd make U1 --feature g` (U-1692-b5) → `→ mock create`, `→ wire`,
  `→ build`, `target test exit: 0`, `green evidence appended to
  specs/g/tdd/cycle-log.md`, terminal line
  `make: behavior=U1 outcome=green feature=g`.
- Make-surface regression suites (with the fix):
  make_command_test.dart + 1587/1565/1330/1407/strict-071/declared-071/1651
  → `+30 -10` and `+16 -7`, with the failing-test identifier sets
  byte-identical (diffed) to the same suites on base `a9329746` — every
  failure pre-existing, none introduced.
