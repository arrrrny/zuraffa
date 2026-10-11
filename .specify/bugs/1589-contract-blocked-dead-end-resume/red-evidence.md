# Red Evidence — bug 1589 (pre-fix runs, this session)

Branch: `fix/1589-contract-blocked-dead-end-resume` (parent: 52ebc3cf).
Toolchain: Dart 3.13.3 (stable) on linux_x64.

## Suite 1 — `test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart`

Command: `dart test test/plugins/tdd/commands/bug_1589_contract_blocked_resume_test.dart`

Result: `00:06 +3 -5: Some tests failed.`

RED (failed pre-fix — the bug):

1. **park note names no hand surface** — expected `hand surface:` /
   `seam test/tdd/004-login-ui/contract_a1_test.dart` /
   `zfa tdd wire contract:A1 --entity User`; actual park output carries none
   of them.
2. **terminal `result=blocked` block names no hand surface** — same shape.
3. **refactor spawn carries no parked seam (this-run parking)** — the
   spawned `tdd refactor …` argv has no `--parked-seam`.
4. **refactor spawn carries no parked seam (resume skip of a persisted
   parking)** — same shape.
5. **`make contract:A1` dead-ends** — actual output (verbatim):
   `zfa tdd make: behavior "contract:A1" has no certified-red evidence in
   cycle-log.md. Run `zfa tdd verify-red contract:A1` first.` /
   `make: behavior=contract:A1 outcome=not-certified-red …` — the dead-end
   loop the issue reports (verify-red can never write red for a contract).

GUARDS (already green pre-fix — behavior that must not change):

- make fails OPEN to `not-certified-red` when the world changed since the
  verdict (lib/ newer).
- make fails OPEN to `not-certified-red` when the receipt is missing.
- make keeps the existing refusal for a NON-contract behavior.

## Suite 2 — `test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart`

Command: `dart test --preset=all test/plugins/tdd/bug_1589_refactor_parked_seam_test.dart`

Result: `00:04 +1 -5: Some tests failed.`

RED (failed pre-fix — the bug):

1. **preflight red confined to a handed parked seam refuses** — the
   `--parked-seam` flag does not even parse (usage exception), and the gate
   refuses `not-green` for a failure the driver attested as a parked
   verdict.
2. **the same red beside baseline-recorded failures refuses** — the #922
   and #1589 economics do not compose.
3. **a re-proof red confined to the parked seam grades REGRESSION** — the
   pass would be recorded as a regression for the parked verdict's
   pre-existing failure.
4. **the surgical guard's companion case** (NEW failure beyond the parked
   seam) — fails only because the flag is unknown (usage exception); the
   refusal itself is the required behavior and is re-pinned post-fix.
5. **unparseable red fail-closed companion case** — same usage-exception
   failure; the fail-closed refusal is re-pinned post-fix.

GUARD (already green pre-fix): a flag-less standalone refactor keeps the
absolute-green contract — `outcome=not-green`, exit non-zero.

## Interpretation

The failures reproduce all three success-criteria violations: (1) blocked
stops name no hand surface, (2) `make` does not accept/translate the blocked
verdict — it dead-ends the resume path, (3) the refactor gate treats a
parked verdict's failure as NEW red for every phase-2 spawn. The guards
pinning fail-open/refusal semantics pass, so the fix can be scoped
surgically.
