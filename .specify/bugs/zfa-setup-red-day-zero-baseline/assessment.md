# Bug Assessment: fresh `zfa setup` ships a red TDD baseline — smoke test asserts an app surface no command produces

- **Slug**: zfa-setup-red-day-zero-baseline
- **Created**: 2026-08-31
- **Source**: pasted text (live reproduction, `/tmp/zfa-setup-probe/probe_app`)
- **Verdict**: valid
- **Severity**: critical

## Report (verbatim or summarized)

Fresh `dart run bin/zfa.dart setup probe_app --platforms=ios,android,macos`
succeeds and prints "Setup complete!" with Next Steps (`entity create` →
`make` → `build`, `flutter test`). But:

```
flutter test → 00:00 +0 -1: Some tests failed.
Failing tests: test/bootstrap_smoke_test.dart: loading ... (compile error)
Error when reading 'lib/app.dart': No such file or directory
Method not found: 'AppContainer'
```

And the one command that generates an app surface fails on a fresh project:

```
zfa app shell → ❌ lib/src/di/index.dart does not declare setupDependencies(...).
   Generate DI first: zfa di <Entity> (or zfa make <Entity> --with=di).
```

## Symptom

A freshly scaffolded app fails its own day-zero smoke test: the test imports
`package:<app>/app.dart` and constructs `AppContainer()`, but setup emits only
flutter-create's Hello-World `lib/main.dart` (`MainApp`). No zfa command
produces `lib/app.dart`/`AppContainer`: the app-shell generator emits
`lib/src/app/my_app.dart` (`MyApp`) and refuses to run until an entity's DI
exists. Setup's printed Next Steps never mention the app shell. Violates
spec 041 FR-001 (smoke test "asserts the generated app module and
dependency-injection container can be constructed") and FR-006 ("After
`zfa setup <name>` finishes, `flutter test` MUST exit 0").

## Reproduction

1. `zfa setup probe_app --platforms=ios,android,macos` (any platforms).
2. `cd probe_app && flutter test` → red (load error: `app.dart` missing).
3. `zfa app shell` → fails (DI index missing — needs an entity first).
4. Follow the printed Next Steps verbatim: no step ever creates `app.dart`.

Same root cause explains zik_zak_zfa's red baseline (its `lib/` is empty;
rewrite tooling copied setup's smoke test).

## Suspected Code Paths

- `lib/src/cli/writers/tdd/` smoke-test writer — emits the
  `app.dart`/`AppContainer` assertion unconditionally.
- `lib/src/plugins/app_shell/builders/app_shell_builder.dart` — generates
  `lib/src/app/my_app.dart` (`MyApp`), not `app.dart`/`AppContainer`.
- `lib/src/commands/app_shell_command.dart:92-99` — `zfa app shell`;
  entity-first DI precondition enforced via error.
- setup's Next Steps printer — canonical sequence omits the app shell.

## Root Cause Hypothesis

The smoke test was specified (041) against an app surface ("generated app
module + DI container") that no day-zero code path generates: setup does not
run the app-shell builder, the builder's output path/symbols differ from the
test's imports, and the builder itself cannot bootstrap without a prior
entity. Three-way contract mismatch (test ↔ shell ↔ Next Steps). High
confidence — all three sides verified live.

## Proposed Remediation

**Preferred**: make day zero self-consistent with the strong assertion
intact — setup emits a minimal zfa-generated app module + DI index (via the
app-shell builder with a bootstrap DI, or a minimal `app.dart` writer) so
`AppContainer()` exists and `flutter test` is green immediately; `zfa app
shell` then upgrades the minimal shell. The epic's provenance audit requires
the strong version (the app surface must be zfa-attributable), so weakening
the smoke test is a fallback only.

**Alternatives**: weaken the day-zero smoke test to assert only what exists
(`MainApp` constructs) and move the `AppContainer` assertion to a
post-app-shell test — rejected for the epic (weakens the provenance story),
acceptable as a stopgap.

**Files likely to change**:
- setup wiring / `lib/src/plugins/app_shell/` (bootstrap-capable shell)
- `lib/src/cli/writers/tdd/` smoke-test writer
- setup Next Steps output

**Tests to add or update**:
- Fresh `zfa setup` → `flutter test` exit 0 (slow-tier, the 041 FR-006 gate).
- `zfa app shell` succeeds on a fresh setup (bootstrap DI) and the smoke
  test still passes after the upgrade.

## Risks & Considerations

- Decide whether day-zero `AppContainer` is a minimal bootstrap DI (empty
  graph) — recommended — vs requiring entity-first.
- `main.dart` (Hello World) vs generated shell duplication needs a decision.

## Open Questions

- None blocking; strong-vs-weak smoke test is the maintainer call, with the
  epic needing the strong one.
