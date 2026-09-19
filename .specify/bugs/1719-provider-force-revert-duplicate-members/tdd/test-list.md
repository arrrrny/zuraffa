# TDD test list — bug 1719 (provider `--force`/`--revert` no-ops + duplicate members)

Behaviors that must exist before the fix is accepted. Each maps to a test in
`test/fixes/bug_1719_provider_force_revert_duplicate_members_test.dart`
(fast tier: capability-level, temp fixtures, no subprocesses).

| # | Behavior | Test |
|---|----------|------|
| B1 | `zfa provider create … --force` OVERWRITES an existing provider file — the result reports `overwritten` (not `skipped`) and the file content is replaced | `bug 1719 / D1 — provider create --force overwrites > --force overwrites the existing provider file (no skip hint)` |
| B2 | `zfa provider create … --revert` DELETES the existing provider file without demanding `--force` — the result reports `deleted` and the file is gone | `bug 1719 / D1 — provider create --revert deletes without --force > --revert deletes the existing provider file` |
| B3 | Provider create with `--init` against an `--init` service emits EXACTLY ONE implementation member per interface member: `Stream<bool> get isInitialized` (getter, once), `initialize(InitializationParams)` (once), `dispose()` (parameter-less, once); the regular member (`auth`) is untouched | `bug 1719 / D2 — one implementation member per interface member > provider create --init against an --init service emits exactly one member per interface member, matching interface signatures` |
| B4 | Provider create WITHOUT `--init` against an `--init` service still mirrors interface signatures (getter stays a getter, `dispose()` stays parameter-less, `initialize` once) — signature-faithful stubs, no duplicates | `bug 1719 / D2 — one implementation member per interface member > provider create without --init still mirrors interface signatures (getter stays a getter, dispose stays parameter-less)` |
| B5 | `zfa service create … --force` OVERWRITES the existing service file — the result reports `overwritten` (not `skipped`) and the content is replaced | `bug 1719 / D3 — service create --force (and --revert) work > --force overwrites the existing service file (no "re-run with --force")` |
| B6 | `zfa service create … --revert` DELETES the generated service file — the result reports `deleted` and the file is gone | `bug 1719 / D3 — service create --force (and --revert) work > --revert deletes the generated service file` |

Whole-command properties (proven by live CLI runs, recorded in
`verification.md`):

| # | Property | Evidence |
|---|----------|----------|
| P1 | With `--force`, the CLI prints `📝 <path>` (overwritten) and exits 0; with `--revert`, `🗑 <path>` | live `zfa provider create` runs on a scratch fixture |
| P2 | `zfa service create … --force` prints the overwritten artifact + conformance pass; `zfa service create --revert` prints `✅ Reverted (deleted):` and exits 0 | live `zfa service create` runs |
| P3 | The regenerated provider for an `--init` service analyzes CLEAN (`dart analyze`: no `duplicate_definition`) — exactly one member per interface member | live `dart analyze lib/src` on the scratch fixture |
| P4 | `--dry-run` no longer writes new provider files (the same `options.*` vs `config.*` root cause, repaired on the same write call) | live `zfa provider create X --dry-run` leaves no file |

Non-behavioral constraints:

- Provider INTERFACE emission (`ServiceInterfaceBuilder`) is unchanged —
  only the provider implementation body/membership changed.
- The append/inject path (`appendToExisting`) keeps its `force: true`
  write semantics; entity-method configs are untouched.
- Existing generation shapes (fresh create without the new flags) are
  byte-identical apart from the corrected member shapes for
  getter/parameter-less interface members.
