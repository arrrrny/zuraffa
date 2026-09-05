# Cycle Log — 972-usecase-aplus-upgrade

Red → green → refactor → verify, with the actual commands and evidence.

## Cycle 1 — RED (reproduce every failure first)

Wrote the failing-first suite (6 files, 19 behaviors) BEFORE any
production change:

```
dart test test/plugins/usecase/
```

Observed failures (the red evidence):

- `usecase_command_grammar_test.dart` FR1-1:
  `Expected: <64> Actual: <0>` with
  `stdout=❌ Usage: zfa usecase <EntityName> [options]` — the silent
  no-op reproduced exactly as the issue describes.
- `usecase_create_json_test.dart` (all 4 tests): the `--json` flag
  cannot even parse on the capability-derived subcommand; no envelope,
  no receipt, `proof check` has nothing to verify.
- `usecase_expectation_post_pass_test.dart` FR4-neg: `make Task
  repository usecase --use-service` exits 0 — the misfire passes
  silently (fail-open hole open).
- `usecase_toggle_default_test.dart`: default methods were
  `['get','update','toggle']` — toggle usecase emitted without request.
- `usecase_revert_test.dart`, `usecase_stream_append_test.dart`: no
  machine verdicts to assert against (red via the missing envelope).

Suite state at end of RED: **9 failing tests** (plus 3 control tests
that pin pre-existing contracts — those were green before and after,
by design).

## Cycle 2 — GREEN (the six orders)

1. **Kill the dead positional body** — `usecase_command.dart`'s run()
   replaced with `reportSubcommandUsage()` (exit 64), mirroring
   `repository_command.dart:42-49`. Dead path (old lines 67-123)
   deleted.
2. **`zfa usecase create --json`** — new first-party
   `UseCaseCreateCommand` (manually registered; `manualSubcommandNames`
   guards the #761 duplicate-registration crash) emitting
   `{schema:1, methods:[{name, action: created|appended|skipped,
   reason}]}`.
3. **Receipts** — `.zfa/receipts/usecase-<entity>.json` (deterministic
   name, `proof.v1`): `requested_methods` / `generated_methods` /
   `skipped_methods` / `guard_reason_codes` / `interface_absent` +
   per-file digests + entity-spec binding.
4. **Close the fail-open hole** — `SourceInterfaceGuard.evaluate()`
   surfaces `interfaceAbsent`; the entity generator fires an
   expectation callback; `UseCasePlugin.generateWithContext` records it
   into the plan context; `UsecaseExpectationPostPass` (make post-pass)
   verifies the responsible plugin declared the methods, else
   `exitCode = 1` + `--> fix:` line.
5. **Drop the toggle default** — `['get','update','toggle']` →
   `['get','update']` (create command + make path).
6. **All tests above.**

```
dart test test/plugins/usecase/      → +36: All tests passed!
```

## Cycle 3 — Refactor / harden

- `filterMethods()` kept as a thin wrapper over the structured
  `evaluate()` — legacy print behavior byte-identical.
- `plugin.generate()` now delegates to `generateWithReport()` — one
  delegation path, no duplicated logic.

## Cycle 4 — Mutation spot-audit (see verification.md)

Three post-green mutants run against the suite:

- MUTANT-1 (exit 64 → dead-hint + exit 0): **killed** by FR1-1.
- MUTANT-2 (toggle default reinstated): initially **survived** — the
  create-path test didn't cover the make path. Strengthened the suite
  with the make-flow test (FR5-2); re-run: **killed**.
- MUTANT-3 (post-pass disabled): **killed** by FR4-neg.

Final state: `dart test test/plugins/usecase/` → **+37: All tests
passed!**
