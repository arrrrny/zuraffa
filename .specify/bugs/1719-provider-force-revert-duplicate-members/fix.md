# Fix — Bug 1719 (provider create: `--force`/`--revert` no-ops + duplicate members)

Branch: fix/1719-provider-force-revert-duplicate-members
Red evidence: `tdd/red-T001-bug1719.log` (6/6 new tests fail before the fix)
Green evidence: `tdd/green-T001-bug1719.log` (6/6 pass after the fix)

## Changed files

### 1. `lib/src/plugins/provider/builders/provider_builder.dart`

- **Fresh-file write reads the per-invocation config, not the plugin-level
  options** (D1a): `FileUtils.writeFile(..., force: config.force, dryRun:
  config.dryRun, verbose: config.verbose)`. The CLI constructs plugins with
  the const-default `GeneratorOptions()`, so `options.force` was always
  false — `--force` was dropped on the floor (existing file reported
  `skipped` even with the flag) and `--dry-run` actually wrote new files.
- **Signature-faithful implementation members** (D2): the interface
  extraction loop now emits via `_buildImplementationMember(ParsedUseCaseInfo)`:
  - `info.isGetter` → the member is emitted as a GETTER (no invented
    `params` argument) — `Stream<bool> get isInitialized` stays a getter;
  - `info.parameterCount == 0` → the member keeps its parameter-less shape
    — `dispose()` does not become `dispose(NoParams params)`;
  - `parameterCount > 0` → one required `params` parameter typed with the
    interface's own parameter type (unchanged behavior for the common case).
  This reuses the `isGetter`/`parameterCount` metadata
  `MethodExtractor` has carried since issue #1570; the builder simply
  ignored it.
- **Exactly one member per interface member** (D2): the `--init` members
  are built once up front (`_buildInitMembers()`), their names collected in
  `initMemberNames`, and interface-extracted members with the same names
  are skipped. When both sides use `--init`, the canonical init bodies
  (`const Stream.empty()`, empty async `initialize`/`dispose`) are emitted
  exactly once instead of colliding with mangled extraction copies.

### 2. `lib/src/plugins/provider/capabilities/create_provider_capability.dart`

- Forwards the global `--revert` flag into `GeneratorConfig(revert: ...)`
  (D1b) — `CapabilityCommand` already parsed `--revert` into
  `args['revert']`; the capability never read it, so the builder's delete
  path was unreachable from the CLI.
- The service-existence precondition (`StateError` when
  `domain/services/<name>_service.dart` is missing) now only guards
  CREATION (`generateData && !revert`) — a `--revert` cleanup must not be
  blocked by an unrelated missing precondition.

### 3. `lib/src/plugins/service/service_plugin.dart`

- Interface write reads the per-invocation config (D3):
  `force: config.force, dryRun: config.dryRun, verbose: config.verbose`.
  This is the D1a shape on the service side — `zfa service create --force`
  reported "Re-run with --force to overwrite" while the flag was already
  passed.

### 4. `lib/src/plugins/service/capabilities/create_service_capability.dart`

- Forwards `args['revert']` into `GeneratorConfig(revert: ...)` (same D1b
  shape as the provider capability).

### 5. `lib/src/commands/service_create_command.dart`

- Declares the `--revert` flag (the first-party command's grammar never had
  it — the generic `CapabilityCommand` surface did) and passes it through
  to the capability args.
- Surfaces `deleted` actions as a first-class SUCCESS outcome: prose mode
  prints `✅ Reverted (deleted): 🗑 <path>`; `--json` mode emits a `pass`
  verdict with the deleted artifact listed. Previously a revert would have
  fallen into the "No files were generated (nothing changed)" refusal with
  exit 1.

### Test

- `test/fixes/bug_1719_provider_force_revert_duplicate_members_test.dart` —
  six regression tests (B1–B6 in `tdd/test-list.md`), constructed with the
  DEFAULT `GeneratorOptions` (the CLI's real configuration — earlier tests
  that passed `GeneratorOptions(force: true)` masked the flag drop).

## Constraints honored

- Provider interface emission (`ServiceInterfaceBuilder`) untouched.
- Append/inject path keeps `force: true` write semantics.
- Fresh-create shapes unchanged apart from the corrected getter /
  parameter-less member shapes.
