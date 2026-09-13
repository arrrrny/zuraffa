# Implementation Plan: Preflight — auto `tdd init` or fail with `setup-error` classification

**Branch**: `feat/1528-auto-tdd-init-or-setup-error` | **Spec**: [spec.md](./spec.md) | **Issue**: #1528

## Technical Context

**Language/Version**: Dart 3.11+ (SDK constraint `^3.11.0`), pure-Dart host package (`zuraffa` 6.2.2 CLI)
**Dependencies**: args, path, yaml (existing — no new deps)
**Storage**: filesystem artifacts only (`.specify/memory/tdd-profile.md`, `dart_test.yaml`, `test/bootstrap_smoke_test.dart`, `lib/app.dart`, `pubspec.yaml`, `.specify/templates/spec-template.md`, `specs/<feature>/tdd/journal.json`)
**Testing**: `dart test` (package:test), `TddFixture` temp-project harness (`test/plugins/tdd/helpers/tdd_fixture.dart`, `writeProfile: false` supported)
**Target/Deployment**: `zfa tdd run` / `zfa tdd gen` / `zfa tdd verify-red` CLI entries
**Scale**: single-project CLI; the preflight is O(1) file-existence probe + (rare) idempotent writer pass

## Project Structure

```
lib/src/plugins/tdd/
  services/
    baseline_init.dart          # NEW — shared idempotent writer sequence (extracted from InitCommand)
    profile_preflight.dart      # NEW — entry-level ensure: probe → auto-init → report / throw
  commands/
    init_command.dart           # REWIRE — delegate body to TddBaselineInit (output byte-identical)
    run_command.dart            # ENTRY PREFLIGHT — after kernel sweep, before #1303 gate; fail-closed on init failure
    gen_command.dart            # ENTRY PREFLIGHT — after cwd resolution + usage validation, before flow
    verify_red_command.dart     # CLASSIFICATION — post-resolution setup probe (single + batch lanes), setup-error, never auto-write
test/plugins/tdd/commands/
  issue_1528_setup_error_test.dart   # NEW — unit/integration tests (red→green)
specs/1528-auto-tdd-init-or-setup-error/
  spec.md plan.md tasks.md tdd/test-list.md tdd/verification.md
```

## Technical Approach

### 1. Shared idempotent baseline (TddBaselineInit)

`InitCommand._run`'s writer sequence (profile → dart_test.yaml → spec template → smoke test → [Flutter: app module + app deps] → dev-deps patcher → [skin]) moves VERBATIM into `TddBaselineInit.ensure({projectRoot, force, skin, onLine, onError})`. The service:

- prints the identical `zfa tdd init: ensuring TDD baseline in <cwd> (Flutter|Dart)` header and `✓/✗` lines through injected sinks (InitCommand passes `stdout.writeln`/`stderr.writeln` — output byte-identical),
- collects `created` (artifact labels actually written/patched) and `failures` (`<writer>: <message>`),
- on failures prints the same misfire block to the error sink and throws the same `StateError` (errors-are-an-API contract preserved),
- keeps `_isFlutterProject`'s FormatException propagation (invalid pubspec → caller decides; preflight fail-closes, init propagates as today).

This is the only implementation of the idempotent sequence — FR-003 (no duplicated idempotency logic).

### 2. Entry preflight (TddProfilePreflight)

`ensure({projectRoot, commandLabel, onLine})`:
1. probe `<root>/.specify/memory/tdd-profile.md` — exists → return `ProfilePreflightReport(profilePresent: true, created: const [])` (silent no-op, FR-008);
2. missing → run `TddBaselineInit.ensure(force: false, skin: false)` with a log sink prefixed by the entry (`zfa tdd run: preflight — TDD profile missing; running idempotent 'zfa tdd init'`), collect `created`, log `preflight — TDD baseline ensured (created: …)`;
3. init threw (writer misfire) → rethrow StateError; the entry fail-closes (US3).

Wiring:
- **run_command.dart**: after the kernel sweep, BEFORE the #1303 dependency-overrides gate (baseline setup precedes gate refusals). On init failure: mirror the #1303 fail-closed shape — `_journalMeta(gateState: 'preflight_red', phase: 'gate', result: 'setup-error', violations: <writer failures>)`, summary line `result=setup-error` with zeroed counts, verdict `exitClass=setup-error` + explain, exit 1 (SPEC 917 golden: failure class distinguished by exit_class). Runs unconditionally (not gated by `--force`, edge case).
- **gen_command.dart**: after cwd resolution + feature-scope usage validation, before the flow. On init failure: gen's refusal shape — error line + `--> fix:` line + verdict (exitClass `setup-error`, outcome fail) + exit 1.
- **verify_red_command.dart**: NO auto-init. Post-resolution probe (single lane: after `_resolveTarget`, before `loadSingleTemplate`; batch lane: after empty-targets early return, before `loadFileTemplate`). Missing → `classification=setup-error` summary + verdict receipt + `--> fix: zfa tdd init` + exit 1. Preserves U18 ordering (unknown-id resolution error still wins, stays `unresolved`, FR-007) and the FR-008 read-only contract (the init writers touch `test/`/`lib/`; verify-red must not).

### 3. Machine-readable surfaces

| Command | Surface (setup condition) | Exit |
|---|---|---|
| `run` | `run: feature=<f> result=setup-error pending=0 red=0 green=0 done=0` + verdict `exit_class=setup-error` + journaled `preflight_red` | 1 |
| `gen` | `zfa tdd gen: setup-error — …` + `--> fix:` + verdict `exit_class=setup-error` | 1 |
| `verify-red` | `verify-red: behavior=<id> classification=setup-error certified=false feature=<f>` (+ batch variants) + verdict receipt | 1 |

`setup-error` joins the exit_class vocabulary as a sub-flavor of the golden exit 1 — no new exit code (the golden table is conformance-pinned).

### 4. What deliberately does NOT change (hard constraints)

- Step sequencing, state machine, `SingleTestRunner` execution/transcript handling, `RedClassification` runner-transcript classes (assertion/compile-error/load-error/…), suite baseline tolerance (`on StateError { // No profile / no suite template }` stays as the loop's own fallback), suite guard, journal replay.
- `run-engine`/`run-skin` standalone entries are NOT named by the issue's fix surface; the meta `run` preflights before lanes spawn, and a spawned `verify-red` child fail-closes with `setup-error` (not `unresolved`) even there — the loop never again sees `unresolved` for the missing-profile condition.

## Technical Context pins (per plan template)

- tdd run/gen entry preflight: profile probe at `<projectRoot>/.specify/memory/tdd-profile.md` — the SAME path constant `SingleTestRunner.defaultProfilePath` (no new path truth)
- `tdd-profile.md` path: `.specify/memory/tdd-profile.md` (unchanged; written by `TddProfileWriter`)
- `tdd init` idempotency: skip-if-present per writer; `--force` is an init-only flag the preflight never sets
- `unresolved` classification: REMAINS the verdict for resolution-stage errors (unknown id, ambiguous target, malformed list, unparseable timeout, snapshot failure) — the issue's complaint is narrowly the setup condition wearing that label
- `setup-error` classification: NEW exit_class/summary label for setup conditions (missing profile; failed baseline ensure), machine-readable on every affected entry
