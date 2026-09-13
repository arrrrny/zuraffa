# Tasks: Preflight — auto `tdd init` or fail with `setup-error` classification

**Branch**: `feat/1528-auto-tdd-init-or-setup-error` | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

> MVP-first: T001–T008 deliver the behaviour slice end-to-end (tests red→green, entries wired).
> `[behavior: <id>]` markers bind tasks to the test list (spec-kit TDD extension).

## Phase 3.1 — Shared idempotent baseline (non-behavioural refactor, output-preserving)

- [x] T001 Extract `InitCommand._run`'s writer sequence verbatim into `TddBaselineInit.ensure({projectRoot, force, skin, onLine, onError}) -> BaselineInitReport{created, failures}` in `lib/src/plugins/tdd/services/baseline_init.dart`; keep the identical header/✓/✗ lines through the injected sinks, the same misfire stderr block and the same `StateError` throw on failures; move `_isFlutterProject` + `_deriveAppName` with it (FormatException propagation unchanged)
- [x] T002 Rewire `InitCommand._run` to delegate to `TddBaselineInit` (sinks = stdout/stderr); keep the `--json` verdict wrapper and `_verdict.details['failures'] = 0`; verify the existing init/doctor tests pass UNCHANGED (output byte-identical, FR-003)

## Phase 3.2 — Behaviour: entry preflight + setup-error classification (TDD)

- [x] T003 `[behavior: U-1528-1]` `[behavior: U-1528-2]` `[behavior: U-1528-3]` RED: `verify-red` on a profile-less fixture with a gen'd behavior ends `classification=setup-error certified=false`, exit non-zero, no evidence, no runner spawn; batch lane `--all` reports `classification=setup-error` after the empty-targets return (US1/US2, FR-005, FR-006) — update pinned U27, keep U18/U20/sc-004 A13 unresolved ordering (FR-007)
- [x] T004 GREEN: implement the post-resolution profile probe in `verify_red_command.dart` (single lane after `_resolveTarget`; batch lane before `loadFileTemplate`): missing → setup-error summary + verdict receipt (`exit_class=setup-error`, outcome fail, `--> fix: run zfa tdd init …`) + exit 1; NO writes anywhere (FR-008 read-only preserved)
- [x] T005 `[behavior: U-1528-4]` RED→GREEN: `TddProfilePreflight.ensure` in `lib/src/plugins/tdd/services/profile_preflight.dart` (probe → `TddBaselineInit` auto-run → report; rethrow writer misfires); wire into `run_command.dart` after the kernel sweep, before the #1303 gate — missing profile → auto-init with created-artifact logging → run proceeds; init failure → journaled `preflight_red` (`result=setup-error`, writer failures as violations), zeroed-counts summary, verdict, exit 1, zero steps spawned (US1/US3, FR-001, FR-004, FR-009)
- [x] T006 `[behavior: U-1528-5]` RED→GREEN: wire the same preflight into `gen_command.dart` after cwd/usage validation, before the flow — auto-init + artifact log on missing profile; fail-closed refusal (gen's verdict shape, `exit_class=setup-error`, exit 1) on init failure (US1 SC-3, FR-002)
- [x] T007 `[behavior: U-1528-6]` No-op guarantee: fixture with a valid profile — run/gen/verify-red output and writes byte-identical to pre-#1528 (preflight silent no-op); assert the preflight creates nothing and prints nothing when the profile exists (FR-008, SC-002)

## Phase 3.3 — Non-behavioural polish

- [x] T008 `/speckit.analyze` sweep: cross-artifact consistency (spec ↔ plan ↔ tasks ↔ test-list), fix drift
- [x] T009 `dart analyze` clean on all touched files; `dart format` the touched files; update the `run_command.dart` doc-comment exit taxonomy (setup-error stop, exit 1, journaled preflight_red)

## Parallelization

- T001 → T002 sequential (same file pair).
- T003–T007 sequential after T002 (each builds on the shared service).
- T008–T009 last.
