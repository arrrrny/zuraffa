# TDD Cycle Log: 1528-auto-tdd-init-or-setup-error

**Feature**: 1528-auto-tdd-init-or-setup-error
**Template**: zuraffa-1.0
**Created**: 2026-09-13

Entries follow the `## <timestamp> - <PHASE> - <behavior-id>` heading format
with a `Behavior:` line and an `Evidence:` block, separated by `---`.
Phases: RED, GREEN, REFACTOR.

## Baseline

Seven behaviors derived from `spec.md` before any implementation change:
U-1528-1 … U-1528-6 (unit) + U-1528-REG1 (regression guard), all PENDING.
Test file: `test/plugins/tdd/commands/issue_1528_setup_error_test.dart`.

---

## 2026-09-13 08:20:00 - RED - U-1528-1

Behavior: verify-red missing profile fails CLOSED as setup-error (single lane)

Evidence: `dart test test/plugins/tdd/commands/issue_1528_setup_error_test.dart --exclude-tags "slow,integration"` — 2 failures, both asserting the NEW contract; the actual output shows the bug:

```
Actual: 'zfa tdd verify-red: behavior B-001\n ...'
'verify-red: behavior=B-001 classification=unresolved certified=false feature=090-tdd-fixture'
Expected: contains 'verify-red: behavior=B-001 classification=setup-error certified=false feature=090-tdd-fixture'
```

A missing TDD profile (setup condition) surfaces as `classification=unresolved`.

---

## 2026-09-13 08:20:00 - RED - U-1528-2

Behavior: verify-red --all missing profile (batch lane) classifies setup-error

Evidence: same run — batch summary shows the misclassification:

```
'verify-red: batch=true behaviors=1 certified=0 classification=unresolved feature=all'
Expected: contains '... classification=setup-error ...'
```

---

## 2026-09-13 08:21:00 - RED - U-1528-4

Behavior: run entry preflights the baseline (auto-init + fail-closed misfire)

Evidence: `dart test test/plugins/tdd/commands/issue_1528_setup_error_test.dart --preset=integration` — 2 failures:

- missing-profile scenario: `.specify/memory/tdd-profile.md` does NOT exist after the run (no preflight), no `zfa tdd run: preflight` line, step spawn log non-empty is unassertable because the loop stops at B-001:verify-red on the missing profile (issue dogfood repro).
- init-misfire scenario: exitCode 0-unrelated failure — expected `result=setup-error` summary and zero spawns; actual run drove steps instead (no fail-closed gate).

---

## 2026-09-13 08:21:00 - RED - U-1528-5

Behavior: gen entry preflights the baseline (auto-init + fail-closed misfire)

Evidence: same integration run — 2 failures:

- missing-profile scenario: expected `.specify/memory/tdd-profile.md` created by the gen entry preflight + `zfa tdd gen: preflight` line; actual: no preflight, no profile.
- init-misfire scenario: expected exit non-zero + verdict `exit_class=setup-error`; actual exit 0 with no refusal (`Expected: not <0>  Actual: <0>`).

---

## 2026-09-13 08:21:00 - GREEN (born-green invariants) - U-1528-3

Behavior: ordering + vocabulary invariants

Evidence: 2/2 pass on pre-fix master — unknown-id with no profile still
resolves FIRST (`unresolved`), a valid-profile unexpected-green rejection is
unchanged. These pin FR-007 ordering; they must stay green after the fix.

---

## 2026-09-13 08:45:00 - GREEN - U-1528-1

Behavior: verify-red missing profile fails CLOSED as setup-error (single lane)

Evidence: `dart test test/plugins/tdd/commands/issue_1528_setup_error_test.dart --exclude-tags "slow,integration"` — 7/7 pass. The post-resolution probe fail-closes with the summary line `verify-red: behavior=B-001 classification=setup-error certified=false feature=<feature>`, the `--> fix: run \`zfa tdd init\`, then re-run` line, a verdict receipt (`exit_class=setup-error`) under `--json`, exit 1, no evidence, NO writes (profile still absent — FR-008 preserved).

---

## 2026-09-13 08:45:00 - GREEN - U-1528-2

Behavior: verify-red --all missing profile (batch lane) classifies setup-error

Evidence: same run — per-behavior + batch summaries carry `classification=setup-error`, `--> fix:` line, exit 1; the empty-targets early return keeps `classification=batch` exit 0.

---

## 2026-09-13 08:46:00 - GREEN - U-1528-4

Behavior: run entry preflights the baseline (auto-init + fail-closed misfire)

Evidence: `dart test test/plugins/tdd/commands/issue_1528_setup_error_test.dart --preset=integration` — 4/4 pass.
- missing profile: the run entry recreated `.specify/memory/tdd-profile.md` + `test/bootstrap_smoke_test.dart` + `dart_test.yaml` + spec template (artifacts logged under `zfa tdd run: preflight — … (created: …)`), then drove the loop's first step (fake zfa step log non-empty); no `classification=unresolved` anywhere.
- init misfire (illegal-YAML pubspec): journaled `preflight_red` (result=setup-error, pubspec failure named in violations), all-zero `run: feature=… result=setup-error …` summary, `--> fix:` line, exit 1, ZERO step spawns.

---

## 2026-09-13 08:46:00 - GREEN - U-1528-5

Behavior: gen entry preflights the baseline (auto-init + fail-closed misfire)

Evidence: same run — missing profile → baseline ensured + artifacts logged before the flow (exit 0); init misfire → fail-closed refusal, verdict `exit_class=setup-error`, exit 1.

---

## 2026-09-13 08:47:00 - GREEN - U-1528-3

Behavior: ordering + vocabulary invariants

Evidence: 2/2 pass post-fix — unknown-id with NO profile still resolves FIRST (`unresolved`), valid-profile unexpected-green unchanged; pinned U27 in verify_red_command_test.dart flipped red→green to the setup-error contract.

---
