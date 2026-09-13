# Test List: 1528-auto-tdd-init-or-setup-error

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1528-1 | `zfa tdd verify-red <id>` on a profile-less fixture (registered gen'd behavior) fails CLOSED before any test process spawns: final line `verify-red: behavior=<id> classification=setup-error certified=false feature=<feature>`, exit non-zero, output names the profile path and the idempotent `zfa tdd init` remediation (`--> fix:` line), cycle-log untouched, verdict receipt exit_class=setup-error under --json | FR-005, FR-009, SC-003 | PENDING |
| U-1528-2 | the batch lane (`verify-red --all`, ≥1 pending behavior, no profile) reports `classification=setup-error` on the batch summary and per-behavior summaries, exit non-zero — AFTER the empty-targets early return keeps `classification=batch` (no targets, no profile → still the honest nothing-to-certify exit 0) | FR-006 | PENDING |
| U-1528-3 | ordering + vocabulary invariants: unknown-id with NO profile still resolves FIRST and classifies `unresolved` (U18/sc-004 A13 pinned); ambiguous no-arg target still `unresolved`; a valid-profile rejection matrix (runner-error/unexpected-green) is unchanged | FR-007, SC-005 | PENDING |
| U-1528-4 | `zfa tdd run <feature>` entry preflight: profile-less fixture → the idempotent init sequence runs at entry (`.specify/memory/tdd-profile.md` + `test/bootstrap_smoke_test.dart` + `dart_test.yaml` recreated), created artifacts are logged, and the loop drives its first step (fake zfa step log non-empty; no `classification=unresolved` anywhere). Init misfire (invalid pubspec) → fail closed BEFORE any step: journaled `preflight_red` (result=setup-error, writer failure named in violations), all-zero `run: feature=<f> result=setup-error …` summary, verdict exit_class=setup-error + fix hint, exit 1, ZERO step spawns | FR-001, FR-004, FR-009, SC-001 | PENDING |
| U-1528-5 | `zfa tdd gen <id>` entry preflight: profile-less fixture → baseline ensured + artifacts logged before the flow; init misfire → fail-closed refusal (gen verdict exit_class=setup-error, `--> fix:` line, exit 1) with no test/subject writes | FR-002, FR-004 | PENDING |
| U-1528-6 | no-op guarantee: fixture with a valid profile — run/gen/verify-red produce byte-identical behavior to pre-#1528 (preflight prints nothing, creates nothing; init idempotency skip-if-present preserved) | FR-008, SC-002 | PENDING |
| U-1528-REG1 | regression guard: existing init/verify/run/gen suites pass unchanged (init output byte-identical after the TddBaselineInit extraction; loop/state machine untouched) | FR-003, FR-010 | PENDING |

## Layer contracts

```yaml
# fr: FR-003, FR-008
baseline_init.dart: TddBaselineInit.ensure is the ONE idempotent writer sequence (profile, dart_test.yaml, spec template, smoke test, [flutter app module + deps], dev-deps, [skin]) shared by zfa tdd init and the entry preflight; identical ✓/✗ lines through injected sinks; same StateError misfire throw
# fr: FR-001, FR-002, FR-004
profile_preflight.dart: TddProfilePreflight.ensure probes <root>/.specify/memory/tdd-profile.md; present → silent no-op report; missing → auto-init (non-force, non-skin) with created-artifact log; init failure → TddProfilePreflightError for the caller's fail-closed verdict
# fr: FR-005, FR-006, FR-007
verify_red_command.dart: post-resolution setup probe (single lane after _resolveTarget; batch lane after the empty-targets return, before loadFileTemplate); missing profile → classification=setup-error + verdict receipt + exit 1; NEVER auto-writes (FR-008 read-only preservation); resolution errors keep unresolved and their ordering
# fr: FR-001, FR-004
run_command.dart: preflight after the kernel sweep, before the #1303 gate, unconditional (not --force-gated); failure → journaled preflight_red + result=setup-error summary + verdict, exit 1, zero steps
# fr: FR-002, FR-004
gen_command.dart: preflight after cwd/usage validation, before the flow; failure → gen refusal verdict, exit 1
```

## Key entities

```yaml
TddBaselineInit: shared idempotent baseline writer sequence (extracted from InitCommand)
BaselineInitReport: created artifacts + writer failures
TddProfilePreflight: entry-level ensure (probe → auto-init → report / typed error)
TddProfilePreflightError: typed setup failure carrying the writer failures
setup-error: the machine-readable exit_class/summary label for setup conditions — never unresolved
```

## External dependencies

(none — pure-Dart filesystem probes and the existing writers; no new packages)

## Routing provenance

All rows are UNIT tier driven directly through `CliRunner` over `TddFixture`
(`writeProfile: false` for the setup-condition rows) — no fallback routing;
every trace cell names the spec FR the behavior verifies.
