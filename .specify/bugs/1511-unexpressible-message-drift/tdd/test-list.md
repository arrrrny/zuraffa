# TDD Test List — BUG 1511 (unexpressible message drift, bug 657 assertion)

- **Date**: 2026-09-12
- **Branch**: `fix/1511-unexpressible-message-drift`
- **Feature area**: `test/plugins/tdd/make_command_test.dart` — US4 misfire-stop on
  unexpressible behaviors
- **Run filter**: `dart test --preset=all test/plugins/tdd/make_command_test.dart -n "bug 657"`

| ID | Test | Assertion contract | Cycle | Result |
| --- | --- | --- | --- | --- |
| T1 | `bug 657: an unexpressible make phrases the refusal in behavior terms — it names the behavior, quotes the full description, and cites the STOP-ON-ROADBLOCK policy` | unexpressible refusal pins current wording: `no generator surface maps the behavior` + quoted description `"provision bespoke DSL syntax with no generator surface"` + `STOP-ON-ROADBLOCK policy`; outcome line `make: behavior=B-042 outcome=unexpressible feature=<feature>`; exit non-zero | RED → GREEN | PASS |
| T2 | `bug 657: a render-type behavior plans the `tdd func` step through the pipeline (no longer unexpressible)` | render-type prose routes through the pipeline and certifies green (`make: behavior=B-043 outcome=green`); regression guard, untouched | (already green) | PASS |

## Guard rails honored

- No production source changed (`git diff --name-only HEAD` lists only
  `test/plugins/tdd/make_command_test.dart`).
- No new test added, none removed, none renamed away from the `bug 657:` filter
  prefix (both tests still match `-n "bug 657"`).
- Suite-level check: full fast suite re-run chunked after the fix — zero failed
  chunks (see `.specify/bugs/1511-unexpressible-message-drift/tdd/verification.md`).
