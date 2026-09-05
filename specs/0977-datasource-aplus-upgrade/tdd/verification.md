# TDD Verification — spec #977: datasource A+ upgrade

Feature: `977-datasource-aplus-upgrade` (branch `spec/977-datasource-aplus-upgrade`)
Scope: kill both exit-0 lies, structured `hasService` skip, `datasource check`
parity gate, standalone receipts, one truth for `--local`.
Toolchain: Dart 3.13.2 (stable), package:test. All numbers below are from
actual runs on this branch; nothing is projected or assumed.

## 1. Test-first evidence (RED → GREEN)

### RED baseline (before implementation, 2026-09-04)

16 failing-first tests were written under `test/plugins/datasource/` and run
against the unmodified tree (`dart test test/plugins/datasource/
datasource_command_exit_test.dart test/plugins/datasource/
datasource_receipts_test.dart test/plugins/datasource/
datasource_default_parity_test.dart`):

- Result: **+5 passing / -11 failing**; the 4th file
  (`datasource_check_command_test.dart`) was **RED-by-absence**: it failed to
  load with `Error when reading 'lib/src/commands/datasource_check_command.dart':
  No such file or directory` because the check verb did not exist.
- The 11 honest RED failures, each reproducing a defect named by the spec:
  - `lie #2 — failure branch never exits 0`: failure exited **0** (bug:
    `datasource_command.dart:80-82`).
  - `capability.execute reports success:false with a reason` (useService):
    skip reported **success:true with zero files** (bug: silent
    `if (config.hasService) return []` at `datasource_plugin.dart:197-199`).
  - `use-service spelling is honored too`: same empty-success lie.
  - `success:true with zero files exits 1`: standalone path exited **0** on
    zero files (#769 mirror missing).
  - receipts ×3: no `.zfa/receipts/datasource-<entity>.json` was written by
    the standalone path.
  - default parity ×4: CLI `--local` default **true** vs capability schema
    default **false**; `--remote` absent from the capability schema entirely;
    a real `ArgResults` parse disagreed with the schema.
- 5 tests were **green at birth** and are honestly reported as pre-existing
  fixes locked by regression tests, not new work:
  - bare-command usage-error tests ×2 (`reportSubcommandUsage()` exit 64 —
    upstream commit `99c4b136` "sweep lying-success exit codes across 16
    commands (#995) (#1039)" had already wired the bare branch; dispatch-level
    `Missing subcommand` → CliRunner `_exit(64)` was already honest);
  - `plugin.generate still returns [] for hasService` (emission semantics
    were never broken — the contract around them was);
  - schema-vs-plugin-config agreement on `local` (both already `false`);
  - dry-run writes no receipt (trivially true pre-change).

### GREEN (after implementation)

`dart test test/plugins/datasource/` → **+29: All tests passed!**
(16 new tests + 4 pre-existing `datasource_plugin_test` tests + 9 pre-existing
`local_generator_test` tests; the full file list is in §3.)

## 2. Verify gates (ACTUAL outputs)

| Gate | Command | Result |
|---|---|---|
| Analyze (touched files) | `dart analyze lib/src/commands/datasource_command.dart lib/src/commands/datasource_check_command.dart lib/src/plugins/datasource/ lib/src/core/project/receipt_store.dart test/plugins/datasource/` | **No issues found!** |
| Analyze (repo delta vs master) | `dart analyze` on stashed master vs branch | master **345 issues** → branch **345 issues** after cleanup (Δ = **0**; the 31 pre-existing `examples/todo_tdd` errors are missing-codegen artifacts, unchanged) |
| Fast suite (chunked, disk-safe) | `tools/run_chunks_range.sh 1 25`, `26 50`, `51 76` (76 chunks, `--exclude-tags flutter`) | **All chunks green**; `test/feature_flags` failed once in chunk mode, then passed standalone (74/74) and in a chunked re-run — transient, not caused by this branch |
| Format idempotency | `dart format .` twice | second run: **0 changed**; `git status` shows only this branch's 8 files |

## 3. Acceptance-criteria coverage

### AC-1 — No path exits 0 on failure or missing args (regression-proven)

- `datasource_command_exit_test.dart › lie #1`:
  - programmatic `run()` with no entity → **exitCode 64** via
    `reportSubcommandUsage()` (the branch `datasource_command.dart:50-53`
    owns; reachable exactly the way the base-class contract documents);
  - dispatch-level `CliRunner.runCapturing(['datasource'])` →
    `Missing subcommand` pinned (CliRunner maps UsageException → 64 at
    `cli_runner.dart:265-268`).
- `lie #2`: capability-reported failure → **exitCode 1** + `--> fix:` line +
  reason printed (proved RED first: exit 0 before the fix).
- zero-files success on the standalone path → **exitCode 1** (#769 mirror,
  proved RED first).
- check verb: missing entity → **exitCode 64**; unknown entity / missing
  interface → **exitCode 1** + `--> fix:`.

### AC-2 — `datasource check` fails on a deliberately diverged impl (both ways)

`datasource_check_command_test.dart`:

- **Missing direction**: `getList` deleted from the remote impl → exit **1**,
  output names `getList` + `product_remote_datasource.dart` + `--> fix:`.
- **Extra-@override direction**: `purge` added with `@override` → exit **1**,
  output names `purge`.
- **sqlite variant divergence**: sqlite impl missing `delete` + `watch` →
  exit **1**, output names both methods + `product_sqlite_datasource.dart`.
- **Positive (both shapes)**: fresh interface+remote+local → exit **0**; a
  complete sqlite variant → exit **0** (plus content pins: class name,
  `implements ProductDataSource`, every method, `PRAGMA journal_mode = WAL`).

Parity semantics (documented in the command's doc comment): every public
interface method must appear in each implementation; every `@override` in an
implementation must exist in the interface; non-`@override` public extras
(the local Hive variant's `save`/`saveAll`/`clear`) are legitimate.

### AC-3 — Standalone receipts written; `zfa proof check` green

`datasource_receipts_test.dart`:

- successful standalone generation writes
  `.zfa/receipts/datasource-product.json` with `schema: proof.v1`,
  `command: datasource create`, `target: Product`;
- `input` records the **id-field / query-field resolution** (`id`, `String`,
  `id`) consumed by the run (#294 audit trail), plus local/remote/cache/init;
- every receipted artifact's `sha256` matches the on-disk bytes;
- `ProofChecker(projectRoot: …).check()` → `ok == true`, **0 findings**,
  receipts ≥ 1;
- dry-run writes no receipt; the local variant lands in the same receipt.

### AC-4 — CLI/schema default parity test lands

`datasource_default_parity_test.dart` (5 tests): CLI `--local` ≡ schema
default; CLI `--remote` ≡ schema default; capability schema ≡ plugin config
schema for both flags; and a real `CommandRunner.parse` produces flag values
equal to the schema defaults. The schema is canonical in code as well:
`DataSourceCommand` derives the flag defaults from
`CreateDataSourceCapability.inputSchema` at construction time — there is no
hard-coded default left to drift.

## 4. Test-smell rubric

- **No test-only backdoors**: production code has no `if (testing)` branches;
  tests drive the real command/capability/plugin objects. Command tests use
  the documented programmatic-invocation path (argResults injection via a
  test subclass) because package:args rejects entity-positionals at dispatch
  for subcommand-registering commands — that is the contract under test, not
  a hole in it.
- **No sleeps/timeouts**: all tests are deterministic on temp dirs cleaned in
  `tearDown`.
- **No assertion-free tests**: every test asserts exit codes, output
  substrings, file existence, JSON fields, or digests.
- **Boundary honesty**: `--dry-run` and best-effort receipt failure paths are
  asserted explicitly (no receipt on dry-run).
- **Known flake**: `test/feature_flags` flaked once inside the chunked runner
  (temp-project `pub get` contention); green on re-run. Unrelated to this
  branch's files.

## 5. Mutation results

**Not run — and not faked.** `mutation_test` is wired via
`mutation-test.xml` scoped to the spec-041 TDD plugin surface; the datasource
plugin is outside that scope, and running the full suite per mutant is
explicitly forbidden by `dart_test.yaml` on small agents (disk/time budget).
Coverage for the mutated behaviors is carried instead by the behavioral
assertions above (exit codes, output contracts, digests), which are the same
properties a mutation run would attempt to falsify.

## 6. Constraints audit

- **Emission semantics unchanged**: `DataSourcePlugin.generate` still returns
  `[]` for `config.hasService` and emits exactly as before — regression test
  `plugin.generate still returns [] for hasService` proves it; the contract
  *around* the emission (capability → command → exit code → receipt) is what
  changed. Receipt writes are best-effort and never alter generation.
- **No path overrides reintroduced**: `pubspec.yaml` has no
  `dependency_overrides:` section (verified before `dart pub get`; the repo
  comment confirms removal per spec 018).
- **Disk housekeeping**: kernel caches cleaned by the chunked runner between
  chunks; probes and temp projects removed; peak disk stayed under 15% of the
  10 GB budget (8.1 GB free at end of run).
