# tdd.verify — Spec 1692: the tdd make path consults the 016 id-gate — upfront refusal for id-less entities

- **Verified**: 2026-09-17, this session, on
  `fix/1692-tdd-make-idless-entity-gate` (working tree, pre-push; base
  `a9329746`)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/plugins/tdd/commands/make_command.dart` (the spec 1692
  gate + `_spec016IdGateRefusal` helper), the new
  `test/plugins/tdd/spec_1692_make_id_gate_test.dart`, and the artifacts under
  `.specify/specs/1692-tdd-make-idless-entity-gate/`.

## Verdict: PASS

## 1. TDD discipline (red → green)

Two behaviors were pinned in `tdd/test-list.md` (U-1692-b1, U-1692-b2) and
written as `test/plugins/tdd/spec_1692_make_id_gate_test.dart` BEFORE the fix.

**Red (pre-fix, unit level)** — observed, not reconstructed:

```
dart test test/plugins/tdd/spec_1692_make_id_gate_test.dart
→ 00:18 +0 -2: Some tests failed.
```

U-1692-b1 failed for exactly the issue's reason: the make output carried no
`Cannot generate architecture for "UserSession": the entity has no id field.`
diagnostic — the pipeline planned `3 step(s): mock create, wire, build` and RAN
it. U-1692-b2 (the id-bearing guard) passed pre-fix by design: it pins the
behavior the fix must not disturb.

**Red (pre-fix, e2e level)** — the task's idless_probe repro, driven end to
end on the patched-out binary (`zfa setup idless_probe --dart`, spec with
`| UserSession | token: String, email: String |` traced by FR-001 to
`UserSessionRepository.refreshSession`, `zfa tdd plan f` →
`route: U1 -> unit lane (entity pipeline: UserSession)`, gen, verify-red
certified, make):

```
zfa tdd make U1 --feature f
   plan: 3 step(s): mock create, wire, build
→ mock create
zfa tdd make: generation step failed at index 0
   command: `/home/z/tools/zfa mock create --name UserSession --certify`
   exit: 1
   output (tail):
❌ Error: mock certification failed for UserSession: dart analyze: 2 issue(s), 2 error(s)
  error - ...user_session_mock_datasource.dart:36:22 - The getter 'id' isn't defined for the type 'UserSession' - undefined_getter
  error - ...user_session_mock_datasource.dart:53:22 - The getter 'id' isn't defined for the type 'UserSession' - undefined_getter
make: behavior=U1 outcome=generation-error feature=f
```

The generated surface held the id-assuming code verbatim:

```dart
Future<UserSession> update(
  UpdateParams<String, UserSessionPatch> params,
) async {
  logger.info('Updating UserSession: ${params.id}');
  ...
  final existing = UserSessionMockData.userSessions.firstWhere(
    (item) => item.id == params.id,
```

This is the bug: the #307/016 gate never fired on the tdd make path and the
mock certification backstop caught the broken output downstream.

**Green (post-fix, unit level):**

```
dart test test/plugins/tdd/spec_1692_make_id_gate_test.dart
→ 00:19 +2: All tests passed!
```

**Green (post-fix, e2e level)** — same repro, patched binary:

```
zfa tdd make U1 --feature f
   plan: 3 step(s): mock create, wire, build
zfa tdd make: refusing BEFORE generation — the traced entity "UserSession" has no id field (spec 016 id-gate on the tdd make path, issue #307).
❌ Cannot generate architecture for "UserSession": the entity has no id field.

Entities need a real identity. Choose one of:
  1. Add an id field:    zfa entity add-field -n UserSession --field id:String
  2. Auto-generate one:  recreate with zfa entity create -n UserSession --auto-id <fields...>
  3. Mark it as a value object if it is an immutable composition type (no identity, no CRUD surface):
       zfa entity create -n UserSession --kind=value_object <fields...>
     or add @ZValueObject / kind: ZorphyKind.valueObject to its annotation.
   or narrow the traced contract to id-neutral methods (no repository/datasource/mock CRUD surface), then re-run.
--> fix: add `id: String` to UserSession, or narrow the traced contract to id-neutral methods, then re-run.
make: behavior=U1 outcome=unexpressible feature=f
```

No pipeline step spawned (the fake-bin oracle in U-1692-b1 proves the log
stays empty; in the e2e run no `→ mock create` line ever printed and no mock
datasource was written by the make).

## 2. Hard-constraint audit (spec 1692)

1. **Consult the 016 id-check on the tdd make path** — PROVED. The gate calls
   the SAME resolver main make uses (`EntityFieldResolver.resolveIdField`) on
   the behavior's traced entity, gated behind an id-dependent-step scan of the
   effective plan (`mock create --name <Traced>`, `make <Traced>` without
   `--no-entity`).
2. **Refuse BEFORE generation with the #307 remediation text** — PROVED
   (U-1692-b4 + the fake-bin log-empty assertion in U-1692-b1). The refusal
   carries the #307 message + three hints + the tdd-path remediation
   (narrow the traced contract to id-neutral methods), classifies as
   `unexpressible` (non-zero exit, no green entry, run loop defers then stops
   honestly — never a fabricated `generation-error`).
3. **Keep the mock cert backstop** — PROVED by absence of change: nothing
   under `lib/src/plugins/mock/` (certification sandbox, contract test
   writer) is modified (`git diff --stat`); the pre-fix e2e run itself
   demonstrates the backstop still catches non-compiling output when the
   gate is bypassed.
4. **Not break id-bearing entity generation** — PROVED in both directions:
   unit guard U-1692-b2 green, and the e2e control (feature g, PriceAlert
   with `id: String`) drove the full post-fix pipeline to
   `make: behavior=U1 outcome=green feature=g` with the certified mock
   generated and green evidence appended.

## 3. Regression scope (only-what-changed verification)

`dart analyze` on the changed files:

```
dart analyze lib/src/plugins/tdd/commands/make_command.dart
             test/plugins/tdd/spec_1692_make_id_gate_test.dart
→ No issues found!
```

Targeted suites (with the fix), vs. the SAME suites on base `a9329746`
(stash/unstash, identical invocation):

| suite | fix | base | verdict |
| ----- | --- | ---- | ------- |
| make_command_test.dart (regression preset) | +30 -10 | +30 -10 | failure sets byte-identical (diffed) — all pre-existing |
| 1587 build-skip + 1587 dedup + 1565 + #1330 + #1407 + strict-071 + 1651 (all preset) | +16 -7 | +16 -7 | failure sets byte-identical — all pre-existing |
| widget 939 + 950 + 1036 + run-driver 1652 (all preset) | +11 -3 | +11 -3 | failure sets byte-identical — all pre-existing |

57 passing / 20 failing across the make surface, with EVERY failing
identifier identical between base and fix (machine-diffed, not eyeballed).
The failures are pre-existing fixture-shape drift (#737/#1530/#942/#1407
groups) on this branch's base, unrelated to identity gating — flagged, not
absorbed.

Format gate:

```
dart format .   → Formatted 2944 files (0 changed)
dart format --output=none --set-exit-if-changed <changed files>
→ exit 0 (zero drift)
```

## 4. Test-strength audit (the fallback rubric)

The new suite's assertions discriminate the contract, not accidents:

- **before-generation proof**: U-1692-b1 asserts the fake zfa invocation log
  is EMPTY — a gate that refused after `mock create` ran (e.g. at the build
  step) would fail this even if every message assertion passed.
- **classification proof**: the summary line is asserted as
  `outcome=unexpressible` AND exit non-zero AND no `## Cycle: U1 (green)`
  entry — a stub that refused but wrote green evidence, or exited 0, fails.
- **text proof**: the #307 message, the `--> fix:` remediation naming both
  remedies (add `id: String` / narrow the traced contract), and the
  id-neutral wording are each asserted verbatim — a reworded refusal fails.
- **over-application proof**: U-1692-b2 asserts the id-bearing entity still
  reaches `mock create` (the log CONTAINS it) and certifies green — a gate
  that refused on entity existence alone (id-blind) fails.
- **mutation note**: `mutation_test` is available in dev_dependencies, but
  the zuraffa repo is not zuraffa-wired (no `.zfa.json`), so
  `/speckit.tdd.verify`'s deterministic dispatch (`zfa tdd verify`) is not
  applicable here and the documented fallback audit was followed. Equivalent
  kill-strength evidence: each mutant class the gate could admit (refuse
  late, refuse wrong entity, refuse id-bearing, misclassify outcome) is
  pinned by a distinct assertion above.

## 5. Acceptance-criteria coverage

| spec criterion | evidence |
| -------------- | -------- |
| SC-1 (repro refuses before generation, no mock written) | U-1692-b4 e2e transcript above |
| SC-2 (id-bearing probe generates unchanged) | U-1692-b5 e2e green + U-1692-b2 |
| SC-3 (analyze clean, both-direction tests, format clean) | sections 3 and 4 |
| SC-4 (backstop untouched) | `git diff --stat`: no file outside `make_command.dart` + the new test under `lib/`/`test/` |

No remediation tasks required — the gate is PASS.
